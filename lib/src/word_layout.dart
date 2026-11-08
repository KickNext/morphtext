import 'package:flutter/widgets.dart';

/// One end of a morph laid out by Flutter: its size, its em in pixels, and
/// each letter's pen position on the baseline (kerning included).
class WordLayout {
  /// Lays out [text] in [style] on one line.
  WordLayout(this.text, this.style, this.scaler, this.direction)
    : em = scaler.scale(style.fontSize ?? _defaultFontSize) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    size = painter.size;
    baseline = painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    var offset = 0;
    for (final rune in text.runes) {
      final length = String.fromCharCode(rune).length;
      final boxes = painter.getBoxesForSelection(
        TextSelection(baseOffset: offset, extentOffset: offset + length),
      );
      pens.add(boxes.isEmpty ? null : Offset(boxes.first.left, baseline));
      offset += length;
    }
    painter.dispose();
  }

  /// [old] if it was laid out from the same inputs, else a new layout.
  static WordLayout reuse(
    WordLayout? old,
    String text,
    TextStyle style,
    TextScaler scaler,
    TextDirection direction,
  ) =>
      old != null &&
          old.text == text &&
          old.style == style &&
          old.scaler == scaler &&
          old.direction == direction
      ? old
      : WordLayout(text, style, scaler, direction);

  /// Flutter's own default, for a style that names no size.
  static const _defaultFontSize = 14.0;

  /// How far above the baseline, in ems, a letter missing from this layout
  /// grows from or shrinks to: about the middle of a lowercase letter.
  static const _gapHeight = .3;

  /// The text laid out.
  final String text;

  /// Its style, merged onto the ambient default.
  final TextStyle style;

  /// The text scaler it was laid out with.
  final TextScaler scaler;

  /// The direction it was laid out in.
  final TextDirection direction;

  /// The font size in logical pixels, after text scaling.
  final double em;

  /// The size of the laid-out line.
  late final Size size;

  /// The distance from the top of the line to its alphabetic baseline.
  late final double baseline;

  /// Each letter's pen position (by code point), or null for one the layout
  /// has no box for.
  final pens = <Offset?>[];

  /// Where a letter that isn't in this layout comes from or goes to: the
  /// pen of the letter at [index] (the end of the line past the last one),
  /// a little above the baseline.
  Offset gap(int index) {
    final x = index < pens.length
        ? (pens[index]?.dx ?? size.width)
        : size.width;
    return Offset(x, baseline - _gapHeight * em);
  }
}
