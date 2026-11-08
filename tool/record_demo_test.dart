// Renders the README hero frame by frame, as a widget test (no device, no
// screen recorder): `tool/record_demo.sh demo` runs it and encodes it.
//
//   flutter test tool/record_demo_test.dart               # doc/frames/*.png
//   REEL_SHEET=1 flutter test tool/record_demo_test.dart  # a contact sheet
//
// It follows the grammar of morphnext's own hero (1280x720, 60 fps, its
// snappy spring, swipes between light acts, a dark circle bursting into a
// frantic grid, the grid collapsing to one survivor, a light circle out, a
// wordmark outro that loops back to the first frame), so the two read as a
// pair, with words where morphnext has icons, and an act morphnext can't do:
// words flowing into icons.

import 'dart:math' show Random, sqrt;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Icon, Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphtext/morphtext.dart';

import '../test/support.dart';
import 'reel.dart';

// morphnext's hero palette.
const paper = Color(0xfff8faf9);
const night = Color(0xff17191a);
const ink = Color(0xff1f2123);
const blue = Color(0xff1a73e8);
const green = Color(0xff1e8e3e);
const red = Color(0xffd93025);
const white = Color(0xffffffff);
const quiet = Color(0xff9aa0a6);
const line = Color(0xffdadce0);
const pastels = [
  Color(0xff8ab4f8),
  Color(0xfff28b82),
  Color(0xfffdd663),
  Color(0xff81c995),
  Color(0xffc58af9),
];

/// The footer: ours, and the engine's.
const credit = 'drei.gg   ·   morphtext   ·   built on morphnext by KickNext';

// The timeline, in seconds: the opening, two type beats, the weight claim,
// words into icons, then the dark grid, the collapse and the outro.
const swipe1 = 3.5, beatAny = 3.95;
const swipe2 = 6.5, beatStyle = 6.95;
const swipe3 = 9.1, act4 = 9.55;
const swipe4 = 12.5, act3 = 12.95;
const circleIn = 16.1, act5 = 16.32;
const collapse = 19.15, circleOut = 19.9, outro = 20.1;
const loop = 22.3, end = 22.95;

/// How long a swipe takes.
const swipeTime = .45;

/// How long a circle takes to fill the frame.
const circleTime = .22;

/// Where the dark circle bursts from: the blue icon that ends the icons
/// act.
const burstCentre = Offset(870, 360);

/// Where the survivor of the grid ends up, and the outro's icon sits.
const markCentre = Offset(640, 250);

TextStyle face(double size, {FontWeight weight = FontWeight.w300, Color? c}) =>
    light.copyWith(fontSize: size, fontWeight: weight, color: c ?? ink);

/// Red Hat Display Black: another font entirely.
TextStyle sansFace(double size, {Color? c}) =>
    sans.copyWith(fontSize: size, color: c ?? ink);

MorphContent word(String text, TextStyle style) =>
    MorphContent.text(text, style: style);

MorphContent icon(IconData data, double size, Color color) =>
    MorphContent.icon(data, size: size, color: color);

/// The index of the step [s] is in, given steps starting at [at].
int stepAt(double s, List<double> at) {
  var k = 0;
  while (k < at.length && s >= at[k]) {
    k++;
  }
  return k;
}

/// How far, 0..1, [s] is through the span from [from] lasting [length].
double through(double s, double from, double length) =>
    ((s - from) / length).clamp(0.0, 1.0);

/// Act 1: MORPH, ANY, TEXT OR ICON, then each word into an icon, one by
/// one: a text icon, a slash, an icon icon.
Widget opening(double s) {
  final caps = sansFace(104);
  MorphContent big(IconData data) => icon(data, 150, ink);
  const any = .6, phrase = 1.3, icons = [2.1, 2.5, 2.9];
  return Center(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        steps(
          s,
          [word('', caps), word('TEXT', caps), big(Icons.text_fields)],
          [phrase, icons[0]],
        ),
        const SizedBox(width: 36),
        steps(
          s,
          [
            word('MORPH', caps),
            word('ANY', caps),
            word('OR', caps),
            word('/', caps),
          ],
          [any, phrase, icons[1]],
        ),
        const SizedBox(width: 36),
        steps(
          s,
          [word('', caps), word('ICON', caps), big(Icons.interests)],
          [phrase, icons[2]],
        ),
      ],
    ),
  );
}

