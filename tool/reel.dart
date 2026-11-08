// Shared by the reels (tool/record_*_test.dart): springs sampled per frame,
// a step sequencer for any MorphContent, and the recorder that writes each
// frame to a PNG, or, with REEL_SHEET=1, a contact sheet of a few moments.
// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphtext/morphtext.dart';
import 'package:morphtext/src/morph_run.dart' show MorphMotion;

import '../test/support.dart';

/// Red Hat Display Light, beside the Black the tests bundle: a drastic
/// weight ramp in one family (OFL, unmodified, tool/fonts).
const sansLightAsset = 'packages/morphtext/fonts/RedHatDisplay-Light.otf';

/// Dancing Script (OFL, tool/fonts), for a script face.
const scriptFamily = 'DancingScript';
const scriptAsset = 'fonts/DancingScript.ttf';

/// The test fonts, plus the reels' own: loads them into the engine and into
/// [fontBytes]. Call from setUpAll.
Future<void> loadReelFonts() async {
  await loadFonts();
  Future<ByteData> read(String path) async =>
      ByteData.sublistView(await File(path).readAsBytes());
  final light = await read('tool/fonts/RedHatDisplay-Light.otf');
  fontBytes[sansLightAsset] = light;
  await (FontLoader(sansFamily)..addFont(Future.value(light))).load();
  final script = await read('tool/fonts/DancingScript.ttf');
  fontBytes[scriptAsset] = script;
  await (FontLoader(scriptFamily)..addFont(Future.value(script))).load();
}

/// The test bundle, with the reels' fonts in its manifest.
class ReelFonts extends TestFonts {
  @override
  Future<ByteData> load(String key) async {
    if (key != 'FontManifest.json') return super.load(key);
    final manifest =
        (jsonDecode(utf8.decode((await super.load(key)).buffer.asUint8List()))
                as List<Object?>)
            .cast<Map<String, Object?>>();
    for (final family in manifest) {
      if (family['family'] == sansFamily) {
        (family['fonts']! as List<Object?>).add({
          'asset': sansLightAsset,
          'weight': 300,
        });
      }
    }
    manifest.add({
      'family': scriptFamily,
      'fonts': [
        {'asset': scriptAsset},
      ],
    });
    return ByteData.sublistView(utf8.encode(jsonEncode(manifest)));
  }
}

/// Frames per second.
const fps = 60;

/// The frame, in logical pixels (rendered at 1:1).
const frameSize = Size(1280, 720);

/// A scene: what shows [s] seconds in.
typedef Scene = Widget Function(double s);

/// How long a spring takes to look done; past it the morph lands on plain
/// text, as AnimatedMorph does once its spring settles.
const settled = .6;

/// [spring]'s position [s] seconds after it starts from rest at 0 toward 1.
/// It may overshoot 1, as a real spring does.
double springAt(double s, [SpringDescription spring = MorphSprings.snappy]) {
  if (s <= 0) return 0;
  if (s >= settled) return 1;
  return SpringSimulation(spring, 0, 1, 0).x(s);
}

/// [states] in turn, springing from each to the next at the times in [at],
/// at rest on the first before them. In flight it may overshoot, as an
/// AnimatedMorph does.
Widget steps(
  double s,
  List<MorphContent> states,
  List<double> at, {
  SpringDescription spring = MorphSprings.snappy,
}) {
  var k = 0;
  while (k < at.length && s >= at[k]) {
    k++;
  }
  final from = states[k == 0 ? 0 : k - 1], to = states[k];
  final since = k == 0 ? double.infinity : s - at[k - 1];
  final moving = since < settled;
  return MorphMotion(
    moving: moving,
    child: MorphBetween(
      from: from,
      to: to,
      progress: AlwaysStoppedAnimation(k == 0 ? 0.0 : springAt(since, spring)),
    ),
  );
}

/// Renders [scene] for [seconds] into [dir]/frame_NNNN.png, or with
/// REEL_SHEET=1, the moments [sheet] (or REEL_TIMES, comma-separated
/// seconds) into [dir]/sheet.png at a third of the size, four to a row.
///
/// With REEL_FROM and/or REEL_TO (seconds), it re-renders only the frames
/// in that span and leaves the others as they are, to redo one part.
Future<void> record(
  WidgetTester tester, {
  required Scene scene,
  required double seconds,
  required String dir,
  required List<double> sheet,
}) async {
  tester.view.physicalSize = frameSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  // One bundle for every frame: a new bundle is new fonts to read.
  final bundle = ReelFonts();
  Future<ui.Image> render(double s) async {
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: bundle,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(key: shot, child: scene(s)),
        ),
      ),
    );
    // Each new word reads its letters' outlines before it's captured.
    await settleFonts(tester);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(shot),
    );
    return (await tester.runAsync(boundary.toImage))!;
  }

  final env = Platform.environment;
  final out = Directory(dir)..createSync(recursive: true);
  final times = env['REEL_TIMES'];
  if (times != null) {
    sheet = [for (final t in times.split(',')) double.parse(t.trim())];
  }
  if (env['REEL_SHEET'] == '1') {
    const columns = 4, scale = 1 / 3;
    final rows = (sheet.length / columns).ceil();
    final cell = frameSize * scale;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (var k = 0; k < sheet.length; k++) {
      final image = await render(sheet[k]);
      final at = Offset(
        (k % columns) * cell.width,
        (k ~/ columns) * cell.height,
      );
      canvas.drawImageRect(
        image,
        Offset.zero & frameSize,
        at & cell,
        Paint()..filterQuality = FilterQuality.medium,
      );
      image.dispose();
    }
    final picture = recorder.endRecording();
    await tester.runAsync(() async {
      final image = await picture.toImage(
        (columns * cell.width).round(),
        (rows * cell.height).round(),
      );
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '${out.path}/sheet.png',
      ).writeAsBytes(png!.buffer.asUint8List());
    });
    return;
  }

  final from = double.tryParse(env['REEL_FROM'] ?? '');
  final to = double.tryParse(env['REEL_TO'] ?? '');
  final partial = from != null || to != null;
  if (!partial) {
    for (final f in out.listSync()) {
      f.deleteSync();
    }
  }
  final frames = (seconds * fps).round();
  final first = from == null ? 0 : (from * fps).floor().clamp(0, frames);
  final last = to == null ? frames : (to * fps).ceil().clamp(0, frames);
  for (var i = first; i < last; i++) {
    final image = await render(i / fps);
    await tester.runAsync(() async {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final name = 'frame_${i.toString().padLeft(4, '0')}.png';
      await File('${out.path}/$name').writeAsBytes(png!.buffer.asUint8List());
    });
  }
}
