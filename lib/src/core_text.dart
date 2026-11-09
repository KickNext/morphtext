// CoreText's copy of the system font's tables, through dart:ffi. Only
// compiled where there's dart:ffi (system_font.dart imports
// core_text_none.dart elsewhere, the web included).

import 'dart:ffi';
import 'dart:io' show Platform;
import 'dart:typed_data';

/// Whether CoreText is read here: iOS.
final bool available = Platform.isIOS;

/// The system UI font's tables by tag, or null when CoreText gave none.
Map<int, Uint8List>? systemFontTables() => _CoreText.open().systemFontTables();

typedef _Ref = Pointer<Void>;

/// The few CoreText and CoreFoundation calls it takes.
final class _CoreText {
  _CoreText(DynamicLibrary lib)
    : _uiFont = lib
          .lookupFunction<
            _Ref Function(Uint32, Double, _Ref),
            _Ref Function(int, double, _Ref)
          >('CTFontCreateUIFontForLanguage'),
      _tables = lib
          .lookupFunction<
            _Ref Function(_Ref, Uint32),
            _Ref Function(_Ref, int)
          >('CTFontCopyAvailableTables'),
      _table = lib
          .lookupFunction<
            _Ref Function(_Ref, Uint32, Uint32),
            _Ref Function(_Ref, int, int)
          >('CTFontCopyTable'),
      _count = lib.lookupFunction<IntPtr Function(_Ref), int Function(_Ref)>(
        'CFArrayGetCount',
      ),
      _at = lib
          .lookupFunction<
            _Ref Function(_Ref, IntPtr),
            _Ref Function(_Ref, int)
          >('CFArrayGetValueAtIndex'),
      _length = lib.lookupFunction<IntPtr Function(_Ref), int Function(_Ref)>(
        'CFDataGetLength',
      ),
      _data = lib
          .lookupFunction<
            Pointer<Uint8> Function(_Ref),
            Pointer<Uint8> Function(_Ref)
          >('CFDataGetBytePtr'),
      _release = lib.lookupFunction<Void Function(_Ref), void Function(_Ref)>(
        'CFRelease',
      );

  /// CoreText is loaded in every iOS app; the process has its symbols.
  factory _CoreText.open() {
    try {
      return _CoreText(DynamicLibrary.process());
    } on ArgumentError {
      return _CoreText(
        DynamicLibrary.open(
          '/System/Library/Frameworks/CoreText.framework/CoreText',
        ),
      );
    }
  }

  static const _kCTFontUIFontSystem = 2;
  static const _noOptions = 0;

  final _Ref Function(int, double, _Ref) _uiFont;
  final _Ref Function(_Ref, int) _tables;
  final _Ref Function(_Ref, int, int) _table;
  final int Function(_Ref) _count;
  final _Ref Function(_Ref, int) _at;
  final int Function(_Ref) _length;
  final Pointer<Uint8> Function(_Ref) _data;
  final void Function(_Ref) _release;

  Map<int, Uint8List>? systemFontTables() {
    final font = _uiFont(_kCTFontUIFontSystem, 0, nullptr);
    if (font == nullptr) return null;
    try {
      final tags = _tables(font, _noOptions);
      if (tags == nullptr) return null;
      final tables = <int, Uint8List>{};
      try {
        for (var i = 0, n = _count(tags); i < n; i++) {
          // The array holds the tags themselves, unboxed.
          final tag = _at(tags, i).address & 0xffffffff;
          final data = _table(font, tag, _noOptions);
          if (data == nullptr) continue;
          try {
            tables[tag] = Uint8List.fromList(
              _data(data).asTypedList(_length(data)),
            );
          } finally {
            _release(data);
          }
        }
      } finally {
        _release(tags);
      }
      return tables;
    } finally {
      _release(font);
    }
  }
}
