// A visual check: text-to-icon and icon-to-icon morphs at t = 0, .25, .5,
// .75 and 1, side by side, written to build/icon_strip.png.
//
//   flutter test tool/icon_strip_test.dart

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphtext/morphtext.dart';

import '../test/support.dart';

void main() {
  setUpAll(loadFonts);

  testWidgets('icon strip', (tester) async {
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const ink = Color(0xff1d1b20);
    final rows = [
      (
        MorphContent.text('Send', style: sans.copyWith(fontSize: 64)),
        const MorphContent.icon(Icons.check_rounded, size: 96, color: ink),
      ),
      (
        MorphContent.text('Jade', style: bold.copyWith(fontSize: 64)),
        const MorphContent.icon(Icons.favorite, size: 96, color: ink),
      ),
      (
        const MorphContent.icon(Icons.menu_rounded, size: 96, color: ink),
        const MorphContent.icon(Icons.close_rounded, size: 96, color: ink),
      ),
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
                  for (final (from, to) in rows)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (final t in [0.0, .25, .5, .75, 1.0])
                            MorphBetween(
                              from: from,
                              to: to,
                              progress: AlwaysStoppedAnimation(t),
                            ),
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
      File('build/icon_strip.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