/// Beat 2: a giant letter becoming the next, beside ANY again: letter,
/// weight, font style, text, each in the style it names.
Widget anyBeat(double s) {
  const letters = ['a', 'g', 'R', '&', 'Q'];
  TextStyle style(int k, double size) => k == 4
      ? sansFace(size)
      : face(size, weight: k.isOdd ? FontWeight.w600 : FontWeight.w300);
  final at = [for (var k = 0; k < 4; k++) beatAny + .2 + k * .6];
  return Stack(
    children: [
      Positioned(
        left: 90,
        width: 380,
        top: 0,
        bottom: 0,
        child: Center(
          child: steps(s, [
            for (var k = 0; k < 5; k++) word(letters[k], style(k, 300)),
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
            word('Any letter.', face(84)),
            word('Any weight.', face(84, weight: FontWeight.w600)),
            word('Any font style.', sansFace(76)),
            word('Any text.', face(84)),
          ], at.take(3).toList()),
        ),
      ),
    ],
  );
}

/// Beat 3: one word in the style it names: Light, Bold, Sans, Script.
Widget styleBeat(double s) => Center(
  child: steps(
    s,
    [
      word('Light', face(170)),
      word('Bold', face(170, weight: FontWeight.w600)),
      word('Sans', sansFace(160)),
      word('Script', script(190)),
    ],
    [for (var k = 0; k < 3; k++) beatStyle + .25 + k * .6],
  ),
);

/// Dancing Script, a script face.
TextStyle script(double size, {Color? c}) =>
    TextStyle(fontFamily: scriptFamily, fontSize: size, color: c ?? ink);

/// Red Hat Display at [weight]: Light (300) to Black (900) is the ramp.
TextStyle ramp(double size, FontWeight weight, {Color? c}) =>
    sans.copyWith(fontSize: size, fontWeight: weight, color: c ?? ink);

/// A status button: its label morphing through [states] at [at], its
/// colour easing through [colors] (one per state).
Widget button(
  double s,
  List<MorphContent> states,
  List<Color> colors,
  List<double> at,
) {
  final k = stepAt(s, at);
  final from = colors[k == 0 ? 0 : k - 1], to = colors[k];
  final t = k == 0 ? 1.0 : springAt(s - at[k - 1]).clamp(0.0, 1.0);
  return Container(
    width: 220,
    height: 68,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Color.lerp(from, to, t),
      borderRadius: BorderRadius.circular(34),
    ),
    child: steps(s, states, at),
  );
}

/// Act 3: words into icons: two buttons going through a request, one that
/// succeeds and one that fails, beside a word flowing into its icon.
Widget icons(double s) {
  final label = sansFace(26, c: white);
  final big = face(120, weight: FontWeight.w600);
  return Stack(
    children: [
      Positioned(
        left: 70,
        top: 140,
        child: Text(
          'Words\ninto icons.',
          style: face(68, weight: FontWeight.w600).copyWith(height: 1.0),
        ),
      ),
      Positioned(
        left: 74,
        top: 400,
        child: Row(
          children: [
            button(
              s,
              [
                word('Send', label),
                word('Sending', label),
                icon(Icons.check_rounded, 40, white),
              ],
              const [blue, blue, green],
              const [act3 + .4, act3 + 1.2],
            ),
            const SizedBox(width: 20),
            button(
              s,
              [
                word('Upload', label),
                word('Uploading', label),
                icon(Icons.close_rounded, 40, white),
              ],
              const [blue, blue, red],
              const [act3 + .6, act3 + 1.5],
            ),
          ],
        ),
      ),
      Positioned(
        left: 700,
        right: 40,
        top: 0,
        bottom: 0,
        child: Center(
          child: steps(
            s,
            [
              word('Done', big),
              icon(Icons.check_rounded, 210, ink),
              word('Love', big),
              icon(Icons.favorite, 210, red),
              word('Play', big),
              icon(Icons.play_arrow_rounded, 210, blue),
            ],
            [for (var k = 0; k < 5; k++) act3 + .3 + k * .6],
          ),
        ),
      ),
    ],
  );
}

