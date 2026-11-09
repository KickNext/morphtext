// The Apple system font (SF Pro), morphing: no font bundled, the outlines
// read from CoreText. Run on an iPhone or a Mac:
//
//   flutter run -t lib/system_font_main.dart
//
// On launch it also checks its own outlines against what Text draws, at
// several sizes, weights and optical sizes, and logs each match as
// `SFCHECK` lines.

// The check reads the engine directly; the demo uses only the public API.
// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:morphtext/morphtext.dart';
import 'package:morphtext/src/engine.dart';
import 'package:morphtext/src/system_font.dart';
import 'package:morphtext/src/word_layout.dart';

void main() => runApp(const SystemFontDemo());

/// The demo app.
class SystemFontDemo extends StatelessWidget {
  /// Creates the demo app.
  const SystemFontDemo({super.key});

  @override
  Widget build(BuildContext context) =>
      const MaterialApp(debugShowCheckedModeBanner: false, home: _Page());
}

class _Page extends StatefulWidget {
  const _Page();

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  var _step = 0;
  Timer? _timer;
  String _status = 'Reading the system font…';
  String _check = '';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 1800),
      (_) => setState(() => _step++),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _probe());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _probe() async {
    final clock = Stopwatch()..start();
    final bytes = systemFontBytes();
    final read = clock.elapsedMilliseconds;
    if (bytes == null) {
      setState(() => _status = 'No system font from CoreText');
      debugPrint('SFCHECK no-bytes');
      return;
    }
    final font = GlyphFont.parse(bytes);
    final status =
        'SF from CoreText: ${(bytes.length / 1024 / 1024).toStringAsFixed(1)}'
        ' MB in $read ms, axes ${font.axes.join(' ')}';
    debugPrint('SFCHECK $status');
    setState(() => _status = status);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final summary = await _calibrate(font);
    if (mounted) setState(() => _check = summary);
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xff111111);
    final big = _step.isOdd;
    final word = const [
      'Dance With God',
      'YOUR ORDER',
      'Lemon Drops',
    ][(_step ~/ 2) % 3];
    return Scaffold(
      backgroundColor: const Color(0xfff6f4ef),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            Text(
              _status,
              style: const TextStyle(fontSize: 11, color: Color(0xff6b6b6b)),
            ),
            if (_check.isNotEmpty)
              Text(
                _check,
                style: const TextStyle(fontSize: 11, color: Color(0xff0f766e)),
              ),
            const SizedBox(height: 24),
            _label('Track title to hero: weight, size and family'),
            SizedBox(
              height: 64,
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedMorphText(
                  word,
                  style: big
                      ? const TextStyle(
                          fontFamily: 'CupertinoSystemDisplay',
                          fontWeight: FontWeight.w800,
                          fontSize: 40,
                          color: ink,
                        )
                      : const TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 17,
                          color: ink,
                        ),
                ),
              ),
            ),
            _label('Ultralight to Black, default family'),
            AnimatedMorphText(
              'OOPARTS',
              style: TextStyle(
                fontWeight: big ? FontWeight.w900 : FontWeight.w100,
                fontSize: 48,
                color: ink,
              ),
            ),
            const SizedBox(height: 12),
            _label('Word to word'),
            AnimatedMorphText(
              big ? 'Pause' : 'Play',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 34,
                color: Color(0xffc2410c),
              ),
            ),
            const SizedBox(height: 20),
            _label('Frozen at 0, ¼, ½, ¾, 1: in-between shapes, no crossfade'),
            for (final t in const [0.0, .25, .5, .75, 1.0])
              MorphText(
                'Ag',
                from: const TextStyle(
                  fontWeight: FontWeight.w200,
                  fontSize: 44,
                  color: ink,
                ),
                to: const TextStyle(
                  fontFamily: 'CupertinoSystemDisplay',
                  fontWeight: FontWeight.w900,
                  fontSize: 44,
                  color: ink,
                ),
                progress: AlwaysStoppedAnimation(t),
              ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        letterSpacing: 1,
        color: Color(0xff8a8a8a),
      ),
    ),
  );
}

/// The probe word: round, straight and diagonal strokes, and counters.
const _word = 'Hamburgefonstiv&Rag8';

/// Pixels per logical pixel for the comparison rasters.
const _k = 3.0;

