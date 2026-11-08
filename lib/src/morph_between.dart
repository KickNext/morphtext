import 'package:flutter/widgets.dart';

import 'animated_morph.dart' show AnimatedMorph;
import 'morph_content.dart';
import 'morph_run.dart';
import 'morph_text.dart';

/// [from] at progress 0 morphing into [to] at progress 1, outline into
/// outline: text into text (as [MorphText]), text into an icon, an icon into
/// text, or one icon into another.
///
/// When one end is an icon and the other a word, every letter of the word
/// flows into the icon (or out of it), and they meet as one shape.
///
/// At progress 0 and 1 it draws [from] or [to] exactly as a [Text] or [Icon]
/// would. For a widget that animates by itself, see [AnimatedMorph].
class MorphBetween extends StatelessWidget {
  /// Creates the morph from [from] to [to], as [progress] runs.
  const MorphBetween({
    super.key,
    required this.from,
    required this.to,
    required this.progress,
    this.semanticsLabel,
    this.handoff = 0,
  }) : assert(handoff >= 0 && handoff <= 1, 'handoff must be within 0..1');

  /// What shows at progress 0.
  final MorphContent from;

  /// What shows at progress 1.
  final MorphContent to;

  /// How far from [from] to [to], clamped to 0..1, as morphnext's
  /// `MorphIcon` takes it: an [AnimationController], a [CurvedAnimation]
  /// for any curve, or an [AlwaysStoppedAnimation] for a fixed value.
  final Animation<double> progress;

  /// The label announced; when null, [from]'s until halfway and [to]'s
  /// after.
  final String? semanticsLabel;

  /// The share of the morph's end, 0..1, over which the end's plain text
  /// fades in over the outlines, as [MorphText.handoff]. 0, the default,
  /// draws exactly the morph you drive.
  final double handoff;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: progress,
    builder: (context, _) => _morph(context, progress.value),
  );

  Widget _morph(BuildContext context, double t) {
    final from = this.from, to = this.to;
    if (from.icon == null && to.icon == null) {
      return MorphText(
        from.text!,
        toText: to.text,
        from: from.style ?? const TextStyle(),
        to: to.style ?? const TextStyle(),
        progress: progress,
        handoff: handoff,
        semanticsLabel:
            semanticsLabel ??
            (t < .5
                ? from.semanticsLabel ?? from.text
                : to.semanticsLabel ?? to.text),
      );
    }
    final (textA, styleA, labelA) = _drawn(from, context);
    final (textB, styleB, labelB) = _drawn(to, context);
    return MorphRun(
      textA,
      toText: textB,
      from: styleA,
      to: styleB,
      t: t,
      semanticsLabel: semanticsLabel ?? (t < .5 ? labelA : labelB),
      converge: true,
      handoff: handoff,
    );
  }
}

/// An icon's size with no [IconTheme] size, as `IconThemeData.fallback`.
const _defaultIconSize = 24.0;

/// [content] as the engine draws it: the characters, their style, and the
/// label to announce. An icon is styled as [Icon] styles it, so either end
/// is pixel for pixel an [Icon].
(String, TextStyle, String) _drawn(MorphContent content, BuildContext context) {
  final icon = content.icon;
  if (icon == null) {
    final text = content.text!;
    return (
      text,
      content.style ?? const TextStyle(),
      content.semanticsLabel ?? text,
    );
  }
  final theme = IconTheme.of(context);
  var color = content.color ?? theme.color ?? const Color(0xff000000);
  final opacity = theme.opacity;
  if (content.color == null && opacity != null && opacity != 1) {
    color = color.withValues(alpha: color.a * opacity);
  }
  return (
    String.fromCharCode(icon.codePoint),
    TextStyle(
      inherit: false,
      color: color,
      fontSize: content.size ?? theme.size ?? _defaultIconSize,
      fontFamily: icon.fontFamily,
      package: icon.fontPackage,
      fontFamilyFallback: icon.fontFamilyFallback,
      height: 1,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    content.semanticsLabel ?? '',
  );
}
