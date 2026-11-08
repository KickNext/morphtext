import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'align.dart';
import 'animated_morph.dart' show AnimatedMorph;
import 'engine.dart';
import 'font_faces.dart';
import 'morph_between.dart' show MorphBetween;
import 'morph_painter.dart';
import 'morph_text.dart' show MorphText;
import 'word_layout.dart';

/// The engine behind [MorphText] and [MorphBetween]: [text] in [from] at
/// [t] = 0 to [toText] in [to] at [t] = 1, glyph outline into glyph outline.
///
/// Flutter lays out both ends (kerning, baseline and all); each letter's
/// outline in each style is read from the font file itself, through
/// morphnext's outline engine. At either end it is plain text, pixel for
/// pixel what a `Text` draws.
///
/// An icon reaches it as Flutter's `Icon` draws one: its code point as a
/// one-character text in the icon font. With [converge], a word morphs into
/// (or out of) the single glyph at the other end as one shape, its letters
/// where its layout puts them, instead of one letter becoming the glyph
/// while the rest shrink away. (One shape, not a copy of the glyph per
/// letter: copies drifting apart cover each other's holes, so an outline
/// icon turned solid before it began to morph.)
///
/// Internal: not exported from the package.
class MorphRun extends StatefulWidget {
  /// Creates the morph from [text] in [from] to [toText] in [to], at [t].
  const MorphRun(
    this.text, {
    super.key,
    required this.toText,
    required this.from,
    required this.to,
    required this.t,
    required this.semanticsLabel,
    this.converge = false,
    this.handoff = 0,
  });

  /// The text at [t] = 0, on one line.
  final String text;

  /// The text at [t] = 1, on one line.
  final String toText;

  /// The style at [t] = 0.
  final TextStyle from;

  /// The style at [t] = 1.
  final TextStyle to;

  /// How far from the start to the end: clamped to 0..1, or a little past
  /// either end under a spring ([MorphMotion]).
  final double t;

  /// The label announced.
  final String semanticsLabel;

  /// Whether a single glyph at one end gathers every letter at the other.
  final bool converge;

  /// The share of the end, 0..1, over which plain text fades in, when not
  /// under an [AnimatedMorph] (which says how far its own handoff has come).
  final double handoff;

  @override
  State<MorphRun> createState() => _MorphRunState();
}

class _MorphRunState extends State<MorphRun> {
  /// How far past either end a spring may carry the outlines, as morphnext's
  /// `AnimatedMorphIcon` allows.
  static const _overshoot = .25;

  /// Which letter becomes which, once the outlines are read.
  List<LetterPair>? _pairs;

  /// What [_pairs] were read for.
  Object? _pairsKey;

  /// Both ends' faces, read with [_pairs], when a word gathers into a
  /// single glyph (or one opens into a word): see [_wholeMorph].
  (FontFace, FontFace)? _gathering;

  /// The whole word's morph into the single glyph, and the geometry it was
  /// planned for.
  GlyphMorph? _whole;
  List<Object?>? _wholeKey;

