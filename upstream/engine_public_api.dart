// Option (a): lib/src/engine.dart once morphnext exposes MorphFont,
// MorphGlyph and MorphGlyphPlan (upstream/0001-public-glyph-api.patch).
// Drop this in place of lib/src/engine.dart and loosen the pin to the
// morphnext release that ships them (e.g. `morphnext: ^0.7.0`).
//
// Same surface morph_text.dart uses today, so nothing else changes.

import 'dart:typed_data';

import 'package:morphnext/morphnext.dart';

/// A font file, parsed once (TrueType `glyf` or CFF outlines).
final class GlyphFont {
  /// Parses [bytes] of an OpenType font file.
  GlyphFont.parse(Uint8List bytes) : _font = MorphFont.parse(bytes);

  final MorphFont _font;

  /// The outline of [codePoint], or null when the font lacks it or it has no
  /// contours (a space).
  GlyphShape? shape(int codePoint) {
    final glyph = _font.glyph(codePoint);
    return glyph == null ? null : GlyphShape._(glyph);
  }
}

/// One glyph's outline in ems: x along the em from the pen position, y down
/// from the font's ascender.
final class GlyphShape {
  GlyphShape._(this._glyph);

  final MorphGlyph _glyph;

  /// The font's ascender, in ems.
  double get ascender => _glyph.ascender;

  /// How many closed contours the outline has.
  int get contourCount => _glyph.contourCount;
}

/// The morph from one glyph outline to another.
final class GlyphMorph {
  /// Pairs [from]'s contours with [to]'s (morphnext's topology-aware plan).
  GlyphMorph(GlyphShape from, GlyphShape to)
    : _plan = MorphGlyphPlan(from._glyph, to._glyph),
      fromAscender = from.ascender,
      toAscender = to.ascender {
    _out = _plan.allocateOutput();
  }

  final MorphGlyphPlan _plan;
  late final List<Float64List> _out;

  /// The `from` font's ascender, in ems.
  final double fromAscender;

  /// The `to` font's ascender, in ems.
  final double toAscender;

  /// The outline at [t]; the buffers are reused by the next call.
  List<Float64List> at(double t) {
    _plan.interpolate(t, _out);
    return _out;
  }

  /// Whether every contour of each outline paired with exactly one of the
  /// other.
  bool get isOneToOne => _plan.isOneToOne;

  /// How many contour pairs the morph draws.
  int get pairCount => _plan.contourCount;
}
