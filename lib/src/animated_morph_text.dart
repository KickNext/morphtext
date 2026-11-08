import 'package:flutter/widgets.dart';
import 'package:morphnext/morphnext.dart' show MorphSprings;

import 'animated_morph.dart';
import 'morph_content.dart';
import 'morph_text.dart' show MorphText;

/// [text] in [style] that morphs, letter by letter, to each new text or
/// style it's given.
///
/// The implicit counterpart of [MorphText], as morphnext's
/// `AnimatedMorphIcon` is to `MorphIcon`: changing [text], [style] or both
/// starts a [spring] (morphnext's [MorphSprings.snappy] by default) from
/// what's on screen. A new word morphs from the old one, letter into
/// letter; a new style morphs weight, size, colour or font. Turning back
/// before it settles reverses from where the word is, keeping its velocity.
/// Give it a [curve] for a fixed [duration] instead.
///
/// Shorthand for an [AnimatedMorph] of [MorphContent.text] (see there for
/// how it draws at rest); use that to morph to or from an icon.
class AnimatedMorphText extends StatelessWidget {
  /// Creates text that morphs to each new [text] and [style].
  const AnimatedMorphText(
    this.text, {
    super.key,
    required this.style,
    this.spring = MorphSprings.snappy,
    this.curve,
    this.duration = AnimatedMorph.defaultDuration,
    this.handoff = AnimatedMorph.defaultHandoff,
    this.onEnd,
    this.semanticsLabel,
  });

  /// The text to show, on one line, and to morph into when it changes.
  final String text;

  /// The style to show, and to morph toward when it changes.
  final TextStyle style;

  /// The spring that drives each morph: morphnext's [MorphSprings] or any
  /// [SpringDescription]. Ignored with a [curve].
  final SpringDescription spring;

  /// A curve to run each morph along over [duration] instead of the
  /// [spring]. Null for the spring.
  final Curve? curve;

  /// How long each morph takes along a [curve].
  final Duration duration;

  /// The share of the morph's end over which the plain text fades in; see
  /// [AnimatedMorph.handoff].
  final double handoff;

  /// Called when a morph ends; not for the first text and style, nor for a
  /// morph that was interrupted.
  final VoidCallback? onEnd;

  /// The label announced for this text; [text] when null.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => AnimatedMorph(
    MorphContent.text(text, style: style),
    spring: spring,
    curve: curve,
    duration: duration,
    handoff: handoff,
    onEnd: onEnd,
    semanticsLabel: semanticsLabel ?? text,
  );
}
