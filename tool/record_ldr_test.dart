// A second reel: a nod to a certain anthology's title card, which people
// thought of when morphnext launched. Its three glyphs, a heart, an X and a
// robot, become LOVE, MORPH and ROBOT: the X is a morph now (a delta, the
// sign for change). Each word flows into its icon, glitches through
// variants, settles, and flows back into the word.
//
//   flutter test tool/record_ldr_test.dart               # build/ldr_frames
//   REEL_SHEET=1 flutter test tool/record_ldr_test.dart  # a contact sheet
//
// Generic Material icons and the package's own fonts: a nod, not the logo.

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphtext/morphtext.dart';

import '../test/support.dart';
import 'reel.dart';

const black = Color(0xff0d0d0d);
const white = Color(0xfff1f3f4);
const red = Color(0xffd93025);
const quiet = Color(0xff5f6368);

const credit = 'drei.gg   ·   morphtext   ·   built on morphnext by KickNext';

const end = 10.5;

/// Quicker than snappy, for the glitch: in and out in a few frames.
const glitch = SpringDescription(mass: 1, stiffness: 900, damping: 45);

const glyphSize = 170.0;

TextStyle caps(double size, Color color) =>
    sans.copyWith(fontSize: size, color: color);

MorphContent word(String text, Color color) =>
    MorphContent.text(text, style: caps(72, color));

MorphContent letter(String text, Color color) =>
    MorphContent.text(text, style: caps(glyphSize, color));

MorphContent icon(IconData data, Color color) =>
    MorphContent.icon(data, size: glyphSize, color: color);

/// One slot: its word, its icon, the variants it glitches through, and the
/// word it ends on.
typedef Slot = ({
  String word,
  MorphContent icon,
  List<MorphContent> variants,
  String last,
  Color color,
});

final slots = <Slot>[
  (
    word: 'LOVE',
    icon: icon(Icons.favorite, red),
    variants: [
      icon(Icons.favorite_border, red),
      letter('L', red),
      icon(Icons.heart_broken, red),
      icon(Icons.volunteer_activism, red),
      letter('O', red),
    ],
    last: 'LOVE',
    color: red,
  ),
  (
    word: 'MORPH',
    icon: icon(Icons.change_history, white),
    variants: [
      letter('X', white),
      icon(Icons.all_inclusive, white),
      letter('M', white),
      icon(Icons.autorenew, white),
      icon(Icons.shuffle, white),
    ],
    last: 'MORPH',
    color: white,
  ),
  (
    word: 'ROBOT',
    icon: icon(Icons.smart_toy, white),
    variants: [
      icon(Icons.android, white),
      letter('R', white),
      icon(Icons.precision_manufacturing, white),
      icon(Icons.memory, white),
      letter('B', white),
    ],
    last: 'ROBOT',
    color: white,
  ),
];

Widget slot(double s, int k) {
  final slot = slots[k];
  final lag = .14 * k;
  // Word, icon, the glitch, the icon again, and the last word.
  final glitchAt = [
    for (var n = 0; n < slot.variants.length; n++) 3.0 + lag + n * .62,
  ];
  final states = [
    word(slot.word, slot.color),
    slot.icon,
    ...slot.variants,
    slot.icon,
    word(slot.last, slot.color),
  ];
  final at = [1.0 + lag, ...glitchAt, 6.6 + lag, 8.4 + lag];
  // The glitch steps spring quicker than the rest.
  var n = 0;
  while (n < at.length && s >= at[n]) {
    n++;
  }
  final glitching = n >= 2 && n <= 1 + slot.variants.length + 1;
  return steps(s, states, at, spring: glitching ? glitch : MorphSprings.snappy);
}

Widget scene(double s) => ColoredBox(
  color: black,
  child: Stack(
    children: [
      Positioned.fill(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var k = 0; k < slots.length; k++)
              SizedBox(
                width: 380,
                height: 260,
                child: Center(child: slot(s, k)),
              ),
          ],
        ),
      ),
      Positioned(
        left: 40,
        bottom: 26,
        child: Text(
          credit,
          style: light.copyWith(fontSize: 13, color: quiet, letterSpacing: 1.5),
        ),
      ),
    ],
  ),
);

void main() {
  setUpAll(loadReelFonts);

  testWidgets('record the nod', (tester) async {
    await record(
      tester,
      scene: scene,
      seconds: end,
      dir: 'build/ldr_frames',
      sheet: const [
        .5, 1.15, 1.4, 2.5, //
        3.1, 3.5, 4.0, 4.6,
        5.3, 6.0, 6.75, 7.6,
        8.5, 8.7, 9.2, 10.3,
      ],
    );
  }, timeout: const Timeout(Duration(minutes: 15)));
}
