# morphtext

**Text that morphs letter by letter, outline into outline.**

A light word turns bold, a serif word turns sans, a small word grows, one
word becomes another, and it stays one word the whole way: no crossfade
between two copies, no ghosted double name in the middle. Each letter's real
outline is read from your bundled fonts and morphed into its counterpart, and
at either end it is plain text, pixel for pixel what a `Text` draws.

![Words and letters morphing: Amethyst going light to bold, small to large and serif to sans; a giant a becoming g, R, & and Q beside a phrase becoming each next word; a blue Quartz counting its weight from 300 to 600; and a grid of stone names becoming other stones in other faces](doc/demo.webp)

morphtext is a companion to [morphnext](https://github.com/KickNext/morphnext)
by KickNext, which morphs icon glyphs read from icon fonts. morphnext is the
engine here: its OpenType reader decodes each letter's outline and its
topology-aware planner pairs the contours of one letter with those of the
other. morphtext adds the text layer on top: laying out both ends, deciding
which letter becomes which, carrying every letter's em square from one layout
to the other, and handing back to plain text at the ends.

## What morphs

| From → to | How |
|---|---|
| Weight, size, colour, slant | Two `TextStyle`s in one family |
| One font into another | Two `TextStyle`s in different families (serif → sans, any bundled pair) |
| One word into another | `toText`, or a new `text` on `AnimatedMorphText` |
| All of it at once | Any combination of the above |

## Why

Most fonts ship a few static weights, not a variable axis, and no font
interpolates into a different font. Animating between two `TextStyle`s can
only crossfade (or snap), and a crossfade between `Amethyst` light and
`Amethyst` bold reads as two names stacked on each other. Morphing each
letter's outline gives the in-between shapes no font ever shipped.

## Install

> Draft: not on pub.dev yet.

```yaml
dependencies:
  morphtext: ^0.1.0
```

Requires Dart `>=3.9.0` and Flutter `>=3.32.0`.

Bundle every font face you morph between in `pubspec.yaml`, as you would for
`Text`. morphtext reads the outlines from those files:

```yaml
flutter:
  fonts:
    - family: Fraunces
      fonts:
        - asset: fonts/Fraunces-300-normal.ttf
          weight: 300
        - asset: fonts/Fraunces-600-normal.ttf
          weight: 600
    - family: RedHatDisplay
      fonts:
        - asset: fonts/RedHatDisplay-Black.otf
          weight: 900
```

## Implicit morph

Change `text`, `style` or both; `AnimatedMorphText` springs from what's on
screen to the new word in the new style. Turning back mid-flight reverses
from where the word is.

```dart
import 'package:morphtext/morphtext.dart';

const serif = TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.w300, fontSize: 52);
const sans = TextStyle(fontFamily: 'RedHatDisplay', fontWeight: FontWeight.w900, fontSize: 52);

GestureDetector(
  onTap: () => setState(() => stone = (stone + 1) % stones.length),
  child: AnimatedMorphText(
    stones[stone],               // a new word morphs from the old one
    style: loud ? sans : serif,  // a new style morphs too
  ),
)
```

It uses morphnext's `MorphSprings.snappy` by default; pass `MorphSprings.smooth`
or any `SpringDescription` as `spring`. `onEnd` fires when a transition
settles. With `MediaQuery.disableAnimations`, changes apply at once.

## Controlled morph

Drive `t` yourself (a page position, a scroll offset, a gesture, an
`AnimationController` in an `AnimatedBuilder`). It is clamped to 0–1.

```dart
MorphText(
  'Rose Quartz',
  from: serif.copyWith(fontSize: 22),
  to: serif.copyWith(fontSize: 48),
  t: progress,
)

MorphText(
  'Amethyst',
  toText: 'Citrine',   // optional: another word at t = 1
  from: serif,
  to: sans,
  t: progress,
)
```

Both styles are merged onto the ambient `DefaultTextStyle`, like `Text`.
Fonts from a package are named the Flutter way:
`TextStyle(fontFamily: 'Fraunces', package: 'my_fonts')`. Don't write the
`packages/my_fonts/Fraunces` string yourself: merging with the default style
would prefix it twice.

## Which letter becomes which

Between two words, letters pair by a weighted edit distance: a letter kept as
itself costs nothing, a letter morphing into another costs a little less than
one appearing or vanishing, and letters never pair with spaces. So most
letters morph into the letter at the same place (`Amethyst` into `Citrine`),
as few as possible appear or vanish (usually just the difference in length),
and a word slides only when that keeps many letters as themselves (`Ruby`
into `bRuby`). Letters left over shrink to a point in the first half of the
morph, or grow from one in the second.

Between two fonts or two weights, the same letter pairs with itself, and
morphnext pairs its contours: the bowl of a serif `a` with the bowl of a
sans `a`. When the two designs differ in structure (a two-storey `g` into a
single-storey one), the extra contour shrinks to a point.

## How it works

1. Flutter lays out both ends with `TextPainter`: each letter's pen position,
   kerning and baseline.
2. For each style, the font file is found through `FontManifest.json` (the
   family's nearest declared weight, upright or italic as asked) and parsed
   once by morphnext's OpenType reader (TrueType or CFF outlines). Each
   letter's outline is sampled into contours.
3. Letters are paired (above), and morphnext plans each pair's morph.
4. Each frame, every pair's outline is interpolated to `t` and drawn into its
   em square, carried from its place in the first layout to its place in the
   second.
5. At `t = 0` and `t = 1` it draws the text with `TextPainter` instead, so
   resting text is real text: hinting, antialiasing and all.

Fonts, plans and layouts are cached: a font is parsed once per asset bundle,
and letter plans are shared by every `MorphText` on the bundle.

## Limitations

- **The outlines must be readable from the bundled font file.** TrueType
  (`glyf`) and CFF outlines in `.ttf`/`.otf`, declared in `pubspec.yaml`.
  Fonts loaded at runtime (`FontLoader`, google_fonts downloads) or system
  fonts aren't in `FontManifest.json`. Then `MorphText` draws plain text and
  switches at the middle (a debug build says why, once).
- **Plain-text ends.** Only `t` strictly between 0 and 1 draws outlines. The
  outline is filled geometry, without hinting, so on small low-DPI text the
  first frame of a morph can look a hair softer than the text at rest.
- **In-between shapes of different letters are abstract.** Weight, size and
  font morphs keep each letter recognisable; one letter morphing into
  another (`y` into `i`) passes through shapes that are neither, as
  morphnext's icons do. At spring speed it reads as motion.
- **One line, one direction, no shaping.** Letters morph code point by code
  point at the positions Flutter laid out, so scripts that shape glyphs
  contextually (Arabic, Indic) and ligatures don't morph faithfully. If your
  font has ligatures in the word (`fi`, `ffl`), turn them off in both styles
  with `fontFeatures: [FontFeature.disable('liga')]`.
- **Letters missing from the font** (fallback glyphs, emoji) are drawn as
  text at their moving position, the nearer end's letter, rather than
  morphed.
- **Static faces morph; variable axes don't yet.** A single variable font is
  read at its default instance (see *Ideas*).
- **A third target mid-flight** starts from whichever of the two ends the
  text is nearer, not from the in-between shape.
- **Semantics.** The text is painted, not laid out as a `Text`, so it is
  exposed as one semantics node labelled with the nearer word (override with
  `semanticsLabel`). It isn't selectable.

## Ideas

- Variable fonts: read each style's `wght` from `fontVariations` and morph
  between two instances of one file (morphnext's reader already supports the
  axes).
- Interrupting with a third target from the in-between shape, as
  `AnimatedMorphIcon` does.
- Multi-line text.

## Example

`example/` is a small app: tap the word for the next stone, switch it
between light, bold and a sans, and slide to grow another word.

The hero above follows the shape of morphnext's own, so the two read as a
pair. It is rendered frame by frame in a widget test
(`tool/record_demo_test.dart`, 1280x720 at 60 fps) and encoded by
`tool/record_demo.sh`. `tool/morph_strip_test.dart` renders word-to-word and
font-to-font morphs side by side for a quick look.

## License and attribution

morphtext is MIT licensed.

It is built on [morphnext](https://github.com/KickNext/morphnext) (MIT,
© 2026 KickNext), whose outline reader and morph planner do the heavy
lifting; morphnext in turn adapts MIT-licensed work from Morphicons and
icon_font_generator (see its `THIRD_PARTY_NOTICES.md`). morphtext is an
independent project, not affiliated with or endorsed by KickNext.

The example and tests bundle Fraunces (© 2020 The Fraunces Project Authors)
and Red Hat Display (© 2021 Red Hat, Inc., Reserved Font Name "Red Hat",
included unmodified), both under the SIL Open Font License 1.1.
