import 'dart:async';

import 'package:flutter/material.dart';
import 'package:morphtext/morphtext.dart';

import 'icons_card.dart';
import 'palette.dart';
import 'widgets.dart';

void main() => runApp(const MorphTextDemo());

const stones = ['Amethyst', 'Citrine', 'Quartz', 'Onyx', 'Jade', 'Garnet'];

/// The faces bundled with the playground (see pubspec.yaml).
enum Face {
  light('Light', 'Fraunces', FontWeight.w300),
  bold('Bold', 'Fraunces', FontWeight.w600),
  sans('Sans', 'RedHatDisplay', FontWeight.w900);

  const Face(this.label, this.family, this.weight);
  final String label;
  final String family;
  final FontWeight weight;

  TextStyle style(double size, Color color) => TextStyle(
    fontFamily: family,
    fontWeight: weight,
    fontSize: size,
    color: color,
  );
}

const _colors = [
  Palette.ink,
  Palette.blue,
  Color(0xffc2410c),
  Color(0xff0f766e),
];

/// How the stage morphs: morphnext's springs, or a curve.
enum Motion {
  snappy('Snappy', 'spring: MorphSprings.snappy', spring: MorphSprings.snappy),
  smooth('Smooth', 'spring: MorphSprings.smooth', spring: MorphSprings.smooth),
  easeOut('Ease out', 'curve: Curves.easeOutCubic', curve: Curves.easeOutCubic),
  easeInOut(
    'Ease in-out',
    'curve: Curves.easeInOutCubic',
    curve: Curves.easeInOutCubic,
  );

  const Motion(this.label, this.code, {this.spring, this.curve});
  final String label;
  final String code;
  final SpringDescription? spring;
  final Curve? curve;
}

/// Curves for driving MorphText's progress by hand.
const _curves = <(String, String, Curve)>[
  ('Ease in-out', 'Curves.easeInOutCubic', Curves.easeInOutCubic),
  ('Linear', 'Curves.linear', Curves.linear),
  ('Ease out back', 'Curves.easeOutBack', Curves.easeOutBack),
  ('Bounce out', 'Curves.bounceOut', Curves.bounceOut),
];

/// The morphtext playground: AnimatedMorphText morphing to each word, face,
/// size, colour and motion you pick, and MorphText driven by a controller
/// through a curve.
class MorphTextDemo extends StatefulWidget {
  const MorphTextDemo({super.key, this.cycle = true});

  /// Whether the stage starts by morphing through [stones] on its own, until
  /// the first touch.
  final bool cycle;

  @override
  State<MorphTextDemo> createState() => _MorphTextDemoState();
}

