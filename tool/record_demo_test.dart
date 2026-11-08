// Renders the README hero frame by frame, as a widget test (no device, no
// screen recorder): `tool/record_demo.sh` runs it and encodes the frames.
//
//   flutter test tool/record_demo_test.dart   # writes doc/frames/*.png
//
// It follows the grammar of morphnext's own hero (1280x720, 60 fps, a light
// opening, a specimen, a claim with counters, a dark grid finale, a footer
// and a progress line), so the two read as a pair, with words where
// morphnext has icons.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphtext/morphtext.dart';

import '../test/support.dart';

// morphnext's hero palette.
const paper = Color(0xfff8faf9);
const night = Color(0xff17191a);
const ink = Color(0xff1f2123);
const blue = Color(0xff1a73e8);
const quiet = Color(0xff9aa0a6);
const pastels = [
  Color(0xff8ab4f8),
  Color(0xfff28b82),
  Color(0xfffdd663),
  Color(0xff81c995),
  Color(0xffc58af9),
];

const fps = 60;
const width = 1280.0, height = 720.0;

// Acts, in seconds.
const act2 = 4.0, act3 = 9.0, act4 = 13.5, end = 18.5;

/// The critically damped spring (morphnext's MorphSprings.smooth), sampled.
const smooth = SpringDescription(mass: 1, stiffness: 170, damping: 26);
double spring(double s) =>
    s <= 0 ? 0 : SpringSimulation(smooth, 0, 1, 0).x(s).clamp(0.0, 1.0);

/// A value that starts at [from] and flips (0 <-> 1) at each of [at],
/// springing each time.
double flips(double s, List<double> at, {double from = 0}) {
  var v = from;
  for (final time in at) {
    if (s < time) break;
    final target = 1 - v.roundToDouble();
    v = v + (target - v) * spring(s - time);
  }
  return v;
}

TextStyle face(double size, {FontWeight weight = FontWeight.w300, Color? c}) =>
    light.copyWith(fontSize: size, fontWeight: weight, color: c ?? ink);

Widget morph(String text, double size, double t, {Color? color}) => MorphText(
  text,
  from: face(size, c: color),
  to: face(size, weight: FontWeight.w600, c: color),
  t: t,
);

/// Red Hat Display Black: another font entirely.
TextStyle sansFace(double size, {Color? c}) =>
    sans.copyWith(fontSize: size, color: c ?? ink);

/// Text through [states] (a word and its style), springing from each to the
/// next at the times in [at]; at rest on the first before them.
Widget steps(double s, List<(String, TextStyle)> states, List<double> at) {
  var k = 0;
  while (k < at.length && s >= at[k]) {
    k++;
  }
  final from = states[k == 0 ? 0 : k - 1], to = states[k];
  final t = k == 0 ? 0.0 : spring(s - at[k - 1]);
  return MorphText(from.$1, toText: to.$1, from: from.$2, to: to.$2, t: t);
}

/// Act 1: one word around the corners: light to bold, small to large,
/// serif to sans, and back to where it started.
Widget opening(double s) => Center(
  child: steps(
    s,
    [
      ('Amethyst', face(96)),
      ('Amethyst', face(96, weight: FontWeight.w600)),
      ('Amethyst', face(150, weight: FontWeight.w600)),
      ('Amethyst', sansFace(150)),
      ('Amethyst', face(96)),
    ],
    const [0.4, 1.3, 2.2, 3.1],
  ),
);

/// Act 2: a giant letter becoming the next, beside a phrase becoming the
/// next word, light and bold by turns, ending in another font.
Widget specimen(double s) {
  const letters = ['a', 'g', 'R', '&', 'Q'];
  const words = ['Every', 'letter,', 'outline', 'into outline,', 'any font.'];
  TextStyle style(int k, double size) => k == 4
      ? sansFace(size)
      : face(size, weight: k.isOdd ? FontWeight.w600 : FontWeight.w300);
  final at = [for (var k = 0; k < 4; k++) act2 + .25 + k * 1.15];
  return Stack(
    children: [
      Positioned(
        left: 90,
        width: 380,
        top: 0,
        bottom: 0,
        child: Center(
          child: steps(s, [
            for (var k = 0; k < 5; k++) (letters[k], style(k, 300)),
          ], at),
        ),
      ),
      Positioned(
        left: 540,
        right: 40,
        top: 0,
        bottom: 0,
        child: Align(
          alignment: Alignment.centerLeft,
          child: steps(s, [
            for (var k = 0; k < 5; k++) (words[k], style(k, 84)),
          ], at),
        ),
      ),
    ],
  );
}

