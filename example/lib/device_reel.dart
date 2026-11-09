// Reels rendered on the device itself (system_font_reel.dart,
// system_font_flyer.dart): every frame drawn by the phone, the system
// font's outlines read from iOS. Like tool/reel.dart, each spring is sampled
// per frame rather than run in real time, so every frame lands exactly.

// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:morphtext/morphtext.dart';
import 'package:morphtext/src/morph_run.dart' show MorphMotion;

/// Frames per second.
const fps = 60;

/// How long a spring takes to look done (tool/reel.dart).
const settled = .6;

/// A spring's position [s] seconds after it starts from rest at 0 toward 1.
double springAt(double s, [SpringDescription spring = MorphSprings.snappy]) {
  if (s <= 0) return 0;
  if (s >= settled) return 1;
  return SpringSimulation(spring, 0, 1, 0).x(s);
}

/// [states] in turn, springing from each to the next at the times in [at].
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
  return MorphMotion(
    moving: since < settled,
    child: MorphBetween(
      from: from,
      to: to,
      progress: AlwaysStoppedAnimation(k == 0 ? 0.0 : springAt(since, spring)),
    ),
  );
}

/// Text to morph.
MorphContent text(String text, TextStyle style) =>
    MorphContent.text(text, style: style);

/// Shows [scene] and records it, [seconds] long at [fps], to the app's
/// Documents/[name] as [frame] logical pixels at [ratio].
class DeviceReel extends StatefulWidget {
  /// Records [scene].
  const DeviceReel({
    super.key,
    required this.scene,
    required this.seconds,
    required this.name,
    this.frame = const Size(360, 640),
    this.ratio = 3,
  });

  /// What shows `s` seconds in.
  final Widget Function(double s) scene;

  /// How long it runs.
  final double seconds;

  /// The folder in Documents its frames go to.
  final String name;

  /// The frame, in logical pixels.
  final Size frame;

  /// Device pixels per logical pixel in the frames.
  final double ratio;

  @override
  State<DeviceReel> createState() => _DeviceReelState();
}

class _DeviceReelState extends State<DeviceReel> {
  final _shot = GlobalKey();
  var _s = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _record());
  }

  /// Shows [s], then waits for any outlines it newly needs to be read and
  /// paired (a frame or two) before it's captured.
  Future<void> _show(double s) async {
    setState(() => _s = s);
    for (var k = 0; k < 3; k++) {
      await Future<void>.delayed(Duration.zero);
      WidgetsBinding.instance.scheduleFrame();
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  Future<void> _record() async {
    final dir = Directory(
      '${Directory.systemTemp.parent.path}/Documents/${widget.name}',
    );
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    final frames = (widget.seconds * fps).round();
    // A first pass reads every face and plans every letter pair.
    for (var i = 0; i < frames; i += 6) {
      await _show(i / fps);
    }
    final clock = Stopwatch()..start();
    for (var i = 0; i < frames; i++) {
      await _show(i / fps);
      final boundary =
          _shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: widget.ratio);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File(
        '${dir.path}/frame_${i.toString().padLeft(4, '0')}.png',
      ).writeAsBytesSync(png!.buffer.asUint8List());
      if (i % 60 == 0) debugPrint('REEL frame $i/$frames');
    }
    final done =
        'REEL done $frames frames in ${clock.elapsedMilliseconds} ms '
        'to ${dir.path}';
    debugPrint(done);
    // Release builds log nothing back to `flutter run`: a marker to wait on.
    File('${dir.path}/done.txt').writeAsStringSync(done);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: const Color(0xff000000),
      body: Center(
        child: RepaintBoundary(
          key: _shot,
          child: SizedBox.fromSize(size: widget.frame, child: widget.scene(_s)),
        ),
      ),
    ),
  );
}
