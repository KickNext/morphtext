// Text that morphs letter by letter, outline into outline: a light word turns
// bold, a serif word turns sans, a small word grows, or one word becomes
// another, never two crossfading. Each letter's outline in each style comes
// from the font file itself (lib/src/engine.dart, on morphnext's outline
// engine).
//
// Flutter lays out both ends (kerning, baseline and all), and each letter's
// em square is carried from its place in one layout to its place in the
// other; at the ends it is plain text, pixel for pixel what a Text draws.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'align.dart';
import 'engine.dart';

/// [text] in [from]'s style at [t] = 0, morphing letter by letter into
/// [toText] (or [text] again) in [to]'s style at [t] = 1.
///
/// The two styles can differ in anything: weight, size, colour, slant, and
/// font family, so a serif word can turn into a sans one. They are merged
/// onto the ambient [DefaultTextStyle], as a [Text] would merge them.
///
/// With [toText], one word becomes another: each letter morphs into its
/// counterpart (mostly the letter at the same place; a word slides when
/// that keeps letters as themselves), and any left over grow from or shrink
/// to a point.
///
/// The font families must be bundled with the app (they appear in
/// `FontManifest.json`), because each letter's outline is read from the font
/// file: the nearest declared weight, upright or italic as the style asks. A
/// font named by a package is written as
/// `TextStyle(fontFamily: 'Fraunces', package: 'my_package')`.
///
/// At `t <= 0` and `t >= 1`, and until the outlines are read, it draws plain
/// text, identical to a one-line [Text] in that style. A letter whose outline
/// can't be read (not in the bundled font, say) is drawn as text at its
/// moving position instead of morphing.
///
/// For a widget that animates by itself when its text or style changes, see
/// [AnimatedMorphText].
class MorphText extends StatefulWidget {
  /// Creates text morphing from [text] in [from] to [toText] (or [text]) in
  /// [to], by [t].
  const MorphText(
    this.text, {
    super.key,
    required this.from,
    required this.to,
    required this.t,
    this.toText,
    this.semanticsLabel,
  });

  /// The text at [t] = 0, on one line.
  final String text;

  /// The text at [t] = 1; [text] when null.
  final String? toText;

  /// The style at [t] = 0.
  final TextStyle from;

  /// The style at [t] = 1.
  final TextStyle to;

  /// How far from the start to the end, clamped to 0..1.
  final double t;

  /// The label announced for this text; when null, [text] until halfway and
  /// [toText] after.
  final String? semanticsLabel;

  @override
  State<MorphText> createState() => _MorphTextState();
}

class _MorphTextState extends State<MorphText> {
  /// The letters' morphs, once read.
  List<_Pair>? _pairs;
  Object? _key;
  _Layout? _a, _b;

  String get _toText => widget.toText ?? widget.text;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(MorphText old) {
    super.didUpdateWidget(old);
    _load();
  }

  (TextStyle, TextStyle) _styles() {
    final base = DefaultTextStyle.of(context).style;
    return (base.merge(widget.from), base.merge(widget.to));
  }

