// Where there's no dart:ffi (the web): no CoreText, so the system font
// stays plain text.

import 'dart:typed_data';

/// Whether CoreText is read here: never.
const available = false;

/// No tables to read.
Map<int, Uint8List>? systemFontTables() => null;
