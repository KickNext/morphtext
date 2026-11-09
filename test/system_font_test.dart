import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphtext/src/engine.dart';
import 'package:morphtext/src/system_font.dart';

/// [file]'s tables by tag, as CoreText hands them over.
Map<int, Uint8List> tablesOf(Uint8List file) {
  final view = ByteData.sublistView(file);
  return {
    for (var i = 0, n = view.getUint16(4); i < n; i++)
      view.getUint32(12 + 16 * i): Uint8List.sublistView(
        file,
        view.getUint32(12 + 16 * i + 8),
        view.getUint32(12 + 16 * i + 8) + view.getUint32(12 + 16 * i + 12),
      ),
  };
}

/// [rune]'s outline in [font], as polygons in ems.
List<List<double>> polygons(GlyphFont font, int rune) {
  final shape = font.shape(rune)!;
  return [
    for (final p in GlyphMorph(shape, shape).at(0)) [...p],
  ];
}

void main() {
  for (final name in ['Fraunces-600-normal.ttf', 'RedHatDisplay-Black.otf']) {
    test('$name reassembled from its tables reads the same outlines', () {
      final original = File('test/fonts/$name').readAsBytesSync();
      final rebuilt = sfnt(tablesOf(original));
      final a = GlyphFont.parse(original), b = GlyphFont.parse(rebuilt);
      for (final rune in 'Amethyst Rg&8'.runes.where((r) => r != 32)) {
        expect(polygons(b, rune), polygons(a, rune));
      }
    });
  }

  test('a static face ignores a variation', () {
    final font = GlyphFont.parse(
      File('test/fonts/Fraunces-300-normal.ttf').readAsBytesSync(),
    );
    expect(font.axes, isEmpty);
    expect(
      polygons(font.varied(weight: 900, opticalSize: 72), 0x41),
      polygons(font, 0x41),
    );
  });

  test('Flutter weights map to where the system font draws them', () {
    double w(FontWeight weight, [String? family]) =>
        systemWeight(TextStyle(fontWeight: weight, fontFamily: family));
    // SF's named instances: Ultralight, Regular, Bold, Black.
    expect(w(FontWeight.w100), closeTo(30.9, .1));
    expect(w(FontWeight.w400), 400);
    expect(w(FontWeight.w700), 700);
    expect(w(FontWeight.w900), 1000);
    expect(w(FontWeight.w100, 'CupertinoSystemDisplay'), 100);
    expect(w(FontWeight.w900, 'CupertinoSystemDisplay'), 870);
    expect(systemOpticalSize(const TextStyle()), 17);
    expect(
      systemOpticalSize(const TextStyle(fontFamily: 'CupertinoSystemDisplay')),
      28,
    );
  });

  test('no system font where there is no CoreText', () {
    if (hasSystemFont) return; // Running on macOS: it has one.
    expect(isSystemStyle(const TextStyle()), isFalse);
    expect(systemFontBytes(), isNull);
  });
}
