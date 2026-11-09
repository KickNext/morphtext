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

And three for SF Pro on an iPhone, read from iOS with nothing bundled:

- **`lib/system_font_main.dart`:** a track title growing into a hero,
  Ultralight into Black, Play into Pause, and letters frozen mid-morph; on
  launch it checks its outlines against what `Text` draws and logs each
  match (`SFCHECK`).
- **`lib/system_font_reel.dart`:** a music player reel, weights, a hero
  title, and icons morphing into each other and into words.
- **`lib/system_font_flyer.dart`:** an old sale flyer, iPhone iPhone iPhone
  morphing in a wave to SF Pro.

The two reels render themselves frame by frame on the phone, 1080x1920 at 60
fps, into the app's Documents (`lib/device_reel.dart`); copy them off with
`xcrun devicectl device copy from --domain-type appDataContainer`.

```bash
flutter run -d chrome   # or any device
flutter run -t lib/system_font_flyer.dart   # on an iPhone
```

Fonts: Fraunces (SIL OFL 1.1, `fonts/Fraunces-OFL.txt`; static Light and
SemiBold instances, Latin-1 subset) and Red Hat Display Light and Black (SIL OFL 1.1,
`fonts/RedHatDisplay-OFL.txt`, unmodified). Icons: Material Icons.
