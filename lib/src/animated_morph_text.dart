import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:morphnext/morphnext.dart' show MorphSprings;

import 'morph_text.dart';

/// [text] in [style] that morphs, letter by letter, to each new text or
/// style it's given.
///
/// The implicit counterpart of [MorphText], as morphnext's
/// `AnimatedMorphIcon` is to `MorphIcon`: changing [text], [style] or both
/// starts a spring transition from what's on screen. A new word morphs from
/// the old one, letter into letter; a new style morphs
/// weight, size, colour or font. Turning back before it settles reverses
/// from where the word is, keeping its velocity. A third target arriving
/// mid-flight starts from whichever of the two the word is nearer.
///
/// When the platform asks for reduced motion
/// ([MediaQueryData.disableAnimations]), changes apply at once.
class AnimatedMorphText extends StatefulWidget {
  /// Creates text that morphs to each new [text] and [style].
  const AnimatedMorphText(
    this.text, {
    super.key,
    required this.style,
    this.spring = MorphSprings.snappy,
    this.onEnd,
    this.semanticsLabel,
  });

  /// The text to show, on one line, and to morph into when it changes.
  final String text;

  /// The style to show, and to morph toward when it changes.
  final TextStyle style;

  /// The spring that drives each transition (morphnext's [MorphSprings]
  /// work here too).
  final SpringDescription spring;

  /// Called when a transition settles; not for the first text and style,
  /// nor for a transition that was interrupted.
  final VoidCallback? onEnd;

  /// The label announced for this text; [text] when null.
  final String? semanticsLabel;

  @override
  State<AnimatedMorphText> createState() => _AnimatedMorphTextState();
}

typedef _End = (String, TextStyle);

class _AnimatedMorphTextState extends State<AnimatedMorphText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );
  late _End _from = (widget.text, widget.style);
  late _End _to = _from;
  var _run = 0;

  @override
  void didUpdateWidget(AnimatedMorphText old) {
    super.didUpdateWidget(old);
    final target = (widget.text, widget.style);
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _settle(target);
      return;
    }
    if (target == _to) return;
    double velocity;
    if (target == _from && _t.isAnimating) {
      // Turning back: run the same morph the other way from here.
      _from = _to;
      velocity = -_t.velocity;
      _t.value = 1 - _t.value;
    } else {
      _from = _t.value < .5 ? _from : _to;
      velocity = 0;
      _t.value = 0;
    }
    _to = target;
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

  void _settle(_End target) {
    _run++;
    _t.stop();
    _from = _to = target;
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
      _from.$1,
      toText: _to.$1,
      from: _from.$2,
      to: _to.$2,
      t: _t.value,
      semanticsLabel: widget.semanticsLabel ?? widget.text,
    ),
  );
}
