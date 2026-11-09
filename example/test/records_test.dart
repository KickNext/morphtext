import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphtext/morphtext.dart';
import 'package:morphtext_example/records.dart';

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const RecordsApp());
  await tester.tap(find.byKey(const ValueKey('sleeve-moons')));
  await tester.pump(); // the route is pushed
  await tester.pump(); // the flight starts
}

MorphText _flyingTitle(WidgetTester tester) => tester.widget<MorphText>(
  find.byWidgetPredicate((w) => w is MorphText && w.text == 'Paper Moons'),
);

void main() {
  testWidgets(
    'the title flies as a MorphText from the list style to the page',
    (tester) async {
      await _open(tester);
      await tester.pump(const Duration(milliseconds: 400));

      final title = _flyingTitle(tester);
      final fonts = const RecordFonts(child: SizedBox());
      expect(title.from, fonts.listTitle);
      expect(title.to, fonts.pageTitle);
      expect(title.progress.value, inExclusiveRange(0, 1));
      // In the overlay, under a Material: no yellow "no Material" underline.
      expect(
        find.ancestor(
          of: find.byWidget(title),
          matching: find.byWidgetPredicate(
            (w) => w is Material && w.type == MaterialType.transparency,
          ),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('it lands as the page title, and flies back the same way', (
    tester,
  ) async {
    await _open(tester);
    // The flight, then the record sliding out; it spins for as long as the
    // page is open, so this pumps a fixed time rather than settling.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(MorphText), findsNothing);
    expect(find.text('Folded Light'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('back')));
    // The record tucks itself away first, then the page pops.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final title = _flyingTitle(tester);
    expect(title.progress.value, inExclusiveRange(0, 1));
    expect(title.from, const RecordFonts(child: SizedBox()).listTitle);

    await tester.pumpAndSettle();
    expect(find.text('Folded Light'), findsNothing);
    expect(find.byType(MorphText), findsNothing);
  });
}
