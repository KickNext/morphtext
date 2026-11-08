import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'engine.dart';
import 'word_layout.dart';

/// One letter of the start ([from], [fromRune]) becoming one of the end
/// ([to], [toRune]). Either may be missing, for a letter that shrinks away or
/// grows in. [morph] is null for a letter with no outline (a space) or one
/// that couldn't be read.
class LetterPair {
  /// Pairs the letter at [from] in the start with the letter at [to] in the
  /// end.
  const LetterPair({
    required this.from,
    required this.to,
    required this.fromRune,
    required this.toRune,
    required this.morph,
  });

  /// The letter's index in the start, by code point.
  final int? from;

  /// The letter's index in the end, by code point.
  final int? to;

  /// The start's letter.
  final int? fromRune;

  /// The end's letter.
  final int? toRune;

  /// The morph between their outlines.
  final GlyphMorph? morph;
}

/// Paints a morph between two [WordLayout]s at [t].
///
/// At either end (unless [moving]), and until [pairs] are read, it paints
/// the nearer end as plain text, exactly as a `Text` would. In between it
/// paints each letter's outline, morphed to [t], in its em square carried
/// from its place in one layout to its place in the other.
class MorphPainter extends CustomPainter {
  /// Paints [a] becoming [b] at [t].
  MorphPainter({
    required this.a,
    required this.b,
    required this.pairs,
    required this.t,
    required this.moving,
    required this.handoff,
    required this.color,
  });

  /// The width of the band shaved off an outline's edges on the web, in
  /// device pixels; see [_fill].
  static const _webEdgeBand = .14;

  /// The start.
  final WordLayout a;

  /// The end.
  final WordLayout b;

  /// Which letter becomes which, once the outlines are read.
  final List<LetterPair>? pairs;

  /// How far from [a] to [b].
  final double t;

  /// Whether a spring is driving the morph: outlines even at (or past) an
  /// end, which it may overshoot.
  final bool moving;

  /// Near the end: how far [b]'s plain text has faded in over the outlines,
  /// 0..1. Null otherwise.
  final double? handoff;

