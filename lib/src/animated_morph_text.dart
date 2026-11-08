import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:morphnext/morphnext.dart' show MorphSprings;

import 'morph_text.dart';

/// [text] that morphs, letter by letter, to each new [style] it's given.
///
/// The implicit counterpart of [MorphText], as morphnext's
/// `AnimatedMorphIcon` is to `MorphIcon`: changing [style] starts a spring
/// transition from the style on screen. Turning back before it settles
/// reverses from where the word is, keeping its velocity. A third style
/// arriving mid-flight starts from whichever of the two the word is nearer.
///
/// Changing [text] doesn't morph; the new text appears in [style]. When the
/// platform asks for reduced motion
/// ([MediaQueryData.disableAnimations]), style changes apply at once.
class AnimatedMorphText extends StatefulWidget {
  /// Creates text that morphs to each new [style].
  const AnimatedMorphText(
    this.text, {
    super.key,
    required this.style,
    this.spring = MorphSprings.snappy,
    this.onEnd,
    this.semanticsLabel,
  });

  /// The text to draw, on one line.
  final String text;

  /// The style to show, and to morph toward when it changes.
  final TextStyle style;

  /// The spring that drives each transition (morphnext's [MorphSprings]
  /// work here too).
  final SpringDescription spring;

  /// Called when a transition settles on its style; not for the first
  /// style, nor for a transition that was interrupted.
  final VoidCallback? onEnd;

  /// The label announced for this text; [text] when null.
  final String? semanticsLabel;

  @override
  State<AnimatedMorphText> createState() => _AnimatedMorphTextState();
}

class _AnimatedMorphTextState extends State<AnimatedMorphText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );
  late TextStyle _from = widget.style;
  late TextStyle _to = widget.style;
  var _run = 0;

  @override
  void didUpdateWidget(AnimatedMorphText old) {
    super.didUpdateWidget(old);
    final style = widget.style;
    if (widget.text != old.text ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      _settle(style);
      return;
    }
    if (style == _to) return;
    double velocity;
    if (style == _from && _t.isAnimating) {
      // Turning back: the same word, run the other way from here.
      _from = _to;
      velocity = -_t.velocity;
      _t.value = 1 - _t.value;
    } else {
      _from = _t.value < .5 ? _from : _to;
      velocity = 0;
      _t.value = 0;
    }
    _to = style;
    final run = ++_run;
    _t
        .animateWith(SpringSimulation(widget.spring, _t.value, 1, velocity))
        .whenCompleteOrCancel(() {
          if (run != _run || !mounted) return;
          // A spring only nears its end; land on it, where it's plain text.
          _t.value = 1;
          widget.onEnd?.call();
        });
  }

  void _settle(TextStyle style) {
    _run++;
    _t.stop();
    _from = _to = style;
    _t.value = 1;
  }

  @override
  void dispose() {
    _run++;
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _t,
    builder: (context, _) => MorphText(
      widget.text,
      from: _from,
      to: _to,
      t: _t.value,
      semanticsLabel: widget.semanticsLabel,
    ),
  );
}
