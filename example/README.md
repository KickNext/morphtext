# morphtext example

The playground at [morphtext.drei.gg](https://morphtext.drei.gg), as a Flutter
app. For the short version, see [example.md](example.md).

- **AnimatedMorphText:** type a word, then change its face (Fraunces Light or
  SemiBold, Red Hat Display Black), size and colour, and its motion: one of
  morphnext's springs or a curve, with the line of code each one is, and how
  much of the end the text fades in over.
- **AnimatedMorph:** buttons whose labels flow into a tick, or a cross when
  the upload fails; and words flipping into their own icons and back.
- **MorphText:** a morph driven by an `AnimationController` through a chosen
  curve, played or scrubbed.

And a second app, **Records** (`lib/records.dart`): MorphText in a Hero. Tap an
album and its title morphs from the list's style to the page's as it flies;
the record slides out of its sleeve. `flutter run -t lib/records_main.dart`.

```bash
flutter run -d chrome   # or any device
```

Fonts: Fraunces (SIL OFL 1.1, `fonts/Fraunces-OFL.txt`; static Light and
SemiBold instances, Latin-1 subset) and Red Hat Display Light and Black (SIL OFL 1.1,
`fonts/RedHatDisplay-OFL.txt`, unmodified). Icons: Material Icons.
