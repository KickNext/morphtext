import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphtext/morphtext.dart';
import 'package:morphtext_example/main.dart';

void main() {
  testWidgets('tapping the word morphs it bold', (tester) async {
    await tester.pumpWidget(const MorphTextDemo());
    await tester.pump();

    MorphText amethyst() => tester.widget<MorphText>(
      find.byWidgetPredicate((w) => w is MorphText && w.text == 'Amethyst'),
    );
    expect(amethyst().to.fontWeight, FontWeight.w300);

    await tester.tap(find.byType(AnimatedMorphText));
    await tester.pump(); // rebuilds with the new style; the spring starts
    await tester.pump(const Duration(milliseconds: 50));
    expect(amethyst().t, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(amethyst().to.fontWeight, FontWeight.w600);
    expect(amethyst().t, 1);
  });

  testWidgets('the slider grows the second word', (tester) async {
    await tester.pumpWidget(const MorphTextDemo());
    final quartz = find.byWidgetPredicate(
      (w) => w is MorphText && w.text == 'Rose Quartz',
    );
    final small = tester.getSize(quartz);
    await tester.drag(find.byType(Slider), const Offset(200, 0));
    await tester.pump();
    expect(tester.getSize(quartz).height, greaterThan(small.height));
  });
}
