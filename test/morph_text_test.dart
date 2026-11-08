import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphtext/morphtext.dart';
import 'package:morphtext/src/engine.dart';

import 'support.dart';

void main() {
  setUpAll(loadFonts);

  group('the ends are plain text', () {
    for (final (name, end, t) in [
      ('t = 0 is the light word', light, 0.0),
      ('t = 1 is the bold word', bold, 1.0),
    ]) {
      testWidgets(name, (tester) async {
        await tester.pumpWidget(page(const Text('Amethyst', style: light)));
        await tester.pumpWidget(page(Text('Amethyst', style: end)));
        final (textSize, text) = await pixels(tester);

        await tester.pumpWidget(
          page(
            MorphText(
              'Amethyst',
              from: light,
              to: bold,
              progress: AlwaysStoppedAnimation(t),
            ),
          ),
        );
        await settleFonts(tester);
        final (morphSize, morph) = await pixels(tester);

        expect(morphSize, textSize);
        expect(differing(morph, text), 0);
      });
    }

    testWidgets('and between, it is not', (tester) async {
      await tester.pumpWidget(page(Text('Amethyst', style: bold)));
      final (_, text) = await pixels(tester);
      await tester.pumpWidget(
        page(
          MorphText(
            'Amethyst',
            from: light,
            to: bold,
            progress: AlwaysStoppedAnimation(.5),
          ),
        ),
      );
      await settleFonts(tester);
      final (_, morph) = await pixels(tester);
      expect(differing(morph, text), greaterThan(0));
    });
  });

  test('every letter pairs one to one, light to bold', () {
    final a = GlyphFont.parse(
      File('test/fonts/Fraunces-300-normal.ttf').readAsBytesSync(),
    );
    final b = GlyphFont.parse(
      File('test/fonts/Fraunces-600-normal.ttf').readAsBytesSync(),
    );
    const sample = 'Amethyst Rose Quartz Obsidian Labradorite 0123456789';
    for (final rune in sample.runes) {
      final letter = String.fromCharCode(rune);
      final sa = a.shape(rune), sb = b.shape(rune);
      if (letter == ' ') {
        expect(sa, isNull, reason: 'a space has no outline');
        continue;
      }
      expect(sa, isNotNull, reason: letter);
      expect(sb, isNotNull, reason: letter);
      expect(sa!.contourCount, sb!.contourCount, reason: letter);
      final morph = GlyphMorph(sa, sb);
      expect(morph.pairCount, sa.contourCount, reason: letter);
      expect(morph.isOneToOne, isTrue, reason: letter);
    }
  });

  testWidgets('it sits where Text sits, at its size', (tester) async {
    await tester.pumpWidget(page(Text('Amethyst', style: big)));
    final textCentre = tester.getCenter(find.byType(Text));

    for (final t in [0.0, .25, .5, .75, 1.0]) {
      await tester.pumpWidget(
        page(
          MorphText(
            'Amethyst',
            from: light,
            to: big,
            progress: AlwaysStoppedAnimation(t),
          ),
        ),
      );
      await settleFonts(tester);
      final box = find.byType(MorphText);
      expect(tester.getCenter(box), textCentre, reason: 't = $t');
    }

    await tester.pumpWidget(page(Text('Amethyst', style: light)));
    final small = tester.getSize(find.byType(Text));
    await tester.pumpWidget(page(Text('Amethyst', style: big)));
    final large = tester.getSize(find.byType(Text));
    await tester.pumpWidget(
      page(
        MorphText(
          'Amethyst',
          from: light,
          to: big,
          progress: AlwaysStoppedAnimation(.5),
        ),
      ),
    );
    expect(tester.getSize(find.byType(MorphText)), Size.lerp(small, large, .5));
  });

  testWidgets('an unbundled family stays plain text', (tester) async {
    const nowhere = TextStyle(fontFamily: 'Nowhere', fontSize: 20);
    await tester.pumpWidget(
      page(
        MorphText(
          'Amethyst',
          from: nowhere,
          to: nowhere.copyWith(fontWeight: FontWeight.w700),
          progress: AlwaysStoppedAnimation(.5),
        ),
      ),
    );
    await settleFonts(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(MorphText), findsOneWidget);
  });

  testWidgets('it inherits the family from DefaultTextStyle', (tester) async {
    // Only the weight differs; the family comes from around it.
    await tester.pumpWidget(
      page(
        DefaultTextStyle(
          style: light,
          child: const MorphText(
            'Amethyst',
            from: TextStyle(),
            to: TextStyle(fontWeight: FontWeight.w600),
            progress: AlwaysStoppedAnimation(.5),
          ),
        ),
      ),
    );
    await settleFonts(tester);
    final (_, inherited) = await pixels(tester);
    await tester.pumpWidget(
      page(
        MorphText(
          'Amethyst',
          from: light,
          to: bold,
          progress: AlwaysStoppedAnimation(.5),
        ),
      ),
    );
    await settleFonts(tester);
    final (_, explicit) = await pixels(tester);
    expect(differing(inherited, explicit), 0);
  });

  testWidgets('it reads as the word', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      page(
        MorphText(
          'Amethyst',
          from: light,
          to: bold,
          progress: AlwaysStoppedAnimation(.5),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Amethyst'), findsOneWidget);
    semantics.dispose();
  });
}