/// Act 4: the claim, the counters, and a blue word, light and bold by turns.
Widget claim(double s) {
  const at = [act4 + .3, act4 + 1.0, act4 + 1.7, act4 + 2.4];
  final k = stepAt(s, at);
  final along = k == 0 ? 0.0 : springAt(s - at[k - 1]).clamp(0.0, 1.0);
  final bold = k.isOdd ? along : 1 - along;
  final weight = (300 + 600 * (k == 0 ? 0 : bold)).round();
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
                Text('300 · 900', style: face(34)),
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
        child: Center(
          child: steps(s, [
            for (var n = 0; n < 5; n++)
              word(
                'Quartz',
                ramp(150, n.isOdd ? FontWeight.w900 : FontWeight.w300, c: blue),
              ),
          ], at),
        ),
      ),
    ],
  );
}

/// The grid's cells: where each sits, in the frame.
Offset cellCentre(int r, int c) =>
    Offset(100 + (c + .5) * 1080 / 4, 146 + r * (500 - 72) / 3);

/// The cell that survives the collapse and becomes the outro's icon.
const survivorRow = 1, survivorColumn = 2;

/// The icon the survivor settles on.
const survivorIcon = Icons.interests;

/// Act 5: a grid where every cell keeps becoming another stone or an icon,
/// each on its own irregular clock. It pops in outward from where the dark
/// circle burst, and collapses, cell by cell, to one survivor.
Widget grid(double s) {
  const names = [
    'Amethyst', 'Citrine', 'Jade', 'Onyx', //
    'Opal', 'Garnet', 'Topaz', 'Jasper',
    'Pyrite', 'Quartz', 'Agate', 'Beryl',
    'Coral', 'Peridot', 'Ruby', 'Lapis',
  ];
  const glyphs = [
    Icons.favorite,
    Icons.star_rounded,
    Icons.check_rounded,
    Icons.close_rounded,
    Icons.search_rounded,
    Icons.menu_rounded,
    Icons.home_rounded,
    Icons.play_arrow_rounded,
    Icons.bolt,
    Icons.diamond,
    Icons.music_note,
    Icons.cloud,
    Icons.pets,
    Icons.rocket_launch,
  ];
  // Nearest the burst first.
  final order =
      [
        for (var r = 0; r < 4; r++)
          for (var c = 0; c < 4; c++) (r, c),
      ]..sort(
        (x, y) => (cellCentre(x.$1, x.$2) - burstCentre).distance.compareTo(
          (cellCentre(y.$1, y.$2) - burstCentre).distance,
        ),
      );
  Widget cell(int r, int c) {
    final n = r * 4 + c;
    final survivor = r == survivorRow && c == survivorColumn;
    // Seeded per cell, so every render is the same.
    final random = Random(n * 7919 + 17);
    final color = pastels[n % pastels.length];
    final faces = [
      face(46, c: color),
      face(46, weight: FontWeight.w600, c: color),
      sansFace(42, c: color),
    ];
    MorphContent next() => random.nextDouble() < .45
        ? icon(glyphs[random.nextInt(glyphs.length)], 64, color)
        : word(names[random.nextInt(names.length)], faces[random.nextInt(3)]);
    final states = [word(names[n], faces[n % 3])];
    final at = <double>[];
    for (
      var time = act5 + .4 + random.nextDouble() * .5;
      time < collapse - .3;
      time += .22 + random.nextDouble() * .53
    ) {
      at.add(time);
      states.add(next());
    }
    if (survivor) {
      at.add(collapse - .25);
      states.add(icon(survivorIcon, 64, color));
    }
    // In: pops up in order from the burst. Out: shrinks away at its own
    // moment, but the survivor, which the overlay takes over.
    final rank = order.indexOf((r, c));
    final popIn = Curves.easeOutBack.transform(
      through(s, act5 + rank * .025, .25),
    );
    final out = survivor
        ? (s >= collapse ? 1.0 : 0.0)
        : Curves.easeInCubic.transform(
            through(s, collapse + random.nextDouble() * .5, .18),
          );
    final centre = cellCentre(r, c);
    return Positioned(
      left: centre.dx - 135,
      top: centre.dy - 36,
      width: 270,
      height: 72,
      child: Transform.scale(
        scale: popIn * (1 - out),
        child: Center(child: steps(s, states, at)),
      ),
    );
  }

  return Stack(
    children: [
      for (var r = 0; r < 4; r++)
        for (var c = 0; c < 4; c++) cell(r, c),
    ],
  );
}

