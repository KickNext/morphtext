// Renders the README demo frame by frame, as a widget test (no device, no
// screen recorder): `tool/record_demo.sh` runs it and encodes the frames.
//
//   flutter test tool/record_demo_test.dart   # writes doc/frames/*.png

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphtext/morphtext.dart';

import '../test/support.dart';

const paper = Color(0xfffaf7f2);
const ink = Color(0xff1d1b20);
const plum = Color(0xff6b3fa0);

void main() {
  setUpAll(loadFonts);

  testWidgets('record the demo', (tester) async {
    tester.view.physicalSize = const Size(800, 440);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final weightFrom = light.copyWith(fontSize: 52, color: ink);
    final weightTo = bold.copyWith(fontSize: 52, color: ink);
    final sizeFrom = light.copyWith(fontSize: 22, color: plum);
    final sizeTo = light.copyWith(fontSize: 48, color: plum);

    // One bundle for every frame: a new bundle is new fonts to read.
    final bundle = TestFonts();
    Widget frame(double t) => DefaultAssetBundle(
      bundle: bundle,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: shot,
          child: ColoredBox(
            color: paper,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 96,
                  child: Center(
                    child: MorphText(
                      'Amethyst',
                      from: weightFrom,
                      to: weightTo,
                      t: t,
                    ),
                  ),
                ),
                SizedBox(
                  height: 80,
                  child: Center(
                    child: MorphText(
                      'Rose Quartz',
                      from: sizeFrom,
                      to: sizeTo,
                      t: t,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // 30 fps: hold, morph, hold, morph back.
    const hold = 18, morph = 27;
    final ts = <double>[
      for (var i = 0; i < hold; i++) 0,
      for (var i = 1; i <= morph; i++)
        Curves.easeInOutCubic.transform(i / morph),
      for (var i = 0; i < hold; i++) 1,
      for (var i = 1; i <= morph; i++)
        1 - Curves.easeInOutCubic.transform(i / morph),
    ];

    final dir = Directory('doc/frames')..createSync(recursive: true);
    for (final f in dir.listSync()) {
      f.deleteSync();
    }
    await tester.pumpWidget(frame(.5));
    await settleFonts(tester);
    for (var i = 0; i < ts.length; i++) {
      await tester.pumpWidget(frame(ts[i]));
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(shot),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final name = 'frame_${i.toString().padLeft(3, '0')}.png';
        await File('${dir.path}/$name').writeAsBytes(png!.buffer.asUint8List());
      });
    }
  });
}
