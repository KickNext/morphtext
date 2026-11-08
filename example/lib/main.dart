import 'package:flutter/material.dart';
import 'package:morphtext/morphtext.dart';

void main() => runApp(const MorphTextDemo());

const _paper = Color(0xfff8faf9);
const _ink = Color(0xff1f2123);
const _blue = Color(0xff1a73e8);

const _serif = TextStyle(
  fontFamily: 'Fraunces',
  fontWeight: FontWeight.w300,
  fontSize: 52,
  color: _ink,
);
const _bold = TextStyle(
  fontFamily: 'Fraunces',
  fontWeight: FontWeight.w600,
  fontSize: 52,
  color: _ink,
);
const _sans = TextStyle(
  fontFamily: 'RedHatDisplay',
  fontWeight: FontWeight.w900,
  fontSize: 52,
  color: _blue,
);

const stones = ['Amethyst', 'Citrine', 'Quartz', 'Onyx', 'Jade', 'Garnet'];

/// AnimatedMorphText morphing to each new word and font, and MorphText
/// driven by a slider.
class MorphTextDemo extends StatefulWidget {
  const MorphTextDemo({super.key});

  @override
  State<MorphTextDemo> createState() => _MorphTextDemoState();
}

class _MorphTextDemoState extends State<MorphTextDemo> {
  var _stone = 0;
  var _style = 0;
  var _t = 0.0;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'morphtext',
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: _paper,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () =>
                    setState(() => _stone = (_stone + 1) % stones.length),
                child: SizedBox(
                  height: 96,
                  width: 360,
                  child: Center(
                    child: AnimatedMorphText(
                      stones[_stone],
                      style: [_serif, _bold, _sans][_style],
                    ),
                  ),
                ),
              ),
              const Text(
                'tap the word for the next stone',
                style: TextStyle(color: _blue),
              ),
              const SizedBox(height: 16),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Light')),
                  ButtonSegment(value: 1, label: Text('Bold')),
                  ButtonSegment(value: 2, label: Text('Sans')),
                ],
                selected: {_style},
                onSelectionChanged: (s) => setState(() => _style = s.first),
              ),
              const SizedBox(height: 48),
              SizedBox(
                height: 80,
                child: Center(
                  child: MorphText(
                    'Rose Quartz',
                    from: _serif.copyWith(fontSize: 22, color: _blue),
                    to: _serif.copyWith(fontSize: 48, color: _blue),
                    t: _t,
                  ),
                ),
              ),
              SizedBox(
                width: 280,
                child: Slider(
                  value: _t,
                  activeColor: _blue,
                  onChanged: (t) => setState(() => _t = t),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
