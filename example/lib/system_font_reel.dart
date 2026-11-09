// A reel of SF Pro morphing, rendered on the device itself: every frame is
// drawn by the phone, the outlines read from iOS through CoreText, nothing
// bundled. Writes 1080x1920 frames at 60 fps to the app's Documents/reel:
//
//   flutter run -t lib/system_font_reel.dart     # on an iPhone

import 'package:flutter/material.dart';
import 'package:morphtext/morphtext.dart';

import 'device_reel.dart';

void main() =>
    runApp(const DeviceReel(scene: _scene, seconds: 9.6, name: 'reel'));

const _paper = Color(0xfff6f4ef);
const _ink = Color(0xff141414);
const _quiet = Color(0xff8a8580);
const _accent = Color(0xffc2410c);

/// The weight ramp: one word, Regular to Ultralight to Black and back.
const _weights = [
  (FontWeight.w400, 'Regular'),
  (FontWeight.w100, 'Ultralight'),
  (FontWeight.w900, 'Black'),
  (FontWeight.w300, 'Light'),
  (FontWeight.w700, 'Bold'),
  (FontWeight.w400, 'Regular'),
];
const _weightTimes = [0.7, 2.2, 3.7, 5.2, 6.7];

/// A track row growing into a hero title and back, with its play button.
const _heroTimes = [1.4, 2.9, 4.4, 5.9, 7.4, 8.6];

/// The heart filling in and emptying, a beat after the title.
const _heartTimes = [2.1, 3.6, 6.6, 8.1];

/// The tab bar: the selected tab's icon becomes its word.
const _tabs = [
  (Icons.search_rounded, 'Search'),
  (Icons.home_rounded, 'Home'),
  (Icons.library_music_rounded, 'Library'),
  (Icons.settings_rounded, 'Settings'),
];

/// Which tab is selected, and from when: Home, round to Home again.
const _selected = [1, 2, 3, 0, 1];
const _tabTimes = [1.0, 2.8, 4.6, 6.4];

Widget _tab(double s, int j) {
  final (icon, word) = _tabs[j];
  final states = <MorphContent>[], at = <double>[];
  MorphContent of(int selected) => selected == j
      ? text(
          word,
          const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: _accent,
          ),
        )
      : MorphContent.icon(icon, size: 26, color: _ink);
  states.add(of(_selected.first));
  for (var k = 1; k < _selected.length; k++) {
    final next = of(_selected[k]);
    if (next == states.last) continue;
    states.add(next);
    at.add(_tabTimes[k - 1]);
  }
  return steps(s, states, at);
}

Widget _scene(double s) {
  final hero = [
    for (var k = 0; k <= _heroTimes.length; k++)
      text(
        'Night Drive',
        k.isOdd
            ? const TextStyle(
                fontFamily: 'CupertinoSystemDisplay',
                fontWeight: FontWeight.w800,
                fontSize: 30,
                color: _ink,
                height: 1,
              )
            : const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 17,
                color: _ink,
                height: 1,
              ),
      ),
  ];
  final play = [
    for (var k = 0; k <= _heroTimes.length; k++)
      MorphContent.icon(
        k.isOdd ? Icons.pause_rounded : Icons.play_arrow_rounded,
        size: 30,
        color: _paper,
      ),
  ];
  final heart = [
    for (var k = 0; k <= _heartTimes.length; k++)
      MorphContent.icon(
        k.isOdd ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        size: 26,
        color: _accent,
      ),
  ];
  return ColoredBox(
    color: _paper,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SF PRO, READ FROM iOS',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 1.2,
              color: _quiet,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'No font bundled. Letters and icons morph.',
            style: TextStyle(fontSize: 15, color: _quiet),
          ),
          const Spacer(),
          SizedBox(
            height: 120,
            child: Align(
              alignment: Alignment.centerLeft,
              child: steps(s, [
                for (final (w, _) in _weights)
                  text(
                    'Morph',
                    TextStyle(
                      fontWeight: w,
                      fontSize: 92,
                      color: _ink,
                      height: 1,
                    ),
                  ),
              ], _weightTimes),
            ),
          ),
          SizedBox(
            height: 28,
            child: Align(
              alignment: Alignment.centerLeft,
              child: steps(s, [
                for (final (_, name) in _weights)
                  text(
                    name,
                    const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      color: _accent,
                    ),
                  ),
              ], _weightTimes),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
            decoration: BoxDecoration(
              color: const Color(0xffffffff),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: steps(s, hero, _heroTimes),
                    ),
                  ),
                ),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(child: steps(s, heart, _heartTimes)),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: _ink,
                    shape: BoxShape.circle,
                  ),
                  child: steps(s, play, _heroTimes),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: const Color(0xffffffff),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                for (var j = 0; j < _tabs.length; j++)
                  Expanded(child: Center(child: _tab(s, j))),
              ],
            ),
          ),
          const Spacer(),
          const Text(
            'morphtext',
            style: TextStyle(
              fontFamily: 'CupertinoSystemDisplay',
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: _ink,
            ),
          ),
          const Text(
            'Flutter · rendered on iPhone',
            style: TextStyle(fontSize: 13, color: _quiet),
          ),
        ],
      ),
    ),
  );
}
