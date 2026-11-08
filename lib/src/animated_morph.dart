import 'dart:math' show max, sqrt;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:morphnext/morphnext.dart' show MorphSprings;

import 'morph_between.dart';
import 'morph_content.dart';
import 'morph_run.dart';

/// [content] that morphs, outline into outline, to each new content it's
/// given: a word into another word or an icon, an icon into a word or
/// another icon, any style into any other.
///
/// The implicit counterpart of [MorphBetween], as morphnext's
/// `AnimatedMorphIcon` is to `MorphIcon`, and driven the same way: changing
/// [content] starts a [spring] (morphnext's [MorphSprings.snappy] by
/// default) from what's on screen. Turning back before it settles reverses
/// from where it is, keeping its velocity. A third target arriving
/// mid-flight starts from whichever of the two is nearer.
///
/// Give it a [curve] instead for a fixed [duration], as Flutter's implicit
/// animations run.
///
/// At rest it is plain text (or an [Icon]), pixel for pixel. Hinted text
/// never quite matches an outline (on the web, light text renders thinner,
/// its baseline snapped to the pixel), so the text fades in over the
/// outlines in the last of the motion ([handoff]), while the word is still
/// moving, rather than switching once it's still.
///
/// When the platform asks for reduced motion
/// ([MediaQueryData.disableAnimations]), changes apply at once.
class AnimatedMorph extends StatefulWidget {
  /// Creates content that morphs to each new [content].
  const AnimatedMorph(
    this.content, {
    super.key,
    this.spring = MorphSprings.snappy,
    this.curve,
    this.duration = defaultDuration,
    this.handoff = defaultHandoff,
    this.onEnd,
    this.semanticsLabel,
  }) : assert(handoff >= 0 && handoff <= 1, 'handoff must be within 0..1');

  /// The default [duration] for a [curve].
  static const defaultDuration = Duration(milliseconds: 350);

  /// The default [handoff]: the last tenth of the morph, chosen by eye on
  /// the web, where the mismatch is largest.
  static const defaultHandoff = .1;

  /// What to show, and to morph into when it changes.
  final MorphContent content;

  /// The spring that drives each morph: morphnext's [MorphSprings] or any
  /// [SpringDescription]. Ignored with a [curve].
  final SpringDescription spring;

  /// A curve to run each morph along over [duration] instead of the
  /// [spring]. Null for the spring.
  final Curve? curve;

  /// How long each morph takes along a [curve].
  final Duration duration;

  /// The share of the morph's end, 0..1, over which the end's plain text
  /// fades in over the outlines, while the word is still moving, so the
  /// switch from outline to hinted text (which never quite match) blends
  /// instead of stepping once it lands. A spring's remaining speed counts
  /// too, so an overshoot in flight is still motion. 0 swaps at the end.
  final double handoff;

  /// Called when a morph ends; not for the first content, nor for a morph
  /// that was interrupted.
  final VoidCallback? onEnd;

  /// The label announced; [content]'s when null.
  final String? semanticsLabel;

  @override
  State<AnimatedMorph> createState() => _AnimatedMorphState();
}