/// Compares, for each family, size and weight, the outline at a range of
/// optical sizes with what Text draws, and logs the best match beside the
/// one morphtext picks. Returns a one-line summary.
Future<String> _calibrate(GlyphFont font) async {
  const families = <String?>[
    null,
    'CupertinoSystemText',
    'CupertinoSystemDisplay',
  ];
  const sizes = [17.0, 34.0, 64.0];
  const weights = FontWeight.values;
  const opszs = <double?>[null, 12, 14, 17, 20, 24, 28, 29, 34, 56, 80];
  var worst = 1.0, total = 0.0, n = 0, misses = 0;
  for (final family in families) {
    for (final size in sizes) {
      for (final weight in weights) {
        final style = TextStyle(
          fontFamily: family,
          fontWeight: weight,
          fontSize: size,
          color: const Color(0xff000000),
        );
        final layout = WordLayout(
          _word,
          style,
          TextScaler.noScaling,
          TextDirection.ltr,
        );
        final w = (layout.size.width * _k).ceil() + 4;
        final h = (layout.size.height * _k).ceil() + 4;
        final text = await _raster(w, h, (canvas) {
          final painter = TextPainter(
            text: TextSpan(text: _word, style: style),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout();
          canvas.scale(_k);
          painter.paint(canvas, Offset.zero);
          painter.dispose();
        });
        final wght = systemWeight(style);
        final chosen = systemOpticalSize(style);
        final scores = <double?, double>{};
        for (final opsz in {...opszs, chosen}) {
          final varied = font.varied(weight: wght, opticalSize: opsz);
          final outline = await _raster(w, h, (canvas) {
            canvas
              ..scale(_k)
              ..drawPath(
                _path(varied, layout),
                Paint()..color = const Color(0xff000000),
              );
          });
          scores[opsz] = _iou(text, outline);
        }
        final best = scores.entries.reduce((a, b) => b.value > a.value ? b : a);
        // Then the weight that fits best at that optical size, then the
        // optical size again at that weight.
        Future<double> fit(double wg, double? op) async => _iou(
          text,
          await _raster(w, h, (canvas) {
            canvas
              ..scale(_k)
              ..drawPath(
                _path(font.varied(weight: wg, opticalSize: op), layout),
                Paint()..color = const Color(0xff000000),
              );
          }),
        );
        var fitW = wght, fitScore = best.value;
        for (var wg = wght - 300; wg <= wght + 300; wg += 25) {
          if (wg < 1) continue;
          final score = await fit(wg, best.key);
          if (score > fitScore) (fitW, fitScore) = (wg, score);
        }
        final coarse = fitW;
        for (var wg = coarse - 20; wg <= coarse + 20; wg += 4) {
          if (wg < 1) continue;
          final score = await fit(wg, best.key);
          if (score > fitScore) (fitW, fitScore) = (wg, score);
        }
        double? fitOp = best.key;
        for (final op in opszs) {
          final score = await fit(fitW, op);
          if (score > fitScore) (fitOp, fitScore) = (op, score);
        }
        debugPrint(
          'SFFIT family=${family ?? 'default'} size=$size '
          'weight=${weight.value} asked=$wght fitW=$fitW fitOpsz=$fitOp '
          'iou=${fitScore.toStringAsFixed(4)}',
        );
        final bestOutline = await _raster(w, h, (canvas) {
          canvas
            ..scale(_k)
            ..drawPath(
              _path(font.varied(weight: wght, opticalSize: best.key), layout),
              Paint()..color = const Color(0xff000000),
            );
        });
        final te = _edges(text, w), oe = _edges(bestOutline, w);
        debugPrint(
          'SFEDGE family=${family ?? 'default'} size=$size weight=${weight.value} '
          'text=$te outline=$oe '
          'dl=${oe.$1 - te.$1} dt=${oe.$2 - te.$2} dr=${oe.$3 - te.$3} db=${oe.$4 - te.$4} '
          'inkText=${_ink(text)} inkOutline=${_ink(bestOutline)}',
        );
        if (size == 64 && weight == FontWeight.w400) {
          await _overlay(
            '${family ?? 'default'}-56-400.png',
            w,
            h,
            style,
            _path(font.varied(weight: wght, opticalSize: best.key), layout),
          );
        }
        final mine = scores[chosen]!;
        worst = mine < worst ? mine : worst;
        total += mine;
        n++;
        if (best.value - mine > .005) misses++;
        debugPrint(
          'SFCHECK family=${family ?? 'default'} size=$size '
          'weight=${weight.value} wght=$wght '
          'chosen=$chosen iou=${mine.toStringAsFixed(4)} '
          'best=${best.key} iou=${best.value.toStringAsFixed(4)} '
          'all=${scores.entries.map((e) => '${e.key}:${e.value.toStringAsFixed(3)}').join(',')}',
        );
      }
    }
  }
  try {
    final docs = Directory('${Directory.systemTemp.parent.path}/Documents')
      ..createSync(recursive: true);
    File('${docs.path}/sf.ttf').writeAsBytesSync(systemFontBytes()!);
    debugPrint('SFCHECK wrote ${docs.path}');
  } on Object catch (e) {
    debugPrint('SFCHECK could not write: $e');
  }
  final summary =
      'Outline vs Text over $n cases: mean IoU ${(total / n).toStringAsFixed(4)}, '
      'worst ${worst.toStringAsFixed(4)}, $misses beaten by another opsz';
  debugPrint('SFCHECK $summary');
  return summary;
}

/// [layout]'s letters in [font], where Flutter put them.
Path _path(GlyphFont font, WordLayout layout) {
  final runes = layout.text.runes.toList();
  final shape = GlyphShape.placed([
    for (var k = 0; k < runes.length; k++)
      if ((layout.pens[k], font.outline(runes[k])) case (
        final pen?,
        final outline?,
      ))
        (
          outline: outline,
          x: pen.dx / layout.em,
          y: (pen.dy - outline.ascender * layout.em) / layout.em,
          scale: 1.0,
        ),
  ])!;
  final path = Path()..fillType = PathFillType.nonZero;
  for (final p in GlyphMorph(shape, shape).at(0)) {
    path.moveTo(p[0] * layout.em, p[1] * layout.em);
    for (var i = 2; i < p.length; i += 2) {
      path.lineTo(p[i] * layout.em, p[i + 1] * layout.em);
    }
    path.close();
  }
  return path;
}

Future<Uint8List> _raster(int w, int h, void Function(Canvas) paint) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData();
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Intersection over union of the inked pixels (alpha at least half).
double _iou(Uint8List a, Uint8List b) {
  var both = 0, either = 0;
  for (var i = 3; i < a.length; i += 4) {
    final x = a[i] >= 128, y = b[i] >= 128;
    if (x && y) both++;
    if (x || y) either++;
  }
  return either == 0 ? 1 : both / either;
}

/// The inked bounds of [px], [w] pixels wide: left, top, right, bottom.
(int, int, int, int) _edges(Uint8List px, int w) {
  var l = 1 << 30, t = 1 << 30, r = -1, b = -1;
  for (var i = 3, p = 0; i < px.length; i += 4, p++) {
    if (px[i] < 128) continue;
    final x = p % w, y = p ~/ w;
    if (x < l) l = x;
    if (x > r) r = x;
    if (y < t) t = y;
    if (y > b) b = y;
  }
  return (l, t, r, b);
}

/// How many pixels are inked.
int _ink(Uint8List px) {
  var n = 0;
  for (var i = 3; i < px.length; i += 4) {
    if (px[i] >= 128) n++;
  }
  return n;
}

/// Text in red and the outline in cyan, multiplied on white: black where
/// they agree. Written to the app's Documents as [name].
Future<void> _overlay(
  String name,
  int w,
  int h,
  TextStyle style,
  Path outline,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = const Color(0xffffffff),
    )
    ..scale(_k);
  final painter = TextPainter(
    text: TextSpan(
      text: _word,
      style: style.copyWith(color: const Color(0xffff0000)),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  painter.paint(canvas, Offset.zero);
  painter.dispose();
  canvas.drawPath(
    outline,
    Paint()
      ..color = const Color(0xff00ffff)
      ..blendMode = BlendMode.multiply,
  );
  final image = await recorder.endRecording().toImage(w, h);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final dir = Directory('${Directory.systemTemp.parent.path}/Documents')
    ..createSync(recursive: true);
  File('${dir.path}/$name').writeAsBytesSync(png!.buffer.asUint8List());
}
