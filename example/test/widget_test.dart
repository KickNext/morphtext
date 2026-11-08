import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphtext/morphtext.dart';
import 'package:morphtext_example/main.dart';

MorphText _stage(WidgetTester tester) => tester.widget<MorphText>(
  find.descendant(
    of: find.byType(AnimatedMorphText),
    matching: find.byType(MorphText),
  ),
);

MorphText _scrub(WidgetTester tester) => tester.widget<MorphText>(
  find.byWidgetPredicate((w) => w is MorphText && w.text == 'Quartz'),
);

Future<void> _show(WidgetTester tester, {bool cycle = false}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MorphTextDemo(cycle: cycle));
  await tester.pump();
}

void main() {
  testWidgets('tapping the word morphs it into the next stone', (tester) async {
    await _show(tester);
    expect(_stage(tester).toText, 'Amethyst');

    await tester.tap(find.byType(AnimatedMorphText));
    await tester.pump(); // rebuilds with the new word; the spring starts
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      (_stage(tester).text, _stage(tester).toText),
      ('Amethyst', 'Citrine'),
    );
    expect(_stage(tester).progress.value, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(_stage(tester).progress.value, 1);
  });

  testWidgets('a typed word becomes the stage word', (tester) async {
    await _show(tester);
    await tester.enterText(find.byType(TextField).first, 'Hello');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(_stage(tester).toText, 'Hello');
  });

  testWidgets('Sans morphs the word into another font', (tester) async {
    await _show(tester);
    await tester.tap(find.text('Sans'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_stage(tester).from.fontFamily, 'Fraunces');
    expect(_stage(tester).to.fontFamily, 'RedHatDisplay');
    await tester.pumpAndSettle();
    expect(_stage(tester).progress.value, 1);
  });

  testWidgets('the t slider drives the scrubbed morph', (tester) async {
    await _show(tester);
    expect(_scrub(tester).progress.value, 0);
    await tester.ensureVisible(find.byKey(const Key('t')));
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const Key('t')), const Offset(200, 0));
    await tester.pump();
    expect(_scrub(tester).progress.value, greaterThan(0));
    expect(_scrub(tester).toText, 'Garnet');
  });

  testWidgets('the stage cycles on its own until touched', (tester) async {
    await _show(tester, cycle: true);
    await tester.pump(const Duration(milliseconds: 2400));
    await tester.pumpAndSettle();
    expect(_stage(tester).toText, 'Citrine');

    await tester.tap(find.byType(AnimatedMorphText));
    await tester.pumpAndSettle();
    expect(_stage(tester).toText, 'Quartz');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(_stage(tester).toText, 'Quartz');
  });

  testWidgets('Send becomes Sending, then a tick, then Send', (tester) async {
    await _show(tester);
    MorphContent button() => tester
        .widget<AnimatedMorph>(
          find.descendant(
            of: find.byKey(const Key('send')),
            matching: find.byType(AnimatedMorph),
          ),
        )
        .content;
    expect(button().text, 'Send');
    await tester.tap(find.byKey(const Key('send')));
    await tester.pump();
    expect(button().text, 'Sending');
    await tester.pump(const Duration(milliseconds: 1100));
    expect(button().icon, Icons.check_rounded);
    await tester.pump(const Duration(milliseconds: 1600));
    expect(button().text, 'Send');
    await tester.pumpAndSettle();
  });

  testWidgets('each pick flips the shape between word and icon', (
    tester,
  ) async {
    await _show(tester);
    MorphContent shape() =>
        tester.widget<AnimatedMorph>(find.byKey(const Key('shape'))).content;
    expect(shape().icon, Icons.check_rounded);

    // From the icon to the pick's word...
    await tester.ensureVisible(find.byKey(const ValueKey('pair-Love')));
    await tester.tap(find.byKey(const ValueKey('pair-Love')));
    await tester.pumpAndSettle();
    expect(shape().text, 'Love');

    // ...and again: the word into its own icon.
    await tester.tap(find.byKey(const ValueKey('pair-Love')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final morph = tester.widget<MorphBetween>(
      find.byWidgetPredicate(
        (w) => w is MorphBetween && w.to.icon == Icons.favorite,
      ),
    );
    expect(morph.from.text, 'Love');
    expect(morph.progress.value, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
  });

  testWidgets('a motion chip switches the stage to a curve', (tester) async {
    await _show(tester);
    AnimatedMorphText stage() =>
        tester.widget<AnimatedMorphText>(find.byType(AnimatedMorphText));
    expect(stage().curve, isNull);
    expect(stage().spring, MorphSprings.snappy);
    expect(find.textContaining('spring: MorphSprings.snappy'), findsOneWidget);

    await tester.ensureVisible(find.text('Ease out'));
    await tester.tap(find.text('Ease out'));
    await tester.pump();
    expect(stage().curve, Curves.easeOutCubic);
    expect(find.textContaining('curve: Curves.easeOutCubic'), findsOneWidget);
  });

  testWidgets('play runs the controlled morph along the chosen curve', (
    tester,
  ) async {
    await _show(tester);
    await tester.ensureVisible(find.text('Bounce out'));
    await tester.tap(find.text('Bounce out'));
    await tester.pump();
    final progress = _scrub(tester).progress;
    expect(progress, isA<CurvedAnimation>());
    expect((progress as CurvedAnimation).curve, Curves.bounceOut);

    await tester.ensureVisible(find.byKey(const Key('play')));
    await tester.tap(find.byKey(const Key('play')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(_scrub(tester).progress.value, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(_scrub(tester).progress.value, 1);
  });

  testWidgets('the text fade slider sets the stage\'s handoff', (tester) async {
    await _show(tester);
    AnimatedMorphText stage() =>
        tester.widget<AnimatedMorphText>(find.byType(AnimatedMorphText));
    expect(stage().handoff, AnimatedMorph.defaultHandoff);
    await tester.ensureVisible(find.byKey(const Key('handoff')));
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const Key('handoff')), const Offset(-400, 0));
    await tester.pump();
    expect(stage().handoff, 0);
    expect(find.textContaining('handoff: 0.00'), findsOneWidget);
  });

  testWidgets('Upload fails: Uploading, a cross, then Retry, every time', (
    tester,
  ) async {
    await _show(tester);
    MorphContent button() => tester
        .widget<AnimatedMorph>(
          find.descendant(
            of: find.byKey(const Key('upload')),
            matching: find.byType(AnimatedMorph),
          ),
        )
        .content;
    expect(button().text, 'Upload');
    for (final first in [true, false]) {
      await tester.ensureVisible(find.byKey(const Key('upload')));
      await tester.tap(find.byKey(const Key('upload')));
      await tester.pump();
      expect(button().text, 'Uploading');
      await tester.pump(const Duration(milliseconds: 1100));
      expect(button().icon, Icons.close_rounded, reason: 'first: $first');
      await tester.pump(const Duration(milliseconds: 1600));
      expect(button().text, 'Retry');
      await tester.pumpAndSettle();
    }
  });
}