  void _load() {
    final (from, to) = _styles();
    final bundle = DefaultAssetBundle.of(context);
    final key = (
      bundle,
      widget.text,
      _toText,
      from.fontFamily,
      from.fontWeight,
      from.fontStyle,
      to.fontFamily,
      to.fontWeight,
      to.fontStyle,
    );
    if (key == _key) return;
    _key = key;
    _pairs = null;
    final ra = widget.text.runes.toList(), rb = _toText.runes.toList();
    unawaited(() async {
      try {
        final fonts = _Fonts.of(bundle);
        final a = await fonts.face(from);
        final b = await fonts.face(to);
        final pairs = [
          for (final (i, j) in alignLetters(ra, rb))
            _Pair(
              i,
              j,
              i != null ? ra[i] : null,
              j != null ? rb[j] : null,
              i != null && j != null
                  ? fonts.morph(a, b, ra[i], rb[j])
                  : i != null
                  // Alone: its own outline, which the painter shrinks.
                  ? fonts.morph(a, a, ra[i], ra[i])
                  : fonts.morph(b, b, rb[j!], rb[j]),
            ),
        ];
        if (mounted && _key == key) setState(() => _pairs = pairs);
      } on Object catch (e) {
        // Unreadable: it stays plain text, switching at the middle.
        _warn(from.fontFamily, to.fontFamily, e);
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    final scaler =
        MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final (from, to) = _styles();
    final t = widget.t.isNaN ? 0.0 : widget.t.clamp(0.0, 1.0);
    final a = _a = _Layout.reuse(_a, widget.text, from, scaler, direction);
    final b = _b = _Layout.reuse(_b, _toText, to, scaler, direction);
    return Semantics(
      label: widget.semanticsLabel ?? (t < .5 ? widget.text : _toText),
      textDirection: direction,
      child: ExcludeSemantics(
        child: CustomPaint(
          size: Size.lerp(a.size, b.size, t)!,
          painter: _MorphTextPainter(
            a,
            b,
            _pairs,
            t,
            Color.lerp(from.color, to.color, t) ?? const Color(0xff000000),
          ),
        ),
      ),
    );
  }
}

/// Reports once per family pair, in debug builds, why a MorphText fell back
/// to plain text.
final _warned = <(String?, String?)>{};
void _warn(String? a, String? b, Object error) {
  if (!kDebugMode || !_warned.add((a, b))) return;
  debugPrint(
    'MorphText: no outlines for "$a" -> "$b" ($error); drawing plain text. '
    'Are both families bundled (FontManifest.json)?',
  );
}

/// One letter of the start ([i], [runeA]) becoming one of the end ([j],
/// [runeB]); either may be missing, for a letter that shrinks away or grows
/// in. [morph] is null for a letter with no outline (a space) or one that
/// couldn't be read.
class _Pair {
  _Pair(this.i, this.j, this.runeA, this.runeB, this.morph);
  final int? i, j;
  final int? runeA, runeB;
  final GlyphMorph? morph;
}

/// The word laid out in one style: its size, its em in pixels, and each
/// letter's pen position on the baseline (kerning included).
class _Layout {
  _Layout(this.text, this.style, this.scaler, this.direction)
    : em = scaler.scale(style.fontSize ?? 14) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    size = painter.size;
    baseline = painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    var i = 0;
    for (final rune in text.runes) {
      final n = String.fromCharCode(rune).length;
      final boxes = painter.getBoxesForSelection(
        TextSelection(baseOffset: i, extentOffset: i + n),
      );
      pens.add(boxes.isEmpty ? null : Offset(boxes.first.left, baseline));
      i += n;
    }
    painter.dispose();
  }

  /// [old] if it was laid out from the same inputs, else a new layout.
  static _Layout reuse(
    _Layout? old,
    String text,
    TextStyle style,
    TextScaler scaler,
    TextDirection direction,
  ) =>
      old != null &&
          old.text == text &&
          old.style == style &&
          old.scaler == scaler &&
          old.direction == direction
      ? old
      : _Layout(text, style, scaler, direction);

  final String text;
  final TextStyle style;
  final TextScaler scaler;
  final TextDirection direction;
  final double em;
  late final Size size;
  late final double baseline;
  final pens = <Offset?>[];

  /// Where a letter that isn't in this layout comes from or goes to: the
  /// pen of the letter at [index] (the end of the word past the last one),
  /// a little above the baseline.
  Offset gap(int index) {
    final x = index < pens.length
        ? (pens[index]?.dx ?? size.width)
        : size.width;
    return Offset(x, baseline - .3 * em);
  }
}

/// One asset bundle's fonts: its manifest, each face read once, and the
/// letter morphs built between them.
class _Fonts {
  _Fonts(this.bundle);
  final AssetBundle bundle;

  static final _byBundle = Expando<_Fonts>('morphtext fonts');
  static _Fonts of(AssetBundle bundle) => _byBundle[bundle] ??= _Fonts(bundle);

  Future<List<Object?>>? _manifest;
  final _faces = <String, Future<_Face>>{};

  /// Recently built letter morphs, shared by every MorphText on the bundle.
  /// (A map literal keeps insertion order: the first key is the oldest.)
  final _morphs = <(String, String, int, int), GlyphMorph?>{};
  static const _maxMorphs = 512;

  /// The face [style] names: the nearest weight in its family, upright or
  /// italic as asked.
  Future<_Face> face(TextStyle style) async {
    final family = style.fontFamily ?? '';
    final weight = (style.fontWeight ?? FontWeight.w400).value;
    final italic = style.fontStyle == FontStyle.italic;
    final manifest = await (_manifest ??= bundle
        .loadString('FontManifest.json', cache: false)
        .then((j) => jsonDecode(j) as List<Object?>));
    String? asset;
    var best = 1 << 30;
    for (final f in manifest.cast<Map<String, Object?>>()) {
      if (f['family'] != family) continue;
      for (final face in (f['fonts']! as List).cast<Map<String, Object?>>()) {
        if ((face['style'] == 'italic') != italic) continue;
        final d = ((face['weight'] as int? ?? 400) - weight).abs();
        if (d < best) {
          best = d;
          asset = face['asset']! as String;
        }
      }
    }
    if (asset == null) {
      throw StateError('no ${italic ? 'italic' : 'upright'} face of "$family"');
    }
    final name = asset;
    return _faces[name] ??= bundle
        .load(name)
        .then(
          (data) => _Face(name, GlyphFont.parse(data.buffer.asUint8List())),
        );
  }

  /// The morph from [runeA] in face [a] to [runeB] in face [b], or null if
  /// either outline can't be read.
  GlyphMorph? morph(_Face a, _Face b, int runeA, int runeB) {
    final key = (a.asset, b.asset, runeA, runeB);
    if (_morphs.containsKey(key)) {
      // Most recently used goes last.
      return _morphs[key] = _morphs.remove(key);
    }
    GlyphMorph? m;
    try {
      final sa = a.font.shape(runeA), sb = b.font.shape(runeB);
      if (sa != null && sb != null) m = GlyphMorph(sa, sb);
    } on Object {
      m = null;
    }
    _morphs[key] = m;
    if (_morphs.length > _maxMorphs) _morphs.remove(_morphs.keys.first);
    return m;
  }
}

class _Face {
  _Face(this.asset, this.font);
  final String asset;
  final GlyphFont font;
}

class _MorphTextPainter extends CustomPainter {
  _MorphTextPainter(this.a, this.b, this.pairs, this.t, this.color);
  final _Layout a, b;
  final List<_Pair>? pairs;
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // At either end, or until the outlines are read: the word as text,
    // centred in the box (exactly what a Text in that style draws).
    final p = pairs;
    if (t <= 0 || t >= 1 || p == null) {
      final at = t < .5 ? a : b;
      final painter = TextPainter(
        text: TextSpan(
          text: at.text,
          style: at.style.copyWith(color: color),
        ),
        textDirection: at.direction,
        textScaler: at.scaler,
        maxLines: 1,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          (size.width - painter.width) / 2,
          (size.height - painter.height) / 2,
        ),
      );
      painter.dispose();
      return;
    }
    // Each letter's outline, morphed to t, in its em square carried between
    // the two layouts (each layout centred in the box as it grows or
    // shrinks).
    final offA = Offset(
      (size.width - a.size.width) / 2,
      (size.height - a.size.height) / 2,
    );
    final offB = Offset(
      (size.width - b.size.width) / 2,
      (size.height - b.size.height) / 2,
    );
    final path = Path()..fillType = PathFillType.nonZero;
    for (var k = 0; k < p.length; k++) {
      final pair = p[k];
      final i = pair.i, j = pair.j;
      // Each end's em square; a point where the letter is absent, at the
      // place of the next letter that is there.
      Rect? sqA, sqB;
      Offset? penA, penB;
      if (i != null) {
        final pen = a.pens[i];
        if (pen == null) continue;
        penA = pen + offA;
      }
      if (j != null) {
        final pen = b.pens[j];
        if (pen == null) continue;
        penB = pen + offB;
      }
      final letter = pair.morph;
      if (letter == null) {
        _fallback(canvas, pair, penA, penB, p, k, offA, offB);
        continue;
      }
      if (penA != null) {
        sqA = _square(penA, a.em, letter.fromAscender);
      } else {
        sqA = Rect.fromCenter(
          center: _next(p, k, a, true) + offA,
          width: 0,
          height: 0,
        );
      }
      if (penB != null) {
        sqB = _square(penB, b.em, letter.toAscender);
      } else {
        sqB = Rect.fromCenter(
          center: _next(p, k, b, false) + offB,
          width: 0,
          height: 0,
        );
      }
      // A letter alone is gone by halfway, or grows in from there, so it
      // never lingers as small text beside the others.
      final along = i == null
          ? ((t - .5) * 2).clamp(0.0, 1.0)
          : j == null
          ? (t * 2).clamp(0.0, 1.0)
          : t;
      final sq = Rect.lerp(sqA, sqB, along)!;
      for (final points in letter.at(t)) {
        _contour(path, points, sq);
      }
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  /// Where, in [layout], the letter of pair [k] would be if it were there:
  /// the place of the next letter that is, or the end of the word.
  static Offset _next(List<_Pair> p, int k, _Layout layout, bool start) {
    for (var n = k + 1; n < p.length; n++) {
      final index = start ? p[n].i : p[n].j;
      if (index != null) return layout.gap(index);
    }
    return layout.gap(layout.pens.length);
  }

  /// A letter's em square in one layout: from its pen position, its top an
  /// ascender above the baseline, as the outline was normalised.
  static Rect _square(Offset pen, double em, double ascender) =>
      Rect.fromLTWH(pen.dx, pen.dy - ascender * em, em, em);

  /// A letter with no outline to morph: drawn as text, the nearer end's
  /// letter in the style between the two, its baseline on the moving pen.
  /// Spaces draw nothing.
  void _fallback(
    Canvas canvas,
    _Pair pair,
    Offset? penA,
    Offset? penB,
    List<_Pair> p,
    int k,
    Offset offA,
    Offset offB,
  ) {
    final rune = t < .5 ? pair.runeA : pair.runeB;
    if (rune == null) return;
    final char = String.fromCharCode(rune);
    if (char.trim().isEmpty) return;
    final from = penA ?? Offset(_next(p, k, a, true).dx, a.baseline) + offA;
    final to = penB ?? Offset(_next(p, k, b, false).dx, b.baseline) + offB;
    final pen = Offset.lerp(from, to, t)!;
    final style = TextStyle.lerp(a.style, b.style, t)!.copyWith(color: color);
    final painter = TextPainter(
      text: TextSpan(text: char, style: style),
      textDirection: a.direction,
      textScaler: a.scaler,
      maxLines: 1,
    )..layout();
    final baseline = painter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    painter.paint(canvas, pen - Offset(0, baseline));
    painter.dispose();
  }

  static void _contour(Path path, Float64List points, Rect sq) {
    if (points.length < 4) return;
    path.moveTo(sq.left + points[0] * sq.width, sq.top + points[1] * sq.height);
    for (var k = 2; k < points.length; k += 2) {
      path.lineTo(
        sq.left + points[k] * sq.width,
        sq.top + points[k + 1] * sq.height,
      );
    }
    path.close();
  }

  @override
  bool shouldRepaint(_MorphTextPainter old) =>
      old.t != t ||
      old.pairs != pairs ||
      old.color != color ||
      old.a != a ||
      old.b != b;
}
