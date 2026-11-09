// The Apple system font (SF Pro), read from CoreText at run time.
//
// Apple doesn't let an app bundle SF Pro (TN3214); a Flutter app on iOS
// draws it through the system font instead, so it never appears in
// FontManifest.json. CoreText hands over the system font's tables
// (CTFontCopyTable, in core_text.dart), and this file reassembles them into
// an in-memory font file for the outline reader. Nothing is shipped or
// written to disk.

import 'dart:typed_data';

import 'package:flutter/painting.dart';

import 'core_text_none.dart' if (dart.library.ffi) 'core_text.dart' as core;

/// The family names Flutter draws with the Apple system font: none at all
/// (the platform default), Flutter's own two, and Apple's private names.
const systemFamilies = {
  '',
  'CupertinoSystemText',
  'CupertinoSystemDisplay',
  '.AppleSystemUIFont',
  '.SF UI Text',
  '.SF UI Display',
  '.SF Pro Text',
  '.SF Pro Display',
  '.SF NS',
  '.SFNS',
};

/// Whether the system font is read from CoreText here: on iOS, where the
/// way Flutter draws it was measured. Elsewhere, macOS included, the system
/// font stays plain text, as before.
bool get hasSystemFont => core.available;

/// Whether [style] is drawn with the system font, and it can be read here.
bool isSystemStyle(TextStyle style) =>
    hasSystemFont && systemFamilies.contains(style.fontFamily ?? '');

/// Whether [style] names the Display cut Flutter registers apart:
/// `CupertinoSystemDisplay`, or Apple's private Display names.
bool _isDisplay(TextStyle style) => switch (style.fontFamily) {
  'CupertinoSystemDisplay' || '.SF UI Display' || '.SF Pro Display' => true,
  _ => false,
};

/// SF's named weights on its `wght` axis (1 to 1000), Ultralight to Black:
/// where CoreText puts Flutter's `w100` to `w900`.
const _namedWeights = [30.925, 110.725, 274.315, 400, 510, 590, 700, 860, 1000];

/// The `wght` the system font is drawn at for [style].
///
/// Measured on an iPhone (iOS 26, Flutter 3.47) by fitting outlines to what
/// `Text` draws (example/lib/system_font_main.dart). The default family and
/// `CupertinoSystemText` land on SF's named weights: `w100` is Ultralight
/// at 31, `w900` Black at 1000. `CupertinoSystemDisplay`, which Flutter's
/// engine registers one weight at a time, takes the weight as is up to
/// `w800`, and about 870 for `w900`.
double systemWeight(TextStyle style) {
  final weight = (style.fontWeight ?? FontWeight.normal).value;
  if (_isDisplay(style)) return weight == 900 ? 870 : weight.toDouble();
  return _namedWeights[weight ~/ 100 - 1].toDouble();
}

/// The `opsz` the system font is drawn at for [style], measured as
/// [systemWeight] is: whatever the size, the default family and
/// `CupertinoSystemText` are SF's Text design (the axis minimum, 17), and
/// `CupertinoSystemDisplay` its default design (28), the one Flutter's
/// engine registers it from.
double systemOpticalSize(TextStyle style) => _isDisplay(style) ? 28 : 17;

Uint8List? _bytes;
var _read = false;

/// The system UI font as an OpenType file, assembled from the tables
/// CoreText reports for it. Null where there's no CoreText or it gave
/// nothing. Read once.
Uint8List? systemFontBytes() {
  if (_read) return _bytes;
  _read = true;
  if (!hasSystemFont) return null;
  final tables = core.systemFontTables();
  return _bytes = tables == null || tables.isEmpty ? null : sfnt(tables);
}

/// An OpenType file holding [tables], by tag: the header, the table
/// records in tag order, then each table on a four-byte boundary. Checksums
/// are left at zero; nothing that reads it checks them.
Uint8List sfnt(Map<int, Uint8List> tables) {
  final tags = tables.keys.toList()..sort();
  final n = tags.length;
  var size = 12 + 16 * n;
  final offsets = <int>[];
  for (final tag in tags) {
    offsets.add(size);
    size += (tables[tag]!.length + 3) & ~3;
  }
  final out = Uint8List(size);
  final view = ByteData.sublistView(out);
  const glyf = 0x676c7966; // 'glyf'
  view.setUint32(0, tables.containsKey(glyf) ? 0x00010000 : 0x4f54544f);
  var power = 1, log = 0;
  while (power * 2 <= n) {
    power *= 2;
    log++;
  }
  view
    ..setUint16(4, n)
    ..setUint16(6, power * 16)
    ..setUint16(8, log)
    ..setUint16(10, n * 16 - power * 16);
  for (var i = 0; i < n; i++) {
    final record = 12 + 16 * i;
    view
      ..setUint32(record, tags[i])
      ..setUint32(record + 8, offsets[i])
      ..setUint32(record + 12, tables[tags[i]]!.length);
    out.setAll(offsets[i], tables[tags[i]]!);
  }
  return out;
}
