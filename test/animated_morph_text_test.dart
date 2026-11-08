import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphtext/morphtext.dart';

import 'support.dart';

void main() {
  setUpAll(loadFonts);

  double t(WidgetTester tester) =>
      tester.widget<MorphText>(find.byType(MorphText)).progress.value;

  testWidgets('a new style morphs in, then settles as plain text', (
    tester,
  ) async {
    var ends = 0;
    Widget at(TextStyle style) =>
        page(AnimatedMorphText('Amethyst', style: style, onEnd: () => ends++));
    await tester.pumpWidget(at(light));
    await settleFonts(tester);
    expect(t(tester), 1);

    await tester.pumpWidget(at(bold));
    await tester.pump(const Duration(milliseconds: 40));
    expect(t(tester), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(t(tester), 1);
    expect(ends, 1);

    final (_, morph) = await pixels(tester);
    await tester.pumpWidget(page(Text('Amethyst', style: bold)));
    final (_, text) = await pixels(tester);
    expect(differing(morph, text), 0);
  });

  testWidgets('turning back reverses from where it is', (tester) async {
    var ends = 0;
    Widget at(TextStyle style) =>
        page(AnimatedMorphText('Amethyst', style: style, onEnd: () => ends++));
    await tester.pumpWidget(at(light));
    await tester.pumpWidget(at(bold));
    await tester.pump(const Duration(milliseconds: 60));
    final mid = t(tester);
    expect(mid, inExclusiveRange(0, 1));

    await tester.pumpWidget(at(light));
    final morph = tester.widget<MorphText>(find.byType(MorphText));
    expect(morph.from, bold);
    expect(morph.to, light);
    // To within Cubic.transform's own precision.
    expect(morph.progress.value, closeTo(1 - mid, 1e-3));

    await tester.pumpAndSettle();
    expect(t(tester), 1);
    expect(ends, 1, reason: 'the interrupted run never ended');
  });

  testWidgets('reduced motion applies a new style at once', (tester) async {
    Widget at(TextStyle style) => MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: page(AnimatedMorphText('Amethyst', style: style)),
    );
    await tester.pumpWidget(at(light));
    await tester.pumpWidget(at(bold));
    final morph = tester.widget<MorphText>(find.byType(MorphText));
    expect((morph.from, morph.to, morph.progress.value), (bold, bold, 1));
  });
}