  WordLayout? _layoutA, _layoutB;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _readOutlines();
  }

  @override
  void didUpdateWidget(MorphRun old) {
    super.didUpdateWidget(old);
    _readOutlines();
  }

  /// Both styles, merged onto the ambient default as a `Text` merges its own.
  (TextStyle, TextStyle) _styles() {
    final base = DefaultTextStyle.of(context).style;
    return (base.merge(widget.from), base.merge(widget.to));
  }

  /// Reads both ends' faces and pairs their letters, unless already done for
  /// the same text and faces. Until it's done, the ends draw as plain text.
  void _readOutlines() {
    final (from, to) = _styles();
    final bundle = DefaultAssetBundle.of(context);
    final key = (
      bundle,
      widget.text,
      widget.toText,
      from.fontFamily,
      from.fontWeight,
      from.fontStyle,
      to.fontFamily,
      to.fontWeight,
      to.fontStyle,
      widget.converge,
    );
    if (key == _pairsKey) return;
    _pairsKey = key;
    _pairs = null;
    _gathering = null;
    final runesA = widget.text.runes.toList();
    final runesB = widget.toText.runes.toList();
    unawaited(() async {
      try {
        final fonts = FontFaces.of(bundle);
        final a = await fonts.face(from);
        final b = await fonts.face(to);
        final alignment = widget.converge
            ? convergeLetters(runesA, runesB)
            : alignLetters(runesA, runesB);
        final pairs = [
          for (final (i, j) in alignment)
            LetterPair(
              from: i,
              to: j,
              fromRune: i == null ? null : runesA[i],
              toRune: j == null ? null : runesB[j],
              morph: switch ((i, j)) {
                (final i?, final j?) => fonts.morph(a, b, runesA[i], runesB[j]),
                // Alone: its own outline, which the painter shrinks or grows.
                (final i?, null) => fonts.morph(a, a, runesA[i], runesA[i]),
                (null, final j?) => fonts.morph(b, b, runesB[j], runesB[j]),
                (null, null) => null,
              },
            ),
        ];
        final gathers =
            widget.converge && (runesA.length == 1) != (runesB.length == 1);
        if (mounted && _pairsKey == key) {
          setState(() {
            _pairs = pairs;
            _gathering = gathers ? (a, b) : null;
          });
        }
      } on Object catch (error) {
        // Unreadable: it stays plain text, switching at the middle.
        _warn(from.fontFamily, to.fontFamily, error);
      }
    }());
  }

  /// The word and the single glyph as one morph, each end's outlines placed
  /// where its layout draws them, in units of the larger em; null until the
  /// faces are read, or when either end has nothing to draw. Planned again
  /// only when the geometry changes, never for a colour.
  GlyphMorph? _wholeMorph(WordLayout a, WordLayout b) {
    final faces = _gathering;
    if (faces == null) return null;
    final unit = a.em > b.em ? a.em : b.em;
    final key = <Object?>[
      faces.$1,
      faces.$2,
      a.text,
      b.text,
      a.em,
      b.em,
      a.baseline,
      b.baseline,
      ...a.pens,
      null,
      ...b.pens,
    ];
    if (_wholeKey != null && listEquals(key, _wholeKey)) return _whole;
    _wholeKey = key;
    GlyphShape? shape(FontFace face, WordLayout layout) {
      final runes = layout.text.runes.toList();
      return GlyphShape.placed([
        for (var k = 0; k < runes.length; k++)
          if ((layout.pens[k], face.font.outline(runes[k])) case (
            final pen?,
            final outline?,
          ))
            (
              outline: outline,
              x: pen.dx / unit,
              y: (pen.dy - outline.ascender * layout.em) / unit,
              scale: layout.em / unit,
            ),
      ]);
    }

    try {
      final from = shape(faces.$1, a), to = shape(faces.$2, b);
      _whole = from == null || to == null ? null : GlyphMorph(from, to);
    } on Object {
      _whole = null;
    }
    return _whole;
  }

  /// Without an [AnimatedMorph]: how far the end's text has faded in over
  /// the last [MorphRun.handoff] of the morph, 0..1; null outside it.
  double? _fade(double t) {
    final window = widget.handoff;
    if (window <= 0 || t >= 1 || t <= 1 - window) return null;
    return smoothstep(1 - (1 - t) / window);
  }

  @override
  Widget build(BuildContext context) {
    final scaler =
        MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final (from, to) = _styles();
    final motion = MorphMotion.maybeOf(context);
    final moving = motion?.moving ?? false;
    final raw = widget.t.isNaN ? 0.0 : widget.t;
    final t = moving
        ? raw.clamp(-_overshoot, 1 + _overshoot)
        : raw.clamp(0.0, 1.0);
    final within = t.clamp(0.0, 1.0);
    final a = _layoutA = WordLayout.reuse(
      _layoutA,
      widget.text,
      from,
      scaler,
      direction,
    );
    final b = _layoutB = WordLayout.reuse(
      _layoutB,
      widget.toText,
      to,
      scaler,
      direction,
    );
    return Semantics(
      label: widget.semanticsLabel,
      textDirection: direction,
      child: ExcludeSemantics(
        child: CustomPaint(
          size: Size.lerp(a.size, b.size, within)!,
          painter: MorphPainter(
            a: a,
            b: b,
            pairs: _pairs,
            whole: _wholeMorph(a, b),
            unit: a.em > b.em ? a.em : b.em,
            t: t,
            moving: moving,
            handoff: motion?.handoff ?? _fade(t),
            color:
                Color.lerp(from.color, to.color, within) ??
                const Color(0xff000000),
          ),
        ),
      ),
    );
  }
}

/// Eases [x], 0..1, in and out: the classic smoothstep.
double smoothstep(double x) => x * x * (3 - 2 * x);

/// Family pairs already reported by [_warn].
final _warned = <(String?, String?)>{};

/// Reports once per family pair, in debug builds, why a morph fell back to
/// plain text.
void _warn(String? a, String? b, Object error) {
  if (!kDebugMode || !_warned.add((a, b))) return;
  debugPrint(
    'morphtext: no outlines for "$a" -> "$b" ($error); drawing plain text. '
    'Are both families bundled (FontManifest.json)?',
  );
}

/// Marks the morphs below as in flight ([AnimatedMorph] wraps its morph in
/// one while it animates).
///
/// In flight, `t` may overshoot either end and the outlines follow it, and
/// the end's plain text fades in over them in the last of the motion
/// ([handoff]), so the word is already text when it lands rather than
/// switching once it's still.
///
/// Internal: not exported from the package.
class MorphMotion extends InheritedWidget {
  /// Marks [child]'s morphs as [moving] or not.
  const MorphMotion({
    super.key,
    required this.moving,
    this.handoff,
    required super.child,
  });

  /// Whether a morph is in flight.
  final bool moving;

  /// Near the end: how far the end's plain text has faded in, 0..1.
  final double? handoff;

  /// The nearest [MorphMotion], if any.
  static MorphMotion? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MorphMotion>();

  @override
  bool updateShouldNotify(MorphMotion old) =>
      old.moving != moving || old.handoff != handoff;
}
