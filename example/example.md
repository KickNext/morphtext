# morphtext examples

Three ways in, in one small app: a word that morphs to each new style, a
word that flows into an icon, and a morph you drive yourself along a curve.

## Fonts

morphtext reads each letter's outline from the font file, so bundle every
face you morph between, as you would for `Text`:

```yaml
dependencies:
  morphtext: ^0.1.0

flutter:
  uses-material-design: true # for Icons
  fonts:
    - family: Fraunces
      fonts:
        - asset: fonts/Fraunces-300-normal.ttf
          weight: 300
        - asset: fonts/Fraunces-600-normal.ttf
          weight: 600
```

A family that isn't bundled (a system font, or one downloaded at runtime)
still draws, as plain text that switches at the middle; a debug build says
why.

## The app

```dart
import 'package:flutter/material.dart';
import 'package:morphtext/morphtext.dart';

void main() => runApp(
  const MaterialApp(
    home: Scaffold(body: Center(child: Demo())),
  ),
);

const light = TextStyle(
  fontFamily: 'Fraunces',
  fontWeight: FontWeight.w300,
  fontSize: 52,
);
// Bundled fonts only: each letter's outline is read from the font file.
const label = TextStyle(
  fontFamily: 'Fraunces',
  fontWeight: FontWeight.w600,
  fontSize: 18,
);
const bold = TextStyle(
  fontFamily: 'Fraunces',
  fontWeight: FontWeight.w600,
  fontSize: 52,
);

class Demo extends StatefulWidget {
  const Demo({super.key});

  @override
  State<Demo> createState() => _DemoState();
}

class _DemoState extends State<Demo> with SingleTickerProviderStateMixin {
  var _bold = false;
  var _sent = false;

  // For MorphText: you drive the morph, along any curve.
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // 1. A word that morphs to each new style (or text) it's given.
      GestureDetector(
        onTap: () => setState(() => _bold = !_bold),
        child: AnimatedMorphText('Amethyst', style: _bold ? bold : light),
      ),
      const SizedBox(height: 32),

      // 2. A word that flows into an icon, and back.
      FilledButton(
        onPressed: () => setState(() => _sent = !_sent),
        child: AnimatedMorph(
          _sent
              ? const MorphContent.icon(
                  Icons.check_rounded,
                  semanticsLabel: 'Sent',
                )
              : const MorphContent.text('Send', style: label),
        ),
      ),
      const SizedBox(height: 32),

      // 3. A morph you drive yourself: here a controller through a curve.
      GestureDetector(
        onTap: () => _controller.value < .5
            ? _controller.forward()
            : _controller.reverse(),
        child: MorphText(
          'Rose Quartz',
          toText: 'Smoky Quartz',
          from: light.copyWith(fontSize: 28),
          to: bold.copyWith(fontSize: 44),
          progress: CurvedAnimation(
            parent: _controller,
            curve: Curves.easeInOutCubic,
          ),
          handoff: .1,
        ),
      ),
    ],
  );
}
```

## Options

- **Motion:** `AnimatedMorph` and `AnimatedMorphText` spring with
  `MorphSprings.snappy` by default, as morphnext's `AnimatedMorphIcon` does.
  Pass `spring: MorphSprings.smooth` (no overshoot) or any
  `SpringDescription`; or `curve: Curves.easeOutCubic` with a `duration` for
  fixed timing.
- **Landing:** the text fades in over the outlines in the last 10% of the
  motion (`handoff`). `0` swaps at the end. On `MorphText` and
  `MorphBetween` it defaults to `0`, so a morph you drive is exact.
- **Text into text:** give `MorphText` a `toText`, or change the text of an
  `AnimatedMorphText`: each letter morphs into its counterpart.
- **Icons:** `MorphContent.icon` takes any `IconData` from a bundled icon
  font; its size and colour default to the ambient `IconTheme`.

## The playground

`lib/main.dart` is the full playground at
[morphtext.drei.gg](https://morphtext.drei.gg): every face, size, colour and
motion, status buttons, word-and-icon pairs, and a curve-driven `MorphText`.

```bash
flutter run -d chrome
```
