import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphtext/morphtext.dart';
import 'package:morphtext_example/main.dart';

MorphText _stone(WidgetTester tester) => tester.widget<MorphText>(
  find.descendant(
    of: find.byType(AnimatedMorphText),
    matching: find.byType(MorphText),
  ),
);

void main() {
  testWidgets('tapping the word morphs it into the next stone', (tester) async {
    await tester.pumpWidget(const MorphTextDemo());
    await tester.pump();
    expect(_stone(tester).toText, 'Amethyst');

    await tester.tap(find.byType(AnimatedMorphText));
    await tester.pump(); // rebuilds with the new word; the spring starts
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      (_stone(tester).text, _stone(tester).toText),
      ('Amethyst', 'Citrine'),
    );
    expect(_stone(tester).t, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(_stone(tester).t, 1);
  });

  testWidgets('Sans morphs the word into another font', (tester) async {
    await tester.pumpWidget(const MorphTextDemo());
    await tester.tap(find.text('Sans'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_stone(tester).from.fontFamily, 'Fraunces');
    expect(_stone(tester).to.fontFamily, 'RedHatDisplay');
    await tester.pumpAndSettle();
    expect(_stone(tester).t, 1);
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
