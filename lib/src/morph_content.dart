import 'package:flutter/widgets.dart';

/// What a morph shows at one end: a line of text in a style, or an icon.
///
/// Text is read from the bundled font that [style] names, an icon from its
/// icon font (Material Icons, Cupertino Icons, or any icon font the app
/// bundles), so text and icons morph into each other freely: a word flows
/// into an icon, an icon into another icon, a word into another word.
///
/// Release builds keep only the icons the app's code references
/// (`--tree-shake-icons`), as for [Icon]: name each icon as a constant, such
/// as `Icons.check`.
@immutable
final class MorphContent {
  /// [text] on one line, in [style] (merged onto the ambient
  /// [DefaultTextStyle], as a [Text] merges its style).
  const MorphContent.text(String this.text, {this.style, this.semanticsLabel})
    : icon = null,
      size = null,
      color = null;

  /// [icon] at [size] in [color], drawn as [Icon] draws it; both default to
  /// the ambient [IconTheme].
  ///
  /// An icon announces nothing unless given a [semanticsLabel], as [Icon].
  const MorphContent.icon(
    IconData this.icon, {
    this.size,
    this.color,
    this.semanticsLabel,
  }) : text = null,
       style = null;

  /// The text, for [MorphContent.text].
  final String? text;

  /// The text's style, for [MorphContent.text].
  final TextStyle? style;

  /// The icon, for [MorphContent.icon].
  final IconData? icon;

  /// The icon's size; the ambient [IconTheme]'s when null.
  final double? size;

  /// The icon's colour; the ambient [IconTheme]'s when null.
  final Color? color;

  /// The label announced at this end: [text] when null for text, nothing
  /// when null for an icon.
  final String? semanticsLabel;

  @override
  bool operator ==(Object other) =>
      other is MorphContent &&
      other.text == text &&
      other.style == style &&
      other.icon == icon &&
      other.size == size &&
      other.color == color &&
      other.semanticsLabel == semanticsLabel;

  @override
  int get hashCode =>
      Object.hash(text, style, icon, size, color, semanticsLabel);

  @override
  String toString() =>
      icon != null ? 'MorphContent.icon($icon)' : 'MorphContent.text("$text")';
}