class _AnimatedMorphState extends State<AnimatedMorph>
    with SingleTickerProviderStateMixin {
  /// A spring is done once what's left of its motion is under this many
  /// physical pixels across the widget (as morphnext measures its icons).
  static const _settledPixels = .5;

  /// The morph's clock: linear time along [_curve], or the spring's
  /// position (which may overshoot) when [_curve] is null.
  late final AnimationController _clock = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  /// [_t] as an animation, for [MorphBetween.progress].
  late final Animation<double> _progress = _Progress(this);

  late MorphContent _from = widget.content;
  late MorphContent _to = _from;

  /// This run's curve, or null when a spring drives it.
  Curve? _curve;

  /// This run's spring, or null when a curve drives it.
  SpringDescription? _spring;

  /// The furthest this run's handoff has come: it only goes forward, so a
  /// spring ringing near the end doesn't fade the text in and out.
  var _handedOff = 0.0;

  /// Counts runs, so a finished run can tell it was superseded.
  var _run = 0;

  /// How far the morph shows, from [_from] (0) to [_to] (1).
  double get _t {
    final curve = _curve;
    return curve == null
        ? _clock.value
        : curve.transform(_clock.value.clamp(0, 1));
  }

  @override
  void didUpdateWidget(AnimatedMorph old) {
    super.didUpdateWidget(old);
    final target = widget.content;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _jumpTo(target);
      return;
    }
    if (target == _to) return;
    final curve = widget.curve;
    var velocity = 0.0;
    if (target == _from && _clock.isAnimating) {
      // Turning back: run the same morph the other way from where it is.
      _from = _to;
      velocity = -_clock.velocity;
      final shown = 1 - _t;
      _clock.value = curve == null ? shown : _inverse(curve, shown);
    } else {
      _from = _t < .5 ? _from : _to;
      _clock.value = 0;
    }
    _to = target;
    _handedOff = 0;
    final run = ++_run;
    final TickerFuture motion;
    if (curve == null) {
      final spring = _spring = widget.spring;
      _curve = null;
      motion = _clock.animateWith(
        SpringSimulation(
          spring,
          _clock.value,
          1,
          velocity,
          snapToEnd: true,
          tolerance: _tolerance(),
        ),
      );
    } else {
      _spring = null;
      _curve = curve;
      motion = _clock.animateTo(
        1,
        duration: widget.duration * (1 - _clock.value).clamp(0.0, 1.0),
      );
    }
    motion.whenCompleteOrCancel(() {
      if (run != _run || !mounted) return;
      _clock.value = 1;
      widget.onEnd?.call();
    });
  }

  @override
  void dispose() {
    _run++;
    _clock.dispose();
    super.dispose();
  }

  /// Shows [target] at once, ending any run.
  void _jumpTo(MorphContent target) {
    _run++;
    _clock.stop();
    _from = _to = target;
    _clock.value = 1;
  }

  /// When a spring counts as done: within [_settledPixels] of its end,
  /// across the widget's size. Flutter's default tolerance would creep on
  /// unseen for a quarter of a second before [AnimatedMorph.onEnd].
  Tolerance _tolerance() {
    final box = context.findRenderObject();
    final size = box is RenderBox && box.hasSize ? box.size : null;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final extent = size == null ? 0.0 : size.longestSide * dpr;
    if (!extent.isFinite || extent <= 0) return Tolerance.defaultTolerance;
    final distance = (_settledPixels / extent).clamp(1e-4, 5e-3);
    return Tolerance(distance: distance, velocity: distance * 30);
  }

  /// Where along [curve] it shows [t]: the curve's inverse, by bisection.
  /// Exact for curves that only rise; a fair guess for any other.
  static double _inverse(Curve curve, double t) {
    var low = 0.0, high = 1.0;
    for (var step = 0; step < 40; step++) {
      final mid = (low + high) / 2;
      if (curve.transform(mid) < t) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return (low + high) / 2;
  }

  /// In the last [AnimatedMorph.handoff] of the motion, how far the end's
  /// plain text has faded in over the outlines, 0..1; null before (and at
  /// rest).
  double? _handoff() {
    final window = widget.handoff;
    if (!_clock.isAnimating || window <= 0) return null;
    var left = (1 - _t).abs();
    final spring = _spring;
    if (spring != null) {
      // A spring still moving fast has further to go than its position says.
      left += _clock.velocity.abs() / sqrt(spring.stiffness / spring.mass);
    }
    final along = _handedOff = max(
      _handedOff,
      (1 - left / window).clamp(0.0, 1.0),
    );
    return along == 0 ? null : smoothstep(along);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _clock,
    builder: (context, _) => MorphMotion(
      moving: _clock.isAnimating,
      handoff: _handoff(),
      child: MorphBetween(
        from: _from,
        to: _to,
        progress: _progress,
        semanticsLabel:
            widget.semanticsLabel ??
            widget.content.semanticsLabel ??
            widget.content.text ??
            '',
      ),
    ),
  );
}

/// How far an [AnimatedMorph] shows: its clock through the run's curve, or
/// the spring's position as it is.
class _Progress extends Animation<double>
    with AnimationWithParentMixin<double> {
  _Progress(this._state);

  final _AnimatedMorphState _state;

  @override
  Animation<double> get parent => _state._clock;

  @override
  double get value => _state._t;
}