/// Act 3: the claim, the counters, and a blue word.
Widget claim(double s) {
  final t = flips(s, [act3 + .5, act3 + 1.6, act3 + 2.7, act3 + 3.8]);
  final weight = (300 + 300 * t).round();
  Widget label(String text) => SizedBox(
    width: 128,
    child: Text(text, style: face(13, c: quiet).copyWith(letterSpacing: 2.5)),
  );
  return Stack(
    children: [
      Positioned(
        left: 70,
        top: 150,
        child: Text(
          'Every weight\nin between.',
          style: face(68, weight: FontWeight.w600).copyWith(height: 1.0),
        ),
      ),
      Positioned(
        left: 74,
        top: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                label('SHIPPED'),
                Text('300 · 600', style: face(34)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                label('DRAWN'),
                Text(
                  '$weight',
                  style: face(56, c: blue).copyWith(
                    fontFeatures: const [ui.FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      Positioned(
        left: 640,
        right: 40,
        top: 0,
        bottom: 0,
        child: Center(child: morph('Quartz', 150, t, color: blue)),
      ),
    ],
  );
}

/// Act 4: a grid of stones, each becoming another stone in another face,
/// in a diagonal wave.
Widget grid(double s) {
  const names = [
    'Amethyst', 'Citrine', 'Jade', 'Onyx', //
    'Opal', 'Garnet', 'Topaz', 'Jasper',
    'Pyrite', 'Quartz', 'Agate', 'Beryl',
    'Coral', 'Peridot', 'Ruby', 'Lapis',
  ];
  return Padding(
    padding: const EdgeInsets.fromLTRB(100, 110, 100, 110),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var r = 0; r < 4; r++)
          Row(
            children: [
              for (var c = 0; c < 4; c++)
                Expanded(child: Center(child: _cell(s, r, c, names))),
            ],
          ),
      ],
    ),
  );
}

Widget _cell(double s, int r, int c, List<String> names) {
  final n = r * 4 + c;
  final color = pastels[n % pastels.length];
  // Light, bold, sans, light again; every other cell a step ahead.
  final faces = [
    face(46, c: color),
    face(46, weight: FontWeight.w600, c: color),
    sansFace(42, c: color),
  ];
  final first = (r + c) % 3;
  return steps(
    s,
    [
      for (var k = 0; k < 4; k++)
        (names[(n + 5 * k) % names.length], faces[(first + k) % 3]),
    ],
    [
      for (final at in [14.0, 15.5, 17.0]) at + .07 * (r + c),
    ],
  );
}

Widget scene(double s) {
  final dark = s >= act4;
  final body = s < act2
      ? opening(s)
      : s < act3
      ? specimen(s)
      : s < act4
      ? claim(s)
      : grid(s);
  return ColoredBox(
    color: dark ? night : paper,
    child: Stack(
      children: [
        Positioned.fill(child: body),
        Positioned(
          left: 40,
          bottom: 26,
          child: Text(
            'drei.gg   ·   morphtext',
            style: face(
              13,
              c: dark ? const Color(0xff5f6368) : quiet,
            ).copyWith(letterSpacing: 1.5),
          ),
        ),
        Positioned(
          left: 0,
          bottom: 0,
          height: 3,
          width: width * s / end,
          child: ColoredBox(
            color: dark
                ? const Color(0xffe8eaed)
                : s >= act3
                ? blue
                : ink,
          ),
        ),
      ],
    ),
  );
}

void main() {
  setUpAll(loadFonts);

  testWidgets('record the hero', (tester) async {
    tester.view.physicalSize = const Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // One bundle for every frame: a new bundle is new fonts to read.
    final bundle = TestFonts();
    Widget frame(double s) => DefaultAssetBundle(
      bundle: bundle,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(key: shot, child: scene(s)),
      ),
    );

    final dir = Directory('doc/frames')..createSync(recursive: true);
    for (final f in dir.listSync()) {
      f.deleteSync();
    }
    final frames = (end * fps).round();
    for (var i = 0; i < frames; i++) {
      await tester.pumpWidget(frame(i / fps));
      // Each new word reads its letters' outlines before it's captured.
      await settleFonts(tester);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(shot),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final name = 'frame_${i.toString().padLeft(4, '0')}.png';
        await File('${dir.path}/$name').writeAsBytes(png!.buffer.asUint8List());
      });
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