class _MorphTextDemoState extends State<MorphTextDemo>
    with SingleTickerProviderStateMixin {
  var _stone = 0;
  String? _typed;
  var _face = Face.light;
  var _size = 72.0;
  var _color = Palette.ink;
  var _motion = Motion.snappy;
  var _handoff = AnimatedMorph.defaultHandoff;
  Timer? _cycle;

  var _from = 'Quartz';
  var _to = 'Garnet';
  var _curve = 0;

  /// MorphText's progress: this controller through the chosen curve.
  late final AnimationController _scrub = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late CurvedAnimation _progress = CurvedAnimation(
    parent: _scrub,
    curve: _curves[_curve].$3,
  );

  String get _word => _typed ?? stones[_stone];

  @override
  void initState() {
    super.initState();
    if (widget.cycle) {
      _cycle = Timer.periodic(const Duration(milliseconds: 2400), (_) {
        setState(() {
          _stone = (_stone + 1) % stones.length;
          // Every other stone changes face too, so a visitor who never
          // touches anything still sees a font morph.
          if (_stone.isEven) {
            _face = Face.values[(_face.index + 1) % Face.values.length];
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _cycle?.cancel();
    _progress.dispose();
    _scrub.dispose();
    super.dispose();
  }

  void _pickCurve(int k) {
    setState(() {
      _curve = k;
      _progress.dispose();
      _progress = CurvedAnimation(parent: _scrub, curve: _curves[k].$3);
    });
  }

  /// Plays MorphText's controller to the other end.
  void _play() {
    if (_scrub.value < .5) {
      _scrub.forward();
    } else {
      _scrub.reverse();
    }
  }

  /// Applies a visitor's change and stops the stage cycling on its own.
  void _touch(VoidCallback change) {
    _cycle?.cancel();
    _cycle = null;
    setState(change);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'morphtext',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Palette.blue,
        surface: Palette.paper,
      ),
      scaffoldBackgroundColor: Palette.paper,
      sliderTheme: const SliderThemeData(
        activeTrackColor: Palette.blue,
        thumbColor: Palette.blue,
      ),
    ),
    home: Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PageHeader(),
                  const SizedBox(height: 32),
                  _stage(),
                  const SizedBox(height: 24),
                  const IconsCard(),
                  const SizedBox(height: 24),
                  _controlled(),
                  const SizedBox(height: 32),
                  const PageFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _stage() => DemoCard(
    title: 'AnimatedMorphText',
    note: 'Change the word, face, size or colour; it springs to the new one.',
    children: [
      GestureDetector(
        onTap: () => _touch(() {
          _typed = null;
          _stone = (_stone + 1) % stones.length;
        }),
        child: SizedBox(
          height: 150,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedMorphText(
                _word,
                style: _face.style(_size, _color),
                spring: _motion.spring ?? MorphSprings.snappy,
                curve: _motion.curve,
                handoff: _handoff,
              ),
            ),
          ),
        ),
      ),
      const Text(
        'tap the word for the next stone, or type your own',
        textAlign: TextAlign.center,
        style: TextStyle(color: Palette.muted, fontSize: 13),
      ),
      const SizedBox(height: 16),
      TextField(
        maxLength: 16,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          hintText: 'Type a word and press Enter',
          border: OutlineInputBorder(),
          isDense: true,
          counterText: '',
        ),
        onSubmitted: (s) => _touch(() {
          final word = s.trim();
          _typed = word.isEmpty ? null : word;
        }),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 16,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SegmentedButton<Face>(
            showSelectedIcon: false,
            segments: [
              for (final f in Face.values)
                ButtonSegment(value: f, label: Text(f.label)),
            ],
            selected: {_face},
            onSelectionChanged: (s) => _touch(() => _face = s.first),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in _colors)
                Swatch(
                  color: c,
                  selected: c == _color,
                  onTap: () => _touch(() => _color = c),
                ),
            ],
          ),
        ],
      ),
      Row(
        children: [
          const Text('Size', style: TextStyle(color: Palette.muted)),
          Expanded(
            child: Slider(
              key: const Key('size'),
              value: _size,
              min: 32,
              max: 120,
              onChanged: (s) => _touch(() => _size = s),
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Motion', style: TextStyle(color: Palette.muted)),
          for (final m in Motion.values)
            ChoiceChip(
              label: Text(m.label),
              selected: m == _motion,
              showCheckmark: false,
              // Not a touch: the stones keep cycling, so each motion shows.
              onSelected: (_) => setState(() => _motion = m),
            ),
        ],
      ),
      Row(
        children: [
          const Text('Text fade', style: TextStyle(color: Palette.muted)),
          Expanded(
            child: Slider(
              key: const Key('handoff'),
              value: _handoff,
              max: .3,
              divisions: 30,
              onChanged: (h) => setState(() => _handoff = h),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '${(_handoff * 100).round()}%',
              style: const TextStyle(
                color: Palette.muted,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
      CodeLine('${_motion.code}, handoff: ${_handoff.toStringAsFixed(2)}'),
    ],
  );

  Widget _controlled() => DemoCard(
    title: 'MorphText',
    note:
        'Drive progress yourself, as morphnext\'s MorphIcon takes it: an '
        'AnimationController through any curve. Light to Sans, word to word.',
    children: [
      SizedBox(
        height: 110,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: MorphText(
              _from,
              toText: _to,
              from: Face.light.style(36, Palette.ink),
              to: Face.sans.style(64, Palette.blue),
              progress: _progress,
              handoff: .1,
            ),
          ),
        ),
      ),
      AnimatedBuilder(
        animation: _scrub,
        builder: (context, _) => Row(
          children: [
            IconButton(
              key: const Key('play'),
              tooltip: _scrub.value < .5 ? 'Play' : 'Play back',
              onPressed: _play,
              icon: Icon(
                _scrub.value < .5
                    ? Icons.play_arrow_rounded
                    : Icons.replay_rounded,
              ),
            ),
            Expanded(
              child: Slider(
                key: const Key('t'),
                value: _scrub.value,
                onChanged: (v) {
                  _scrub.stop();
                  _scrub.value = v;
                },
              ),
            ),
            SizedBox(
              width: 36,
              child: Text(
                _progress.value.toStringAsFixed(2),
                style: const TextStyle(
                  color: Palette.muted,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Curve', style: TextStyle(color: Palette.muted)),
          for (var k = 0; k < _curves.length; k++)
            ChoiceChip(
              label: Text(_curves[k].$1),
              selected: k == _curve,
              showCheckmark: false,
              onSelected: (_) => _pickCurve(k),
            ),
        ],
      ),
      const SizedBox(height: 8),
      CodeLine(
        'progress: CurvedAnimation(parent: controller, '
        'curve: ${_curves[_curve].$2}), handoff: 0.1',
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: WordField(
              label: 'from',
              initial: _from,
              onChanged: (s) => setState(() => _from = s),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: WordField(
              label: 'to',
              initial: _to,
              onChanged: (s) => setState(() => _to = s),
            ),
          ),
        ],
      ),
    ],
  );
}
