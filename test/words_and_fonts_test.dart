import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphtext/morphtext.dart';
import 'package:morphtext/src/align.dart';
import 'package:morphtext/src/engine.dart';

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
        MorphText('Amethyst', toText: 'Citrine', from: light, to: bold, t: 0),
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
        MorphText('Amethyst', toText: 'Citrine', from: light, to: bold, t: 1),
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
        t: .5,
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
            MorphText('Amethyst', toText: 'Amber', from: light, to: bold, t: t),
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
      expect(morph.t, inExclusiveRange(0, 1));

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
        const MorphText('Amethyst', from: light, to: sans, t: 0),
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
        const MorphText('Amethyst', from: light, to: sans, t: 1),
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
            t: .5,
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
          t: 1,
        ),
      );
      expect(
        differing(end, await shoot(tester, const Text('Quartz', style: sans))),
        0,
      );
    });
  });
}
