import 'package:flutter/widgets.dart';

import 'animated_morph_text.dart' show AnimatedMorphText;
import 'morph_between.dart' show MorphBetween;
import 'morph_run.dart';

/// [text] in [from]'s style at progress 0, morphing letter by letter into
/// [toText] (or [text] again) in [to]'s style at progress 1.
///
/// The two styles can differ in anything: weight, size, colour, slant and
/// font family, so a serif word can turn into a sans one. They are merged
/// onto the ambient [DefaultTextStyle], as a [Text] merges its style.
///
/// With [toText], one word becomes another: each letter morphs into its
/// counterpart (mostly the letter at the same place; a word slides when
/// that keeps letters as themselves), and any left over grow from or shrink
/// to a point.
///
/// The font families must be bundled with the app (they appear in
/// `FontManifest.json`), because each letter's outline is read from the font
/// file: the nearest declared weight, upright or italic as the style asks.
/// Name a font from a package the Flutter way:
/// `TextStyle(fontFamily: 'Fraunces', package: 'my_package')`.
///
/// At progress 0 and 1, and until the outlines are read, it draws plain
/// text, identical to a one-line [Text] in that style. A letter whose outline
/// can't be read (missing from the bundled font, say) is drawn as text at its
/// moving position instead of morphing.
///
/// For a widget that animates by itself when its text or style changes, see
/// [AnimatedMorphText]; to morph to or from an icon, see [MorphBetween].
class MorphText extends StatelessWidget {
  /// Creates text morphing from [text] in [from] to [toText] (or [text]) in
  /// [to], as [progress] runs.
  const MorphText(
    this.text, {
    super.key,
    required this.from,
    required this.to,
    required this.progress,
    this.toText,
    this.semanticsLabel,
    this.handoff = 0,
  }) : assert(handoff >= 0 && handoff <= 1, 'handoff must be within 0..1');

  /// The text at progress 0, on one line.
  final String text;

  /// The text at progress 1; [text] when null.
  final String? toText;

  /// The style at progress 0.
  final TextStyle from;

  /// The style at progress 1.
  final TextStyle to;

  /// How far from the start to the end, clamped to 0..1, as morphnext's
  /// `MorphIcon` takes it: an [AnimationController], a [CurvedAnimation]
  /// for any curve, or an [AlwaysStoppedAnimation] for a fixed value (a
  /// scroll position, a gesture).
  final Animation<double> progress;

  /// The label announced; when null, [text] until halfway and [toText]
  /// after.
  final String? semanticsLabel;

  /// The share of the morph's end, 0..1, over which the end's plain text
  /// fades in over the outlines, so the switch from outline to hinted text
  /// (which never quite match) blends instead of stepping.
  ///
  /// 0, the default, draws exactly the morph you drive: outlines until
  /// progress is 1, then plain text.
  final double handoff;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: progress,
    builder: (context, _) {
      final t = progress.value;
      final end = toText ?? text;
      return MorphRun(
        text,
        toText: end,
        from: from,
        to: to,
        t: t,
        semanticsLabel: semanticsLabel ?? (t < .5 ? text : end),
        handoff: handoff,
      );
    },
  );
}
