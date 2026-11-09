// SF Pro as an old sale flyer, rendered on the device itself: rows of
// iPhone iPhone iPhone, a wave of morphs down the page through other
// words to SF Pro, strips of icons morphing with them, and a starburst.
// Every letter is the system font, read from iOS; nothing is bundled.
// Writes 1080x1920 frames at 60 fps to the app's Documents/flyer:
//
//   flutter run -t lib/system_font_flyer.dart     # on an iPhone

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:morphtext/morphtext.dart';

import 'device_reel.dart';

void main() =>
    runApp(const DeviceReel(scene: _scene, seconds: 9.6, name: 'flyer'));

const _paper = Color(0xffffe14a);
const _ink = Color(0xff121212);
const _red = Color(0xffe2231a);

/// Each beat of the flyer: the word, its weight and family on the heavy
/// rows, the icons the strips show, and the starburst.
typedef _Beat = ({
  String word,
  FontWeight weight,
  bool display,
  List<IconData> icons,
  MorphContent badge,
});

const _badgeText = TextStyle(
  fontFamily: 'CupertinoSystemDisplay',
  fontWeight: FontWeight.w900,
  fontSize: 30,
  color: _paper,
  height: 1,
);

const _beats = <_Beat>[
  (
    word: 'iPhone',
    weight: FontWeight.w900,
    display: false,
    icons: [
      Icons.phone_iphone_rounded,
      Icons.tablet_mac_rounded,
      Icons.laptop_mac_rounded,
      Icons.watch_rounded,
      Icons.headphones_rounded,
    ],
    badge: MorphContent.text('NEW!', style: _badgeText),
  ),
  (
    word: 'Pro Max',
    weight: FontWeight.w900,
    display: true,
    icons: [
      Icons.phone_iphone_rounded,
      Icons.battery_charging_full_rounded,
      Icons.bolt_rounded,
      Icons.memory_rounded,
      Icons.speed_rounded,
    ],
    badge: MorphContent.icon(
      Icons.phone_iphone_rounded,
      size: 60,
      color: _paper,
    ),
  ),
  (
    word: 'Retina',
    weight: FontWeight.w200,
    display: false,
    icons: [
      Icons.wb_sunny_rounded,
      Icons.visibility_rounded,
      Icons.brightness_high_rounded,
      Icons.contrast_rounded,
      Icons.auto_awesome_rounded,
    ],
    badge: MorphContent.text('PRO', style: _badgeText),
  ),
  (
    word: 'Camera',
    weight: FontWeight.w800,
    display: true,
    icons: [
      Icons.photo_camera_rounded,
      Icons.videocam_rounded,
      Icons.camera_rounded,
      Icons.image_rounded,
      Icons.center_focus_strong_rounded,
    ],
    badge: MorphContent.icon(
      Icons.photo_camera_rounded,
      size: 58,
      color: _paper,
    ),
  ),
  (
    word: 'Face ID',
    weight: FontWeight.w600,
    display: false,
    icons: [
      Icons.face_rounded,
      Icons.lock_open_rounded,
      Icons.fingerprint_rounded,
      Icons.verified_user_rounded,
      Icons.lock_rounded,
    ],
    badge: MorphContent.text('WOW!', style: _badgeText),
  ),
  (
    word: 'SF Pro',
    weight: FontWeight.w900,
    display: true,
    icons: [
      Icons.text_fields_rounded,
      Icons.format_bold_rounded,
      Icons.format_size_rounded,
      Icons.font_download_rounded,
      Icons.title_rounded,
    ],
    badge: MorphContent.text('SF Pro', style: _badgeText),
  ),
];

/// When each beat after the first begins, at the top of the page; the
/// wave reaches each row a little later.
const _beatTimes = [1.1, 2.6, 4.1, 5.6, 7.1];

/// How long the wave takes per row, and per icon along a strip.
const _rowDelay = .055, _iconDelay = .03;

/// Rows of the page, top to bottom: null for an icon strip.
const _rows = 12;
const _iconRows = {3, 8};
const _rowHeight = 48.0;

List<double> _times(double delay) => [for (final t in _beatTimes) t + delay];

/// The weight a light row takes when the heavy rows have [weight], and the
/// other way round: alternate rows swing the other way.
FontWeight _swing(FontWeight weight) =>
    weight.value >= 600 ? FontWeight.w200 : FontWeight.w900;

