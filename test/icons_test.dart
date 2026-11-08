import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphtext/morphtext.dart';
import 'package:morphtext/src/align.dart';

import 'support.dart';

List<(int?, int?)> converge(String a, String b) =>
    convergeLetters(a.runes.toList(), b.runes.toList());

/// Pixels of [widget] alone on the page.
Future<List<int>> shoot(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(page(widget));
  await settleFonts(tester);
  return (await pixels(tester)).$2;
}

const ink = Color(0xff1d1b20);
const send = MorphContent.text('Send', style: light);
const check = MorphContent.icon(
  Icons.check,
  size: 48,
  color: ink,
  semanticsLabel: 'Sent',
);
const close = MorphContent.icon(Icons.close, size: 48, color: ink);

void main() {
  setUpAll(loadFonts);

  group('letters converge', () {
    test('every letter of a word meets the single glyph', () {
      expect(converge('Send', 'x'), [(0, 0), (1, 0), (2, 0), (3, 0)]);
      expect(converge('x', 'Send'), [(0, 0), (0, 1), (0, 2), (0, 3)]);
    });

    test('spaces pair with nothing', () {
      expect(converge('a b', 'x'), [(0, 0), (1, null), (2, 0)]);
    });

    test('word to word and glyph to glyph align as usual', () {
      expect(
        converge('Ruby', 'bRuby'),
        alignLetters('Ruby'.runes.toList(), 'bRuby'.runes.toList()),
      );
      expect(converge('x', 'y'), [(0, 0)]);
    });
  });

  group('text and icons', () {
    testWidgets('the ends are exactly a Text and an Icon', (tester) async {
      final start = await shoot(
        tester,
        const MorphBetween(
          from: send,
          to: check,
          progress: AlwaysStoppedAnimation(0),
        ),
      );
      expect(
        differing(start, await shoot(tester, const Text('Send', style: light))),
        0,
      );
      final end = await shoot(
        tester,
        const MorphBetween(
          from: send,
          to: check,
          progress: AlwaysStoppedAnimation(1),
        ),
      );
      expect(
        differing(
          end,
          await shoot(tester, const Icon(Icons.check, size: 48, color: ink)),
        ),
        0,
      );
    });

    testWidgets('between, a word draws outlines flowing into the icon', (
      tester,
    ) async {
      const widget = MorphBetween(
        from: send,
        to: check,
        progress: AlwaysStoppedAnimation(.5),
      );
      final mid = await shoot(tester, widget);
      // Fonts withheld: plain text instead of outlines.
      await tester.pumpWidget(page(widget, bundle: NoFonts()));
      await settleFonts(tester);
      final (_, plain) = await pixels(tester);
      expect(mid.length, plain.length);
      expect(differing(mid, plain), greaterThan(mid.length ~/ 4 ~/ 50));
      expect(tester.takeException(), isNull);
    });

    testWidgets('one icon morphs into another', (tester) async {
      final mid = await shoot(
        tester,
        const MorphBetween(
          from: check,
          to: close,
          progress: AlwaysStoppedAnimation(.5),
        ),
      );
      final a = await shoot(
        tester,
        const Icon(Icons.check, size: 48, color: ink),
      );
      final b = await shoot(
        tester,
        const Icon(Icons.close, size: 48, color: ink),
      );
      expect(differing(mid, a), greaterThan(0));
      expect(differing(mid, b), greaterThan(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('an icon takes its size and colour from IconTheme', (
      tester,
    ) async {
      final themed = await shoot(
        tester,
        const IconTheme(
          data: IconThemeData(size: 40, color: Color(0xff1a73e8)),
          child: MorphBetween(
            from: MorphContent.icon(Icons.check),
            to: MorphContent.icon(Icons.check),
            progress: AlwaysStoppedAnimation(1),
          ),
        ),
      );
      final icon = await shoot(
        tester,
        const Icon(Icons.check, size: 40, color: Color(0xff1a73e8)),
      );
      expect(differing(themed, icon), 0);
    });

    testWidgets('it reads as the nearer end; an unlabelled icon as nothing', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        page(
          const MorphBetween(
            from: send,
            to: check,
            progress: AlwaysStoppedAnimation(.3),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Send'), findsOneWidget);
      await tester.pumpWidget(
        page(
          const MorphBetween(
            from: send,
            to: check,
            progress: AlwaysStoppedAnimation(.7),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Sent'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('AnimatedMorph springs from a word to an icon and back', (
      tester,
    ) async {
      var ends = 0;
      Widget at(MorphContent c) => page(AnimatedMorph(c, onEnd: () => ends++));
      await tester.pumpWidget(at(send));
      await settleFonts(tester);
      await tester.pumpWidget(at(check));
      await tester.pump(const Duration(milliseconds: 40));
      final morph = tester.widget<MorphBetween>(find.byType(MorphBetween));
      expect((morph.from, morph.to), (send, check));
      expect(morph.progress.value, inExclusiveRange(0, 1));

      // Turning back mid-flight reverses from where it is.
      await tester.pumpWidget(at(send));
      await tester.pump(const Duration(milliseconds: 16));
      final back = tester.widget<MorphBetween>(find.byType(MorphBetween));
      expect((back.from, back.to), (check, send));

      await tester.pumpAndSettle();
      expect(ends, 1);
      final (_, settled) = await pixels(tester);
      expect(
        differing(
          settled,
          await shoot(tester, const Text('Send', style: light)),
        ),
        0,
      );
    });
  });
}
