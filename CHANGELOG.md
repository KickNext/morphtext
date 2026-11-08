## 0.1.0-dev.1

- `MorphText`: text morphing letter by letter, driven by `progress` (an
  `Animation<double>`, as morphnext's `MorphIcon` takes it), between any two
  styles (weight, size, colour, slant, or one font family into another) and,
  with `toText`, from one word into another. Plain text at either end.
- `AnimatedMorphText`: springs to each new text and style with morphnext's
  `MorphSprings.snappy` by default (re-exported; any `SpringDescription`
  works), reversing mid-flight from where it is and keeping its velocity;
  or along an optional `curve` over a fixed `duration`. Plain text at rest, faded in over the outlines in the
  last of the motion (`handoff`, 0.1 by default) so nothing changes after
  it lands. `MorphText` and `MorphBetween` take `handoff` too, 0 by default.
- `MorphContent`, `MorphBetween` and `AnimatedMorph`: text and icons morph
  into each other (a word flows into an icon, an icon into another), read
  from any bundled icon font; each end is pixel for pixel a `Text` or `Icon`.
- Letters pair by a weighted edit distance; leftover letters shrink to or
  grow from a point.
- Extracted from Numina, where it carries a stone's name from Today's light
  title to its card's bold one.
