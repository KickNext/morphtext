## 0.1.0-dev.1

- `MorphText`: text morphing letter by letter, driven by `t`, between any two
  styles (weight, size, colour, slant, or one font family into another) and,
  with `toText`, from one word into another. Plain text at either end.
- `AnimatedMorphText`: springs to each new text and style, reversing
  mid-flight.
- Letters pair by a weighted edit distance; leftover letters shrink to or
  grow from a point.
- Extracted from Numina, where it carries a stone's name from Today's light
  title to its card's bold one.