Widget _textRow(double s, int r, int textIndex) {
  final heavy = textIndex.isEven;
  final color = textIndex % 3 == 1 ? _red : _ink;
  final states = [
    for (final beat in _beats)
      text(
        List.filled(5, beat.word).join(' '),
        TextStyle(
          fontFamily: beat.display ? 'CupertinoSystemDisplay' : null,
          fontWeight: heavy ? beat.weight : _swing(beat.weight),
          fontSize: 44,
          color: color,
          height: 1,
          letterSpacing: -.5,
        ),
      ),
  ];
  // Bricked, and drifting a little, alternately left and right.
  final drift = (r.isEven ? -1 : 1) * s * 9;
  final x = (r.isEven ? -14.0 : -78.0) + drift;
  return _bleed(x, steps(s, states, _times(r * _rowDelay)));
}

Widget _iconRow(double s, int r) {
  const count = 10, gap = 46.0;
  final drift = (r.isEven ? -1 : 1) * s * 9;
  final x = (r.isEven ? -10.0 : -33.0) + drift;
  return _bleed(
    x,
    Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var k = 0; k < count; k++)
          SizedBox(
            width: gap,
            child: Center(
              child: steps(s, [
                for (final beat in _beats)
                  MorphContent.icon(
                    beat.icons[k % beat.icons.length],
                    size: 32,
                    color: k.isEven ? _ink : _red,
                  ),
              ], _times(r * _rowDelay + k * _iconDelay)),
            ),
          ),
      ],
    ),
  );
}

/// [child] laid out as wide as it likes, [x] from the left, cut at the
/// page's edges.
Widget _bleed(double x, Widget child) => SizedBox(
  height: _rowHeight,
  child: ClipRect(
    child: OverflowBox(
      alignment: Alignment.centerLeft,
      minWidth: 0,
      maxWidth: double.infinity,
      child: Transform.translate(offset: Offset(x, 0), child: child),
    ),
  ),
);

Widget _starburst(double s) {
  final breathe = 1 + .035 * math.sin(2 * math.pi * s / 1.3);
  return Transform.rotate(
    angle: -.22 + .04 * math.sin(2 * math.pi * s / 2.9),
    child: Transform.scale(
      scale: breathe,
      child: SizedBox(
        width: 150,
        height: 150,
        child: CustomPaint(
          painter: const _Star(),
          child: Center(
            child: steps(s, [
              for (final beat in _beats) beat.badge,
            ], _times(.25)),
          ),
        ),
      ),
    ),
  );
}

/// A print-style starburst: red, with an offset black shadow.
class _Star extends CustomPainter {
  const _Star();

  @override
  void paint(Canvas canvas, Size size) {
    const points = 20;
    final c = size.center(Offset.zero);
    final outer = size.shortestSide / 2, inner = outer * .78;
    final path = Path();
    for (var k = 0; k < points * 2; k++) {
      final r = k.isEven ? outer : inner;
      final a = math.pi * k / points;
      final p = c + Offset(math.cos(a), math.sin(a)) * r;
      k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas
      ..drawPath(path.shift(const Offset(5, 5)), Paint()..color = _ink)
      ..drawPath(path, Paint()..color = _red);
  }

  @override
  bool shouldRepaint(_Star old) => false;
}

Widget _scene(double s) {
  var textIndex = 0;
  return ColoredBox(
    color: _paper,
    child: Stack(
      children: [
        Column(
          children: [
            for (var r = 0; r < _rows; r++)
              _iconRows.contains(r)
                  ? _iconRow(s, r)
                  : _textRow(s, r, textIndex++),
            const Spacer(),
            Container(
              height: 640 - _rows * _rowHeight,
              width: double.infinity,
              color: _ink,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: const Row(
                children: [
                  Text(
                    'morphtext',
                    style: TextStyle(
                      fontFamily: 'CupertinoSystemDisplay',
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      color: _paper,
                    ),
                  ),
                  Spacer(),
                  Text(
                    'SF PRO FROM iOS\nNO FONT BUNDLED',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      height: 1.25,
                      letterSpacing: 1,
                      color: _paper,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Positioned(right: 18, top: 196, child: _starburst(s)),
      ],
    ),
  );
}
