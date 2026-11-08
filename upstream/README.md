# Off the pin: two ways

morphtext uses morphnext's **internals** (`lib/src/font/open_type_font.dart`,
`lib/src/geometry/{morph_plan,resample,shape}.dart`), so `pubspec.yaml` pins
`morphnext: 0.6.1` exactly. A package on pub.dev can't live on that pin for
long: any morphnext release may move those files (open PRs #18 and #19 both
rewrite `morph_plan.dart`), and an exact pin conflicts with every app that
wants a newer morphnext for its icons.

Everything morphnext-specific is behind one file, `lib/src/engine.dart`
(`GlyphFont`, `GlyphShape`, `GlyphMorph`), so either way out changes only
that file and the pubspec.

## (a) A public API in morphnext (recommended)

- `ISSUE.md`: the issue text, ready to post.
- `0001-public-glyph-api.patch`: the PR, `git am`-able onto morphnext
  `v0.6.1` (and onto `main`, whose `lib/` is identical as of 2026-11-08).
  Adds `MorphFont`, `MorphGlyph`, `MorphGlyphPlan` (+188/-2, one new file,
  one test file). morphnext's suite passes (131 tests); analysis and format
  clean.
- `engine_public_api.dart`: morphtext's `engine.dart` rewritten on that API.
  Verified: morphtext's 11 tests pass against the patched morphnext through a
  path override.

When a morphnext release ships it: copy `engine_public_api.dart` over
`lib/src/engine.dart`, set `morphnext: ^<that release>`, delete this folder.

Why first: morphtext stays a real companion (one engine, fixes flow to both,
the credit is a dependency rather than a copy), and KickNext keeps control of
internals. Cost: it waits on someone else's review and release, and the
names may change in review.

## (b) Vendor the engine (fallback)

The local branch **`vendored`** (`git switch vendored`) copies the eight files
the engine needs under `lib/src/third_party/morphnext/` with morphnext's MIT
licence, its `THIRD_PARTY_NOTICES.md` (Morphicons and icon_font_generator,
both MIT), and a header in each file naming the source revision. The
`morphnext` dependency is dropped entirely; the spring presets it supplied
are copied as constants. Same tests pass.

Why fallback: publishable today with no pin and no waiting. Cost: ~5,000 lines
of someone else's parser to keep current by hand, fixes upstream don't reach
morphtext, and "companion to morphnext" becomes "contains a copy of
morphnext", which is a less friendly look even when the licence allows it.

A reasonable sequence: post (a); if there's no answer in a few weeks, or the
answer is no, publish from `vendored`, and switch back if (a) lands later.
