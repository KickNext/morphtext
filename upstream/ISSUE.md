<!--
DRAFT for KickNext/morphnext. Not posted. Drei decides whether, when, and
under whose account it goes up, and whether the patch goes with it as a PR.
Checked 2026-11-08: no existing issue on this; main's lib/ is identical to
v0.6.1; open PRs #18 and #19 both change lib/src/geometry/morph_plan.dart.
-->

**Title:** Public API for glyph outlines and plans (morphing beyond icons)

Hi! Thanks for morphnext. The outline reader and the contour planner are
lovely work, and they turn out to be useful beyond icons.

### What I built on it

[morphtext](https://drei.gg/morphtext) morphs *text* between two styles letter
by letter: a light word turns bold, a small word grows, and it stays one word
the whole way instead of crossfading between two copies. It came out of an
app where a stone's name flies from a light title to a card's bold title; the
font ships two static weights, so every crossfade read as two names.

Flutter lays the word out in both styles; for each letter, morphnext reads the
outline from the bundled font file and plans the morph between the light and
the bold glyph. At the ends it draws plain text. (Demo: <link to demo.webp>)

It credits morphnext as the engine, and I'd like it to depend on morphnext
properly rather than copy it.

### The problem

The pieces it needs are internal: `OpenTypeFont` (`src/font/open_type_font.dart`),
`sampleContoursWithPointCounts` (`src/geometry/resample.dart`), `MorphShape` /
`CubicContour` (`src/geometry/shape.dart`) and `buildMorphPlan` / `MorphPlan`
(`src/geometry/morph_plan.dart`). Today morphtext imports them from `lib/src`
and pins `morphnext: 0.6.1` exactly, which is fragile for both of us: #18 and
#19 already reshape `morph_plan.dart`, and you shouldn't have to think about
a downstream package when you refactor internals.

### Proposal

A small public surface, nothing about icons, widgets or caching:

```dart
/// A font file's outlines.
final class MorphFont {
  factory MorphFont.parse(Uint8List bytes);  // throws FormatException
  bool contains(int codePoint);
  /// In ems about the glyph's origin; null if absent or empty (a space).
  MorphGlyph? glyph(int codePoint,
      {double? weight, double? fill, double? grade, double? opticalSize});
}

/// One glyph, sampled for morphing. x right of the origin, y down from the
/// ascender, in ems.
final class MorphGlyph {
  double get advance;
  double get ascender;
  double get descender;
  int get contourCount;
}

/// The morph between two glyphs, paired as MorphIcon pairs icons.
final class MorphGlyphPlan {
  factory MorphGlyphPlan(MorphGlyph from, MorphGlyph to);
  int get contourCount;
  bool get isOneToOne;   // no contour grew from / shrank to a point
  List<Float64List> allocateOutput();
  void interpolate(double t, List<Float64List> output);
}
```

All three wrap what exists; `MorphShape` and `MorphPlan` stay private, so you
keep the freedom to change sampling and matching. The glyph is sampled exactly
as `MorphRepository` samples an icon (the point-count rule is shared, not
copied), and the variable-font arguments map to the existing
`FontVariationSelection`.

I have this as a patch against v0.6.1: one new file
(`lib/src/morph_glyph.dart`, ~130 lines), one export, the point-count helper
made package-visible, and `test/morph_glyph_test.dart` using your
`TestFontBuilder` (glyph reading, missing/empty glyphs, pairing, one-to-one
detection, bad bytes). The full suite passes (131 tests), `flutter analyze
--fatal-infos lib test` and `dart format` are clean. morphtext's own tests pass
against it unchanged.

Would you take this as a PR? Happy to rename anything (`MorphFont` vs
`MorphGlyphFont`, say), trim the variable-font arguments, rebase onto #18 if
that lands first, or go a different way if you'd rather expose this
differently.
