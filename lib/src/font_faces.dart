import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import 'engine.dart';
import 'system_font.dart';

/// One font file, read and parsed.
class FontFace {
  /// The face read from [asset].
  FontFace(this.asset, this.font);

  /// The asset key it was read from, and for a variable face, where on
  /// its axes: what tells one face from another.
  final String asset;

  /// Its parsed outlines.
  final GlyphFont font;
}

/// One asset bundle's fonts: its manifest, each face read once, and the
/// letter morphs built between them.
class FontFaces {
  FontFaces._(this.bundle);

  /// The fonts of [bundle], shared by every morph that uses it.
  static FontFaces of(AssetBundle bundle) =>
      _byBundle[bundle] ??= FontFaces._(bundle);

  static final _byBundle = Expando<FontFaces>('morphtext fonts');

  /// How many letter morphs to keep, most recently used first.
  static const _maxMorphs = 512;

  /// The bundle the fonts come from.
  final AssetBundle bundle;

  Future<List<Object?>>? _manifest;
  final _faces = <String, FontFace>{};

  /// Recently built letter morphs. A map literal keeps insertion order, so
  /// the first key is the least recently used.
  final _morphs = <(String, String, int, int), GlyphMorph?>{};

  /// The face [style] names: the nearest declared weight in its family,
  /// upright or italic as asked. On iOS, a
  /// family the bundle doesn't declare that names the system
  /// font (none, or `CupertinoSystemText` and the like) is read from
  /// CoreText instead.
  ///
  /// A variable face is read at the `wght` and `opsz` that Flutter draws it
  /// at: the style's [TextStyle.fontVariations], and for the system font,
  /// what its weight and family draw where those don't say.
  ///
  /// Throws a [StateError] when the family has no such face in the bundle's
  /// `FontManifest.json` and isn't the system font.
  Future<FontFace> face(TextStyle style) async {
    final family = style.fontFamily ?? '';
    final weight = (style.fontWeight ?? FontWeight.normal).value;
    final italic = style.fontStyle == FontStyle.italic;
    final manifest = await (_manifest ??= bundle
        .loadString('FontManifest.json', cache: false)
        .then((json) => jsonDecode(json) as List<Object?>));
    String? asset;
    var nearest = double.infinity;
    for (final entry in manifest.cast<Map<String, Object?>>()) {
      if (entry['family'] != family) continue;
      final fonts = (entry['fonts']! as List<Object?>)
          .cast<Map<String, Object?>>();
      for (final font in fonts) {
        if ((font['style'] == 'italic') != italic) continue;
        final declared = font['weight'] as int? ?? FontWeight.normal.value;
        final distance = (declared - weight).abs();
        if (distance < nearest) {
          nearest = distance.toDouble();
          asset = font['asset']! as String;
        }
      }
    }
    final system = asset == null && !italic && isSystemStyle(style);
    if (asset == null && !system) {
      throw StateError('no ${italic ? 'italic' : 'upright'} face of "$family"');
    }
    final file = asset ?? _systemAsset;
    final parsed = _files[file] ??= system
        ? Future(() {
            final bytes = systemFontBytes();
            if (bytes == null) throw StateError('no system font from CoreText');
            return GlyphFont.parse(bytes);
          })
        : bundle
              .load(file)
              .then((data) => GlyphFont.parse(data.buffer.asUint8List()));
    final font = await parsed;
    if (font.axes.isEmpty) {
      return _faces[file] ??= FontFace(file, font);
    }
    double? axis(String tag) {
      for (final v in style.fontVariations ?? const <FontVariation>[]) {
        if (v.axis == tag) return v.value;
      }
      return null;
    }

    final wght = axis('wght') ?? (system ? systemWeight(style) : null);
    final opsz = axis('opsz') ?? (system ? systemOpticalSize(style) : null);
    final key = '$file@wght=$wght,opsz=$opsz';
    return _faces[key] ??= FontFace(
      key,
      font.varied(weight: wght, opticalSize: opsz),
    );
  }

  /// The key the system font's file is kept under, apart from the bundle's.
  static const _systemAsset = 'morphtext:system';

  /// Each font file, parsed once.
  final _files = <String, Future<GlyphFont>>{};

  /// The morph from [runeA] in face [a] to [runeB] in face [b], or null when
  /// either has no outline to read (a space, a missing letter).
  GlyphMorph? morph(FontFace a, FontFace b, int runeA, int runeB) {
    final key = (a.asset, b.asset, runeA, runeB);
    if (_morphs.containsKey(key)) {
      // Move it to the end: most recently used.
      return _morphs[key] = _morphs.remove(key);
    }
    GlyphMorph? morph;
    try {
      final shapeA = a.font.shape(runeA), shapeB = b.font.shape(runeB);
      if (shapeA != null && shapeB != null) morph = GlyphMorph(shapeA, shapeB);
    } on Object {
      morph = null;
    }
    _morphs[key] = morph;
    if (_morphs.length > _maxMorphs) _morphs.remove(_morphs.keys.first);
    return morph;
  }
}
