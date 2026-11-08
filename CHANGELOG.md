## 0.1.2

- A word and an icon now morph as one shape, every letter from its place in
  the word, instead of each letter carrying its own copy of the icon. The
  copies drifted apart as the morph began and covered each other's holes,
  so an outline icon (Tabler, Lucide, Material's `_border` and `_outline`
  icons) turned solid before it started to change. Letters with nothing to
  become now shrink away rather than all flowing into the icon.

## 0.1.1

- A shorter package description, within pub.dev's 180 characters.
- Changelog tidy-up.

## 0.1.0

First release.

- `MorphText`: text morphing letter by letter, driven by `progress` (an
  `Animation<double>`, as morphnext's `MorphIcon` takes it), between any two
  styles (weight, size, colour, slant, or one font family into another) and,
  with `toText`, from one word into another. Plain text at either end.
- `AnimatedMorphText`: springs to each new text and style with morphnext's
  `MorphSprings.snappy` by default (re-exported; any `SpringDescription`
  works), reversing mid-flight from where it is and keeping its velocity;
  or along an optional `curve` over a fixed `duration`. Plain text at rest,
  faded in over the outlines in the last of the motion (`handoff`, 0.1 by
  default) so nothing changes after it lands. `MorphText` and `MorphBetween` take `handoff` too, 0 by default.
- `MorphContent`, `MorphBetween` and `AnimatedMorph`: text and icons morph
  into each other (a word flows into an icon, an icon into another), read
  from any bundled icon font; each end is pixel for pixel a `Text` or `Icon`.
- Letters pair by a weighted edit distance; leftover letters shrink to or
  grow from a point.
- Extracted from an app we're building, where it carries a name from a light
  title to a card's bold one.
