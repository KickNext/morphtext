// ignore_for_file: implementation_imports
//
// The seam to morphnext (KickNext, MIT, github.com/KickNext/morphnext): the
// only file in morphtext that touches its outline engine. It rests on
// morphnext 0.6.1's internals (src/font, src/geometry), not its public
// widgets, which is why pubspec.yaml pins that version exactly.
//
// The surface below is the small public API proposed upstream
// (upstream/ISSUE.md): read a glyph's outline from font bytes by code point,
// and plan a morph between two outlines. Once morphnext ships it, this file
// becomes upstream/engine_public_api.dart and the pin becomes a range.

import 'dart:typed_data';

import 'package:morphnext/src/font/open_type_font.dart';
import 'package:morphnext/src/geometry/morph_plan.dart';
import 'package:morphnext/src/geometry/resample.dart';
import 'package:morphnext/src/geometry/shape.dart';

/// A font file, parsed once (TrueType `glyf` or CFF outlines).
final class GlyphFont {
  /// Parses [bytes] of an OpenType font file.
  GlyphFont.parse(Uint8List bytes)
    : this._(OpenTypeFont.parse(bytes), defaultFontVariationSelection);

  GlyphFont._(this._font, this._variation);

  final OpenTypeFont _font;
  final FontVariationSelection _variation;

  /// The design axes of a variable font, by tag (`wght`, `opsz`, ...);
  /// empty for a static one.
  Set<String> get axes => _font.variationAxes.keys.toSet();

  /// The same font at [weight] and [opticalSize] on its `wght` and `opsz`
  /// axes, each clamped to the axis and ignored where the font has no such
  /// axis. Null leaves an axis at its default. Shares the parsed file.
  GlyphFont varied({double? weight, double? opticalSize}) => GlyphFont._(
    _font,
    (fill: null, weight: weight, grade: null, opticalSize: opticalSize),
  );

  /// The outline of [codePoint], or null when the font lacks it or it has no
  /// contours (a space).
  GlyphShape? shape(int codePoint) {
    final outline = this.outline(codePoint);
    if (outline == null) return null;
    return GlyphShape._(_sample(outline._contours), outline.ascender);
  }

  /// The unsampled outline of [codePoint], to place with others in one
  /// shape ([GlyphShape.placed]), or null as for [shape].
  GlyphOutline? outline(int codePoint) {
    if (!_font.containsCodePoint(codePoint)) return null;
    final outline = _font.glyphForCodePoint(codePoint, _variation);
    final upm = outline.metrics.unitsPerEm.toDouble();
    final asc = outline.metrics.ascender.toDouble();
    if (upm <= 0 || outline.contours.isEmpty) return null;
    // Normalised to the em: x from the pen, y down from the ascender.
    return GlyphOutline._([
      for (final c in outline.contours)
        CubicContour(
          Float64List.fromList([
            for (var k = 0; k < c.points.length; k += 2) ...[
              c.points[k] / upm,
              (asc - c.points[k + 1]) / upm,
            ],
          ]),
        ),
    ], asc / upm);
  }

  static MorphShape _sample(List<CubicContour> contours) =>
      sampleContoursWithPointCounts(
        contours,
        pointCounts: [for (final c in contours) _pointsFor(c)],
        fillRule: MorphFillRule.nonZero,
      );

  /// As morphnext samples an icon glyph: 16 points a curve, from 64 up to
  /// 2048 in powers of two.
  static int _pointsFor(CubicContour c) {
    var n = 64;
    while (n < c.segmentCount * 16 && n < 2048) {
      n *= 2;
    }
    return n;
  }
}

/// A glyph's outline as the font draws it, in ems (x from the pen position,
/// y down from the font's ascender), not yet sampled for morphing.
final class GlyphOutline {
  GlyphOutline._(this._contours, this.ascender);

  final List<CubicContour> _contours;

  /// The font's ascender, in ems.
  final double ascender;
}

/// One glyph's outline in ems: x along the em from the pen position, y down
/// from the font's ascender. Or, from [GlyphShape.placed], several outlines
/// as one shape.
final class GlyphShape {
  GlyphShape._(this._shape, this.ascender);

  /// Several outlines as one shape, each scaled by its `scale` and moved to
  /// (`x`, `y`): a word's letters where its layout puts them, so the whole
  /// word morphs as one outline. Null when there's nothing to draw.
  /// [ascender] is 0: the shape is placed already.
  static GlyphShape? placed(
    Iterable<({GlyphOutline outline, double x, double y, double scale})> parts,
  ) {
    final contours = [
      for (final p in parts)
        for (final c in p.outline._contours)
          CubicContour(
            Float64List.fromList([
              for (var k = 0; k < c.points.length; k += 2) ...[
                p.x + c.points[k] * p.scale,
                p.y + c.points[k + 1] * p.scale,
              ],
            ]),
          ),
    ];
    if (contours.isEmpty) return null;
    return GlyphShape._(GlyphFont._sample(contours), 0);
  }

  final MorphShape _shape;

  /// The font's ascender, in ems.
  final double ascender;

  /// How many closed contours the outline has (o has two, i two, B three).
  int get contourCount => _shape.contours.length;
}

/// The morph from one glyph outline to another.
final class GlyphMorph {
  /// Pairs [from]'s contours with [to]'s (morphnext's topology-aware plan).
  GlyphMorph(GlyphShape from, GlyphShape to)
    : _plan = buildMorphPlan(from._shape, to._shape),
      fromAscender = from.ascender,
      toAscender = to.ascender {
    _out = _plan.allocateOutput();
  }

  final MorphPlan _plan;
  late final List<Float64List> _out;

  /// The `from` font's ascender, in ems.
  final double fromAscender;

  /// The `to` font's ascender, in ems.
  final double toAscender;

  /// The outline at [t] (0 is `from`, 1 is `to`): one closed polygon per
  /// contour pair, as interleaved x, y in ems. The buffers are reused by the
  /// next call; copy them to keep them.
  List<Float64List> at(double t) {
    _plan.interpolate(t, _out);
    return _out;
  }

  /// Whether every contour of each outline paired with exactly one of the
  /// other: nothing grew from or shrank to a point.
  bool get isOneToOne =>
      _plan.items.every((i) => !i.sourceCollapsed && !i.targetCollapsed);

  /// How many contour pairs the morph draws.
  int get pairCount => _plan.items.length;
}