/// The survivor of the grid, from the collapse to the outro: it travels to
/// [markCentre] and grows, turning blue as the light comes back.
Widget survivor(double s) {
  final move = Curves.easeInOutCubic.transform(through(s, collapse, .6));
  final at = Offset.lerp(
    cellCentre(survivorRow, survivorColumn),
    markCentre,
    move,
  )!;
  final size = 64 + (120 - 64) * move;
  final color = Color.lerp(
    pastels[(survivorRow * 4 + survivorColumn) % pastels.length],
    blue,
    through(s, circleOut, circleTime),
  );
  return Positioned(
    left: at.dx - size / 2,
    top: at.dy - size / 2,
    child: Icon(survivorIcon, size: size, color: color),
  );
}

/// The outro: a cycling icon over the wordmark, which builds in in rainbow
/// colours and settles to ink, with a tagline, the install line and the
/// pub.dev address; then all but the wordmark fades, and the wordmark
/// becomes the first frame's MORPH, so the reel loops.
Widget outroScene(double s) {
  final settle = through(s, outro + .85, .6);
  final details =
      through(s, outro + .95, .35) * (1 - through(s, loop - .1, .3));
  final drop = Curves.easeInOutCubic.transform(through(s, loop, .4));
  final wordmark = steps(
    s,
    [
      word('', sansFace(84)),
      word('m', sansFace(84)),
      word('morph', sansFace(84)),
      word('morphtext', sansFace(84)),
      word('MORPH', sansFace(104)),
    ],
    const [outro + .15, outro + .3, outro + .5, loop],
  );
  final colors = [
    for (final pastel in pastels) Color.lerp(pastel, ink, settle)!,
  ];
  return Stack(
    children: [
      Positioned(
        left: 0,
        right: 0,
        top: markCentre.dy - 80,
        height: 160,
        child: Opacity(
          opacity: 1 - through(s, loop - .1, .3),
          child: Center(
            child: steps(
              s,
              [
                icon(survivorIcon, 120, blue),
                icon(Icons.text_fields, 120, blue),
                icon(Icons.favorite, 120, blue),
                icon(Icons.bolt, 120, blue),
                icon(Icons.star_rounded, 120, blue),
                icon(Icons.interests, 120, blue),
              ],
              [for (var k = 0; k < 5; k++) outro + .35 + k * .45],
            ),
          ),
        ),
      ),
      // The wordmark, dropping to the middle as it becomes MORPH.
      Positioned(
        left: 0,
        right: 0,
        top: 330 * (1 - drop) + 300 * drop,
        height: 120,
        child: Center(
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (rect) =>
                LinearGradient(colors: colors).createShader(rect),
            child: wordmark,
          ),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        top: 452,
        child: Opacity(
          opacity: details,
          child: Column(
            children: [
              Text(
                'TEXT INTO TEXT.  TEXT INTO ICONS.',
                style: sansFace(13, c: quiet).copyWith(letterSpacing: 3.5),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: line, width: 1.5),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text('flutter pub add morphtext', style: sansFace(17)),
              ),
              const SizedBox(height: 14),
              Text('pub.dev/packages/morphtext', style: face(16, c: quiet)),
            ],
          ),
        ),
      ),
    ],
  );
}

/// [outgoing] swiping away to the right as [incoming] swipes in from the
/// left, both fading, over [swipeTime] from [at].
Widget swipe(double s, double at, Widget outgoing, Widget incoming) {
  final p = through(s, at, swipeTime);
  // The outgoing scene leaves in the first 60%, the incoming one arrives in
  // the last 60%: they only overlap in the middle, faintly.
  final leave = Curves.easeInCubic.transform((p / .6).clamp(0.0, 1.0));
  final arrive = Curves.easeOutCubic.transform(((p - .4) / .6).clamp(0.0, 1.0));
  return Stack(
    children: [
      Positioned.fill(
        child: Opacity(
          opacity: 1 - leave,
          child: Transform.translate(
            offset: Offset(220 * leave, 0),
            child: outgoing,
          ),
        ),
      ),
      Positioned.fill(
        child: Opacity(
          opacity: arrive,
          child: Transform.translate(
            offset: Offset(-140 * (1 - arrive), 0),
            child: incoming,
          ),
        ),
      ),
    ],
  );
}

