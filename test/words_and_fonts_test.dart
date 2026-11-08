import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphtext/morphtext.dart';
import 'package:morphtext/src/align.dart';
import 'package:morphtext/src/engine.dart';
import 'package:morphtext/src/morph_run.dart' show MorphMotion;

import 'support.dart';

List<(int?, int?)> align(String a, String b) =>
    alignLetters(a.runes.toList(), b.runes.toList());

/// Pixels of [widget] alone on the page.
Future<List<int>> shoot(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(page(widget));
  await settleFonts(tester);
  return (await pixels(tester)).$2;
}

void main() {
  setUpAll(loadFonts);

  group('letters align', () {
    test('a word with itself: every letter stays', () {
      expect(align('Amethyst', 'Amethyst'), [
        for (var i = 0; i < 8; i++) (i, i),
      ]);
    });

    test('letters morph in place; only the extra ones go', () {
      // A m kept, e->b t->e h->r morph, y s t go.
      expect(align('Amethyst', 'Amber'), [
        (0, 0),
        (1, 1),
        (2, 2),
        (3, 3),
        (4, 4),
        (5, null),
        (6, null),
        (7, null),
      ]);
    });

    test('a word slides when that keeps its letters', () {
      expect(align('Ruby', 'bRuby'), [
        (null, 0),
        (0, 1),
        (1, 2),
        (2, 3),
        (3, 4),
      ]);
    });

    test('spaces pair with spaces, never with letters', () {
      final pairs = align('Rose Quartz', 'Smoky Quartz');
      for (final (i, j) in pairs) {
        if (i == null || j == null) continue;
        expect('Rose Quartz'[i] == ' ', 'Smoky Quartz'[j] == ' ');
      }
      expect(pairs, contains((4, 5)));
    });

    test('from or to nothing', () {
      expect(align('', 'ab'), [(null, 0), (null, 1)]);
      expect(align('ab', ''), [(0, null), (1, null)]);
      expect(align('', ''), isEmpty);
    });

    test('every letter of each word is used once, in order', () {
      final random = Random(7);
      String word() => String.fromCharCodes([
        for (var k = random.nextInt(9); k > 0; k--) 97 + random.nextInt(6),
      ]);
      for (var n = 0; n < 500; n++) {
        final a = word(), b = word();
        final pairs = align(a, b);
        expect(
          [for (final (i, _) in pairs) ?i],
          [for (var i = 0; i < a.length; i++) i],
          reason: '$a -> $b',
        );
        expect(
          [for (final (_, j) in pairs) ?j],
          [for (var j = 0; j < b.length; j++) j],
          reason: '$a -> $b',
        );
      }
    });
  });

  group('word to word', () {
    testWidgets('the ends are the two words as plain text', (tester) async {
      final start = await shoot(
        tester,
        MorphText(
          'Amethyst',
          toText: 'Citrine',
          from: light,
          to: bold,
          progress: AlwaysStoppedAnimation(0),
        ),
      );
      expect(
        differing(
          start,
          await shoot(tester, const Text('Amethyst', style: light)),
        ),
        0,
      );
      final end = await shoot(
        tester,
        MorphText(
          'Amethyst',
          toText: 'Citrine',
          from: light,
          to: bold,
          progress: AlwaysStoppedAnimation(1),
        ),
      );
      expect(
        differing(end, await shoot(tester, Text('Citrine', style: bold))),
        0,
      );
    });

    testWidgets('between, it draws outlines', (tester) async {
      const widget = MorphText(
        'Amethyst',
        toText: 'Amber',
        from: light,
        to: sans,
        progress: AlwaysStoppedAnimation(.5),
      );
      final mid = await shoot(tester, widget);
      // The same widget with its fonts withheld draws plain text instead.
      await tester.pumpWidget(page(widget, bundle: NoFonts()));
      await settleFonts(tester);
      final (_, plain) = await pixels(tester);
      expect(mid.length, plain.length);
      expect(differing(mid, plain), greaterThan(mid.length ~/ 4 ~/ 50));
      expect(tester.takeException(), isNull);
    });

    testWidgets('it reads as the nearer word', (tester) async {
      final semantics = tester.ensureSemantics();
      for (final (t, word) in [(.3, 'Amethyst'), (.7, 'Amber')]) {
        await tester.pumpWidget(
          page(
            MorphText(
              'Amethyst',
              toText: 'Amber',
              from: light,
              to: bold,
              progress: AlwaysStoppedAnimation(t),
            ),
          ),
        );
        expect(find.bySemanticsLabel(word), findsOneWidget);
      }
      semantics.dispose();
    });

    testWidgets('AnimatedMorphText morphs a new word in', (tester) async {
      var ends = 0;
      Widget at(String word) =>
          page(AnimatedMorphText(word, style: light, onEnd: () => ends++));
      await tester.pumpWidget(at('Amethyst'));
      await settleFonts(tester);
      await tester.pumpWidget(at('Citrine'));
      await tester.pump(const Duration(milliseconds: 40));
      final morph = tester.widget<MorphText>(find.byType(MorphText));
      expect((morph.text, morph.toText), ('Amethyst', 'Citrine'));
      expect(morph.progress.value, inExclusiveRange(0, 1));

      await tester.pumpAndSettle();
      expect(ends, 1);
      final (_, settled) = await pixels(tester);
      expect(
        differing(
          settled,
          await shoot(tester, const Text('Citrine', style: light)),
        ),
        0,
      );
    });
  });

  group('springs', () {
    testWidgets('a spring hands over to plain text once, and stays there', (
      tester,
    ) async {
      // Bold to light: the spring overshoots and rings around the end. Were
      // it to draw plain text whenever t >= 1, it would swap between text
      // and outline as it rings, and thin strokes would shimmer.
      final settled = await shoot(tester, const Text('Amethyst', style: light));
      Widget at(TextStyle style) => page(
        // The default spring, MorphSprings.snappy, overshoots.
        AnimatedMorphText('Amethyst', style: style),
      );
      await tester.pumpWidget(at(bold));
      await settleFonts(tester);
      await tester.pumpWidget(at(light));
      final asText = <bool>[];
      var overshot = false;
      for (var k = 0; k < 90; k++) {
        await tester.pump(const Duration(milliseconds: 16));
        final t = tester
            .widget<MorphText>(find.byType(MorphText))
            .progress
            .value;
        overshot |= t > 1;
        final (_, frame) = await pixels(tester);
        // Mid-morph the box is between the two words' sizes.
        asText.add(
          frame.length == settled.length && differing(frame, settled) == 0,
        );
        if (!tester.hasRunningAnimations) break;
      }
      expect(overshot, isTrue, reason: 'snappy overshoots');
      expect(asText.last, isTrue, reason: 'it lands on plain text');
      // Once it reads as the plain text it stays so: no flipping back to
      // outlines as the spring rings (the text fades in as motion dies, so
      // the last frames in flight may already match it).
      final first = asText.indexOf(true);
      expect(
        asText.sublist(first).every((x) => x),
        isTrue,
        reason: 'no flip back to outlines: $asText',
      );
      expect(first, greaterThan(0), reason: 'outlines first: $asText');
    });

    testWidgets('by default it springs like morphnext and settles promptly', (
      tester,
    ) async {
      Widget at(TextStyle style) =>
          page(AnimatedMorphText('Amethyst', style: style));
      await tester.pumpWidget(at(bold));
      await settleFonts(tester);
      await tester.pumpWidget(at(light));
      final ts = <double>[];
      var elapsed = Duration.zero;
      while (tester.hasRunningAnimations) {
        await tester.pump(const Duration(milliseconds: 16));
        elapsed += const Duration(milliseconds: 16);
        ts.add(tester.widget<MorphText>(find.byType(MorphText)).progress.value);
      }
      // snappy's attack: past half the morph within the first 100 ms.
      expect(ts[5], greaterThan(.5));
      // Its little overshoot, then exactly the end once it's within half a
      // pixel (no creeping tail).
      expect(ts.reduce(max), greaterThan(1));
      expect(ts.last, 1);
      expect(elapsed, lessThan(const Duration(milliseconds: 600)));
    });

    testWidgets('the text fades in while the word still moves', (tester) async {
      // Frames in the last of the motion are neither outline nor text, and
      // the first frame at rest is the plain text: nothing changes after.
      final settled = await shoot(tester, const Text('Amethyst', style: light));
      Widget at(TextStyle style) =>
          page(AnimatedMorphText('Amethyst', style: style));
      await tester.pumpWidget(at(bold));
      await settleFonts(tester);
      await tester.pumpWidget(at(light));
      final gaps = <int>[];
      while (tester.hasRunningAnimations) {
        await tester.pump(const Duration(milliseconds: 8));
        final (_, frame) = await pixels(tester);
        gaps.add(
          frame.length == settled.length ? differing(frame, settled) : -1,
        );
      }
      // Converging on the text: the last frames in flight are already
      // close, and it ends exactly on it.
      expect(gaps.last, 0);
      final inFlight = gaps.sublist(0, gaps.length - 1).where((g) => g >= 0);
      expect(inFlight.last, lessThan(inFlight.first), reason: '$gaps');
    });

    testWidgets('a curve is optional, and ends on time', (tester) async {
      Widget at(TextStyle style) => page(
        AnimatedMorphText(
          'Amethyst',
          style: style,
          curve: Curves.easeOutCubic,
          duration: const Duration(milliseconds: 300),
        ),
      );
      await tester.pumpWidget(at(bold));
      await settleFonts(tester);
      await tester.pumpWidget(at(light));
      var maxT = 0.0;
      var elapsed = Duration.zero;
      while (tester.hasRunningAnimations) {
        await tester.pump(const Duration(milliseconds: 16));
        elapsed += const Duration(milliseconds: 16);
        maxT = max(
          maxT,
          tester.widget<MorphText>(find.byType(MorphText)).progress.value,
        );
      }
      expect(maxT, lessThanOrEqualTo(1));
      expect(elapsed, lessThanOrEqualTo(const Duration(milliseconds: 320)));
      expect(
        tester.widget<MorphText>(find.byType(MorphText)).progress.value,
        1,
      );
    });
  });

  group('handoff', () {
    testWidgets('AnimatedMorphText fades text in by default; 0 turns it off', (
      tester,
    ) async {
      Future<List<double?>> run(double? handoff) async {
        Widget at(TextStyle style) => page(
          handoff == null
              ? AnimatedMorphText('Amethyst', style: style)
              : AnimatedMorphText('Amethyst', style: style, handoff: handoff),
        );
        await tester.pumpWidget(at(bold));
        await settleFonts(tester);
        await tester.pumpWidget(at(light));
        final seen = <double?>[];
        while (tester.hasRunningAnimations) {
          await tester.pump(const Duration(milliseconds: 16));
          seen.add(
            tester.widget<MorphMotion>(find.byType(MorphMotion)).handoff,
          );
        }
        await tester.pumpWidget(const SizedBox());
        return seen;
      }

      expect((await run(null)).whereType<double>(), isNotEmpty);
      expect((await run(0)).whereType<double>(), isEmpty);
      // A wider window starts the fade earlier.
      final wide = await run(.3), narrow = await run(.05);
      expect(
        wide.indexWhere((h) => h != null),
        lessThan(narrow.indexWhere((h) => h != null)),
      );
    });

    testWidgets('MorphText is exact by default; handoff opts into the fade', (
      tester,
    ) async {
      Widget at(double t, double handoff) => MorphText(
        'Amethyst',
        from: bold,
        to: light,
        progress: AlwaysStoppedAnimation(t),
        handoff: handoff,
      );
      final exact = await shoot(tester, at(.97, 0));
      final faded = await shoot(tester, at(.97, .1));
      expect(differing(exact, faded), greaterThan(0));
      // Outside the window, and at the end, the two agree.
      expect(
        differing(
          await shoot(tester, at(.8, 0)),
          await shoot(tester, at(.8, .1)),
        ),
        0,
      );
      final text = await shoot(tester, const Text('Amethyst', style: light));
      expect(differing(await shoot(tester, at(1, .1)), text), 0);
    });
  });

  group('font to font', () {
    test('a serif and a sans (CFF) letter pair up', () {
      final serif = GlyphFont.parse(
        File('test/fonts/Fraunces-300-normal.ttf').readAsBytesSync(),
      );
      final sansFont = GlyphFont.parse(
        File('test/fonts/RedHatDisplay-Black.otf').readAsBytesSync(),
      );
      for (final rune in 'Amethyst Quartz'.runes) {
        if (rune == 32) continue;
        final a = serif.shape(rune)!, b = sansFont.shape(rune)!;
        final morph = GlyphMorph(a, b);
        expect(morph.pairCount, greaterThan(0));
        expect(morph.at(.5).every((c) => c.every((v) => v.isFinite)), isTrue);
      }
    });

    testWidgets('the ends are each font as plain text', (tester) async {
      final start = await shoot(
        tester,
        const MorphText(
          'Amethyst',
          from: light,
          to: sans,
          progress: AlwaysStoppedAnimation(0),
        ),
      );
      expect(
        differing(
          start,
          await shoot(tester, const Text('Amethyst', style: light)),
        ),
        0,
      );
      final end = await shoot(
        tester,
        const MorphText(
          'Amethyst',
          from: light,
          to: sans,
          progress: AlwaysStoppedAnimation(1),
        ),
      );
      expect(
        differing(
          end,
          await shoot(tester, const Text('Amethyst', style: sans)),
        ),
        0,
      );
    });

    testWidgets('word and font at once', (tester) async {
      await tester.pumpWidget(
        page(
          const MorphText(
            'Amethyst',
            toText: 'Quartz',
            from: light,
            to: sans,
            progress: AlwaysStoppedAnimation(.5),
          ),
        ),
      );
      await settleFonts(tester);
      expect(tester.takeException(), isNull);
      final end = await shoot(
        tester,
        const MorphText(
          'Amethyst',
          toText: 'Quartz',
          from: light,
          to: sans,
          progress: AlwaysStoppedAnimation(1),
        ),
      );
      expect(
        differing(end, await shoot(tester, const Text('Quartz', style: sans))),
        0,
      );
    });
  });
}