  /// The colour at [t].
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final pairs = this.pairs;
    if (pairs == null || (!moving && (t <= 0 || t >= 1))) {
      _text(canvas, size);
      return;
    }
    final handoff = this.handoff;
    if (handoff == null) {
      _outlines(canvas, size, pairs);
      return;
    }
    // A cross-dissolve to the end's text, added rather than layered so the
    // insides of the letters stay fully opaque and only the edges, where an
    // outline and hinted text rasterise differently, blend.
    canvas
      ..saveLayer(null, Paint())
      ..saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, 1 - handoff));
    _outlines(canvas, size, pairs);
    canvas
      ..restore()
      ..saveLayer(
        null,
        Paint()
          ..color = Color.fromRGBO(0, 0, 0, handoff)
          ..blendMode = BlendMode.plus,
      );
    _text(canvas, size, end: true);
    canvas
      ..restore()
      ..restore();
  }

  @override
  bool shouldRepaint(MorphPainter old) =>
      old.t != t ||
      old.moving != moving ||
      old.handoff != handoff ||
      old.pairs != pairs ||
      old.color != color ||
      old.a != a ||
      old.b != b;

  /// The nearer end (or with [end], [b]) as plain text, centred in the box.
  void _text(Canvas canvas, Size size, {bool end = false}) {
    final layout = end || t >= .5 ? b : a;
    final painter = TextPainter(
      text: TextSpan(
        text: layout.text,
        style: layout.style.copyWith(color: color),
      ),
      textDirection: layout.direction,
      textScaler: layout.scaler,
      maxLines: 1,
    )..layout();
    painter
      ..paint(canvas, _centred(size, painter.size))
      ..dispose();
  }

  /// Each letter's outline, morphed to [t], in its em square carried between
  /// the two layouts (each centred in the box as it grows or shrinks), on
  /// the baseline each end's text is actually drawn on.
  void _outlines(Canvas canvas, Size size, List<LetterPair> pairs) {
    final transform = canvas.getTransform();
    var offsetA = _centred(size, a.size);
    var offsetB = _centred(size, b.size);
    offsetA = offsetA.translate(0, _snap(transform, offsetA.dy + a.baseline));
    offsetB = offsetB.translate(0, _snap(transform, offsetB.dy + b.baseline));
    final path = Path()..fillType = PathFillType.nonZero;
    for (var k = 0; k < pairs.length; k++) {
      final pair = pairs[k];
      final from = pair.from, to = pair.to;
      Offset? penA, penB;
      if (from != null) {
        final pen = a.pens[from];
        if (pen == null) continue;
        penA = pen + offsetA;
      }
      if (to != null) {
        final pen = b.pens[to];
        if (pen == null) continue;
        penB = pen + offsetB;
      }
      final morph = pair.morph;
      if (morph == null) {
        final fromPen =
            penA ??
            Offset(_next(pairs, k, a, start: true).dx, a.baseline) + offsetA;
        final toPen =
            penB ??
            Offset(_next(pairs, k, b, start: false).dx, b.baseline) + offsetB;
        _letterAsText(canvas, pair, Offset.lerp(fromPen, toPen, t)!);
        continue;
      }
      // Each end's em square, or a point where the letter is absent: the
      // place of the next letter that is there.
      final squareA = penA != null
          ? _square(penA, a.em, morph.fromAscender)
          : Rect.fromCenter(
              center: _next(pairs, k, a, start: true) + offsetA,
              width: 0,
              height: 0,
            );
      final squareB = penB != null
          ? _square(penB, b.em, morph.toAscender)
          : Rect.fromCenter(
              center: _next(pairs, k, b, start: false) + offsetB,
              width: 0,
              height: 0,
            );
      // A letter alone is gone by halfway, or grows in from there, so it
      // never lingers as small text beside the others.
      final along = from == null
          ? ((t - .5) * 2).clamp(0.0, 1.0)
          : to == null
          ? (t * 2).clamp(0.0, 1.0)
          : t;
      final square = Rect.lerp(squareA, squareB, along)!;
      for (final points in morph.at(t)) {
        _addContour(path, points, square);
      }
    }
    _fill(canvas, path, transform);
  }

  /// Fills [path] in [color].
  ///
  /// On the web, Skia draws text with a contrast boost that thins its edges,
  /// and fills paths without one, so an outline carries 2–7% more ink than
  /// the same text and visibly lightens as it hands over. Shaving
  /// [_webEdgeBand] off the outline's edges matches the text's weight
  /// (measured on CanvasKit: Fraunces Light and SemiBold and Red Hat Display
  /// Black, 72 px). The native renderers draw the two alike.
  void _fill(Canvas canvas, Path path, Float64List transform) {
    final scale = transform[0].abs();
    if (!kIsWeb || scale == 0) {
      canvas.drawPath(path, Paint()..color = color);
      return;
    }
    canvas
      ..saveLayer(null, Paint())
      ..drawPath(path, Paint()..color = color)
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * _webEdgeBand / scale
          ..blendMode = BlendMode.dstOut
          ..color = const Color(0xff000000),
      )
      ..restore();
  }

  /// A letter with no outline to morph, drawn as text at [pen]: the nearer
  /// end's letter, in the style between the two. Spaces draw nothing.
  void _letterAsText(Canvas canvas, LetterPair pair, Offset pen) {
    final rune = t < .5 ? pair.fromRune : pair.toRune;
    if (rune == null) return;
    final letter = String.fromCharCode(rune);
    if (letter.trim().isEmpty) return;
    final style = TextStyle.lerp(a.style, b.style, t)!.copyWith(color: color);
    final painter = TextPainter(
      text: TextSpan(text: letter, style: style),
      textDirection: a.direction,
      textScaler: a.scaler,
      maxLines: 1,
    )..layout();
    final baseline = painter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    painter
      ..paint(canvas, pen - Offset(0, baseline))
      ..dispose();
  }

  /// Where something of [inner] size sits centred in [outer].
  static Offset _centred(Size outer, Size inner) => Offset(
    (outer.width - inner.width) / 2,
    (outer.height - inner.height) / 2,
  );

  /// How far to move a baseline at [y] (logical, in this canvas) to land on
  /// a whole device pixel, as Skia places unrotated text: it rounds each
  /// run's baseline to the pixel. Outlines drawn on the exact baseline would
  /// sit up to half a pixel off the text they hand over to. Nothing for a
  /// rotated or skewed canvas, where text isn't snapped either.
  static double _snap(Float64List transform, double y) {
    final scale = transform[5], ty = transform[13];
    if (transform[1] != 0 || transform[4] != 0 || scale <= 0) return 0;
    final device = y * scale + ty;
    return ((device + .5).floorToDouble() - device) / scale;
  }

  /// Where, in [layout], the letter of pair [k] would be if it were there:
  /// the place of the next letter that is, or the end of the line.
  static Offset _next(
    List<LetterPair> pairs,
    int k,
    WordLayout layout, {
    required bool start,
  }) {
    for (var n = k + 1; n < pairs.length; n++) {
      final index = start ? pairs[n].from : pairs[n].to;
      if (index != null) return layout.gap(index);
    }
    return layout.gap(layout.pens.length);
  }

  /// A letter's em square in one layout: from its pen position, its top an
  /// ascender above the baseline, as the outline was normalised.
  static Rect _square(Offset pen, double em, double ascender) =>
      Rect.fromLTWH(pen.dx, pen.dy - ascender * em, em, em);

  /// Adds one contour, a closed polygon in ems, to [path] in [square].
  static void _addContour(Path path, Float64List points, Rect square) {
    if (points.length < 4) return;
    path.moveTo(
      square.left + points[0] * square.width,
      square.top + points[1] * square.height,
    );
    for (var k = 2; k < points.length; k += 2) {
      path.lineTo(
        square.left + points[k] * square.width,
        square.top + points[k + 1] * square.height,
      );
    }
    path.close();
  }
}