/// [inner] over [outer], showing through a circle that grows from [centre]
/// to fill the frame over [circleTime] from [at], its edge a thin [rim].
Widget circle(
  double s,
  double at,
  Offset centre,
  Widget outer,
  Widget inner, {
  required Color fill,
  Color? rim,
}) {
  final grow = Curves.easeInCubic.transform(through(s, at, circleTime));
  final farthest = sqrt(1280.0 * 1280.0 + 720.0 * 720.0);
  final radius = farthest * grow;
  return Stack(
    children: [
      Positioned.fill(child: outer),
      Positioned.fill(
        child: ClipPath(
          clipper: _Circle(centre, radius),
          child: ColoredBox(color: fill, child: inner),
        ),
      ),
      if (rim != null && grow > 0 && grow < 1)
        Positioned.fill(
          child: CustomPaint(painter: _Ring(centre, radius, rim)),
        ),
    ],
  );
}

class _Circle extends CustomClipper<Path> {
  _Circle(this.centre, this.radius);

  final Offset centre;
  final double radius;

  @override
  Path getClip(Size size) =>
      Path()..addOval(Rect.fromCircle(center: centre, radius: radius));

  @override
  bool shouldReclip(_Circle old) =>
      old.centre != centre || old.radius != radius;
}

class _Ring extends CustomPainter {
  _Ring(this.centre, this.radius, this.color);

  final Offset centre;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawCircle(
    centre,
    radius,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color,
  );

  @override
  bool shouldRepaint(_Ring old) => old.radius != radius;
}

/// The light acts, swiping from one to the next.
Widget lightActs(double s) {
  if (s < swipe1) return opening(s);
  if (s < beatAny) return swipe(s, swipe1, opening(s), anyBeat(s));
  if (s < swipe2) return anyBeat(s);
  if (s < beatStyle) return swipe(s, swipe2, anyBeat(s), styleBeat(s));
  if (s < swipe3) return styleBeat(s);
  if (s < act4) return swipe(s, swipe3, styleBeat(s), claim(s));
  if (s < swipe4) return claim(s);
  if (s < act3) return swipe(s, swipe4, claim(s), icons(s));
  return icons(s);
}

Widget scene(double s) {
  final Widget body;
  if (s < circleIn) {
    body = ColoredBox(color: paper, child: lightActs(s));
  } else if (s < circleOut) {
    body = circle(
      s,
      circleIn,
      burstCentre,
      ColoredBox(color: paper, child: lightActs(s)),
      grid(s),
      fill: night,
      rim: blue,
    );
  } else {
    body = circle(
      s,
      circleOut,
      markCentre,
      ColoredBox(color: night, child: grid(s)),
      outroScene(s),
      fill: paper,
    );
  }
  final dark = s >= circleIn + circleTime && s < circleOut + circleTime;
  return Stack(
    children: [
      Positioned.fill(child: body),
      if (s >= collapse && s < outro) survivor(s),
      Positioned(
        left: 40,
        bottom: 26,
        child: Text(
          credit,
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
        width: frameSize.width * s / end,
        child: ColoredBox(
          color: dark
              ? const Color(0xffe8eaed)
              : s >= act4
              ? blue
              : ink,
        ),
      ),
    ],
  );
}

void main() {
  setUpAll(loadReelFonts);

  testWidgets('record the hero', (tester) async {
    await record(
      tester,
      scene: scene,
      seconds: end,
      dir: 'doc/frames',
      sheet: const [
        .3, 2.0, 3.7, 4.0, //
        4.6, 5.2, 5.8, 6.4,
        7.0, 7.6, 8.2, 8.9,
        9.8, 11.0, 13.5, 15.9,
        16.2, 17.5, 19.6, 21.4,
      ],
    );
  }, timeout: const Timeout(Duration(minutes: 15)));
}
