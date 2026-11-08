// Text that morphs between two styles letter by letter, outline into outline:
// a light word turns bold, or a small word grows, as one word, never two
// crossfading. Each letter's outline in each style comes from the font file
// itself (lib/src/engine.dart, on morphnext's outline engine).
//
// Flutter lays the word out in both styles (kerning, baseline and all), and
// each letter's em square is carried between its two layouts; at the ends it
// is plain text, pixel for pixel what a Text in that style draws.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'engine.dart';

/// [text] in [from]'s style at [t] = 0 and [to]'s at 1, morphing letter by
/// letter in between: weight, size, slant and colour.
///
/// Both styles are merged onto the ambient [DefaultTextStyle], as a [Text]
/// would merge them. Their font families must be bundled with the app (they
/// appear in `FontManifest.json`), because each letter's outline is read
/// from the font file: the nearest declared weight, upright or italic as the
/// style asks. A font named by a package is written as
/// `TextStyle(fontFamily: 'Fraunces', package: 'my_package')`.
///
/// At `t <= 0` and `t >= 1`, and until the outlines are read, it draws plain
/// text, identical to a one-line [Text] in that style. A letter whose outline
/// can't be read (not in the bundled font, say) is drawn as text at its
/// moving position instead of morphing.
///
/// For a widget that animates by itself when its style changes, see
/// [AnimatedMorphText].
class MorphText extends StatefulWidget {
  /// Creates text morphing from [from] to [to] by [t].
  const MorphText(
    this.text, {
    super.key,
    required this.from,
    required this.to,
    required this.t,
    this.semanticsLabel,
  });

  /// The text to draw, on one line.
  final String text;

  /// The style at [t] = 0.
  final TextStyle from;

  /// The style at [t] = 1.
  final TextStyle to;

  /// How far from [from] to [to], clamped to 0..1.
  final double t;

  /// The label announced for this text; [text] when null.
  final String? semanticsLabel;

  @override
  State<MorphText> createState() => _MorphTextState();
}

class _MorphTextState extends State<MorphText> {
  /// Each letter's morph; null for a letter with no outline (a space) or
  /// one that couldn't be read.
  List<GlyphMorph?>? _letters;
  Object? _key;
  _Layout? _a, _b;

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
      from.fontFamily,
      from.fontWeight,
      from.fontStyle,
      to.fontFamily,
      to.fontWeight,
      to.fontStyle,
    );
    if (key == _key) return;
    _key = key;
    _letters = null;
    final text = widget.text;
    unawaited(() async {
      try {
        final fonts = _Fonts.of(bundle);
        final a = await fonts.face(from);
        final b = await fonts.face(to);
        final letters = [
          for (final rune in text.runes) fonts.morph(a, b, rune),
        ];
        if (mounted && _key == key) setState(() => _letters = letters);
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
    final b = _b = _Layout.reuse(_b, widget.text, to, scaler, direction);
    return Semantics(
      label: widget.semanticsLabel ?? widget.text,
      textDirection: direction,
      child: ExcludeSemantics(
        child: CustomPaint(
          size: Size.lerp(a.size, b.size, t)!,
          painter: _MorphTextPainter(
            a,
            b,
            _letters,
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
    final baseline = painter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
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
  final pens = <Offset?>[];
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
  final _morphs = <(String, String, int), GlyphMorph?>{};
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

  /// [rune]'s morph from face [a] to face [b], or null if either outline
  /// can't be read.
  GlyphMorph? morph(_Face a, _Face b, int rune) {
    final key = (a.asset, b.asset, rune);
    if (_morphs.containsKey(key)) {
      // Most recently used goes last.
      return _morphs[key] = _morphs.remove(key);
    }
    GlyphMorph? m;
    try {
      final sa = a.font.shape(rune), sb = b.font.shape(rune);
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
  _MorphTextPainter(this.a, this.b, this.letters, this.t, this.color);
  final _Layout a, b;
  final List<GlyphMorph?>? letters;
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // At either end, or until the outlines are read: the word as text,
    // centred in the box (exactly what a Text in that style draws).
    final p = letters;
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
    final runes = a.text.runes.toList();
    for (var i = 0; i < p.length; i++) {
      final letter = p[i];
      final pa = a.pens[i], pb = b.pens[i];
      if (pa == null || pb == null) continue;
      if (letter == null) {
        _fallback(canvas, runes[i], Offset.lerp(pa + offA, pb + offB, t)!);
        continue;
      }
      final sq = Rect.lerp(
        _square(pa + offA, a.em, letter, 0),
        _square(pb + offB, b.em, letter, 1),
        t,
      )!;
      for (final points in letter.at(t)) {
        _contour(path, points, sq);
      }
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  /// The letter's em square in one layout: from its pen position, its top
  /// an ascender above the baseline, as the outline was normalised.
  static Rect _square(Offset pen, double em, GlyphMorph letter, int end) {
    final asc = end == 0 ? letter.fromAscender : letter.toAscender;
    return Rect.fromLTWH(pen.dx, pen.dy - asc * em, em, em);
  }

  /// A letter with no outline to morph: drawn as text, in the style between
  /// the two, its baseline on the moving pen. Spaces draw nothing.
  void _fallback(Canvas canvas, int rune, Offset pen) {
    final char = String.fromCharCode(rune);
    if (char.trim().isEmpty) return;
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
      old.letters != letters ||
      old.color != color ||
      old.a != a ||
      old.b != b;
}
