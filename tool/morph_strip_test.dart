// A visual check: word-to-word and font-to-font morphs at t = 0, .25, .5,
// .75 and 1, side by side, written to build/morph_strip.png.
//
//   flutter test tool/morph_strip_test.dart

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphtext/morphtext.dart';

import '../test/support.dart';

void main() {
  setUpAll(loadFonts);

  testWidgets('morph strip', (tester) async {
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final l = light.copyWith(fontSize: 64);
    final b = bold.copyWith(fontSize: 64);
    final s = sans.copyWith(fontSize: 64);
    final rows = [
      ('Amethyst', 'Amber', l, b),
      ('Amethyst', 'Citrine', l, b),
      ('Quartz', 'Onyx', l, s),
    ];
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: TestFonts(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: shot,
            child: ColoredBox(
              color: const Color(0xfff8faf9),
              child: Row(
                children: [
                  for (final (from, to, a, z) in rows)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (final t in [0.0, .25, .5, .75, 1.0])
                            MorphText(from, toText: to, from: a, to: z, t: t),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await settleFonts(tester);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(shot),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build').createSync();
      File('build/morph_strip.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
