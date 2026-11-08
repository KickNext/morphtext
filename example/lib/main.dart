import 'package:flutter/material.dart';
import 'package:morphtext/morphtext.dart';

void main() => runApp(const MorphTextDemo());

const _paper = Color(0xfffaf7f2);
const _ink = Color(0xff1d1b20);
const _plum = Color(0xff6b3fa0);

const _light = TextStyle(
  fontFamily: 'Fraunces',
  fontWeight: FontWeight.w300,
  fontSize: 52,
  color: _ink,
);

/// Two morphs: a word that turns bold when tapped (AnimatedMorphText), and
/// one that grows as the slider moves (MorphText, driven by t).
class MorphTextDemo extends StatefulWidget {
  const MorphTextDemo({super.key});

  @override
  State<MorphTextDemo> createState() => _MorphTextDemoState();
}

class _MorphTextDemoState extends State<MorphTextDemo> {
  var _bold = false;
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
                onTap: () => setState(() => _bold = !_bold),
                child: SizedBox(
                  height: 96,
                  child: Center(
                    child: AnimatedMorphText(
                      'Amethyst',
                      style: _bold
                          ? _light.copyWith(fontWeight: FontWeight.w600)
                          : _light,
                    ),
                  ),
                ),
              ),
              const Text('tap the word', style: TextStyle(color: _plum)),
              const SizedBox(height: 48),
              SizedBox(
                height: 80,
                child: Center(
                  child: MorphText(
                    'Rose Quartz',
                    from: _light.copyWith(fontSize: 22, color: _plum),
                    to: _light.copyWith(fontSize: 48, color: _plum),
                    t: _t,
                  ),
                ),
              ),
              SizedBox(
                width: 280,
                child: Slider(
                  value: _t,
                  activeColor: _plum,
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
