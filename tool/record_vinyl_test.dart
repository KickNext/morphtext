// The Records example (example/lib/records.dart) on a phone, filmed: MorphText
// inside a real Hero flight. A tap on an album flies its sleeve and title to
// the album page, the record slides out and spins, back tucks it away and
// flies everything home; then the same again at a third of the speed. A real
// Navigator, real Heroes and real taps, pumped frame by frame.
//
//   tool/record_demo.sh vinyl                             # doc/reels/vinyl.*
//   flutter test tool/record_vinyl_test.dart              # build/vinyl_frames
//   REEL_SHEET=1 flutter test tool/record_vinyl_test.dart # a contact sheet

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// The example is its own package, not a dependency of this one.
// ignore: avoid_relative_lib_imports
import '../example/lib/records.dart';
import '../test/support.dart';
import 'reel.dart';

const sleeve = ValueKey('sleeve-moons');
const back = ValueKey('back');

/// The example, in the test bundle's faces (the same fonts, under the
/// package's names).
Widget app() => RecordsApp(
  fonts: (child) => RecordFonts(serif: light, sansFace: sans, child: child),
);

// ---- The frame around the phone ----

const phone = Size(340, 660);

/// A thin margin around the phone, and nothing else.
const margin = 12.0;
final canvasSize = Size(phone.width + 2 * margin, phone.height + 2 * margin);

/// Rendered at 2x, so the clip stays sharp.
const scale = 2.0;

Widget stage(Widget app) => ColoredBox(
  color: ink,
  child: Padding(
    padding: const EdgeInsets.all(margin),
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(38),
        border: Border.all(color: const Color(0xff2c2e33), width: 5),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(33), child: app),
    ),
  ),
);

// ---- Recording ----

/// The take: what happens, for how long in the app's own time, and how much
/// slower than real time the clip shows it. Twice through: once as it is,
/// then the flights again at a third of the speed.
typedef Phase = ({String? tap, double seconds, double slow});

const phases = <Phase>[
  (tap: null, seconds: 1.0, slow: 1),
  (tap: 'open', seconds: 3.9, slow: 1),
  (tap: 'close', seconds: 1.6, slow: 1),
  (tap: null, seconds: .8, slow: 1),
  (tap: 'open', seconds: 1.7, slow: 3),
  (tap: null, seconds: 1.4, slow: 1),
  (tap: 'close', seconds: 1.6, slow: 3),
  (tap: null, seconds: .8, slow: 1),
];

void main() {
  setUpAll(loadReelFonts);

  testWidgets('record the vinyl', (tester) async {
    tester.view.physicalSize = canvasSize * scale;
    tester.view.devicePixelRatio = scale;
    addTearDown(tester.view.reset);

    final bundle = ReelFonts();
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: bundle,
        child: RepaintBoundary(key: shot, child: stage(app())),
      ),
    );
    await settleFonts(tester);

    // A rehearsal, so every word's outlines are read before the take.
    Future<void> run(double seconds) async {
      for (var i = 0; i < (seconds * fps).round(); i++) {
        await tester.pump(const Duration(microseconds: 1000000 ~/ fps));
      }
    }

    await tester.tap(find.byKey(sleeve));
    await run(.1);
    await settleFonts(tester);
    await run(2.5);
    await tester.tap(find.byKey(back));
    await run(3);
    await settleFonts(tester);

    final sheet = Platform.environment['REEL_SHEET'] == '1';
    final out = Directory('build/vinyl_frames')..createSync(recursive: true);
    for (final f in out.listSync()) {
      f.deleteSync();
    }
    final shots = <ui.Image>[];

    var i = 0;
    for (final phase in phases) {
      if (phase.tap == 'open') await tester.tap(find.byKey(sleeve));
      if (phase.tap == 'close') await tester.tap(find.byKey(back));
      final frames = (phase.seconds * phase.slow * fps).round();
      final step = Duration(microseconds: (1000000 / fps / phase.slow).round());
      for (var k = 0; k < frames; k++, i++) {
        await tester.pump(step);
        if (sheet && i % 45 != 0) continue;
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(shot),
        );
        final image = (await tester.runAsync(
          () => boundary.toImage(pixelRatio: scale),
        ))!;
        if (sheet) {
          shots.add(image);
          continue;
        }
        await tester.runAsync(() async {
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          final name = 'frame_${i.toString().padLeft(4, '0')}.png';
          await File(
            '${out.path}/$name',
          ).writeAsBytes(png!.buffer.asUint8List());
        });
      }
    }

    if (sheet) {
      const columns = 6;
      final full = canvasSize * scale;
      final cell = full / 3;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      for (var k = 0; k < shots.length; k++) {
        canvas.drawImageRect(
          shots[k],
          Offset.zero & full,
          Offset((k % columns) * cell.width, (k ~/ columns) * cell.height) &
              cell,
          Paint()..filterQuality = FilterQuality.medium,
        );
      }
      final picture = recorder.endRecording();
      await tester.runAsync(() async {
        final image = await picture.toImage(
          (columns * cell.width).round(),
          ((shots.length / columns).ceil() * cell.height).round(),
        );
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${out.path}/sheet.png',
        ).writeAsBytes(png!.buffer.asUint8List());
      });
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
