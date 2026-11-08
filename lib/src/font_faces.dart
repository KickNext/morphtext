import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import 'engine.dart';

/// One font file, read and parsed.
class FontFace {
  /// The face read from [asset].
  FontFace(this.asset, this.font);

  /// The asset key it was read from.
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
  final _faces = <String, Future<FontFace>>{};

  /// Recently built letter morphs. A map literal keeps insertion order, so
  /// the first key is the least recently used.
  final _morphs = <(String, String, int, int), GlyphMorph?>{};

  /// The face [style] names: the nearest declared weight in its family,
  /// upright or italic as asked.
  ///
  /// Throws a [StateError] when the family has no such face in the bundle's
  /// `FontManifest.json`.
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
    if (asset == null) {
      throw StateError('no ${italic ? 'italic' : 'upright'} face of "$family"');
    }
    final key = asset;
    return _faces[key] ??= bundle
        .load(key)
        .then(
          (data) => FontFace(key, GlyphFont.parse(data.buffer.asUint8List())),
        );
  }

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
