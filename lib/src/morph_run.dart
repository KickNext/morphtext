import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'align.dart';
import 'animated_morph.dart' show AnimatedMorph;
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
/// one-character text in the icon font. With [converge], every letter of a
/// word morphs into (or out of) the single glyph at the other end, so a word
/// flows into an icon instead of one letter becoming it while the rest
/// shrink away.
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
        if (mounted && _pairsKey == key) setState(() => _pairs = pairs);
      } on Object catch (error) {
        // Unreadable: it stays plain text, switching at the middle.
        _warn(from.fontFamily, to.fontFamily, error);
      }
    }());
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
