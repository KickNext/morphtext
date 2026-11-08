import 'package:flutter/material.dart';
import 'package:morphtext/morphtext.dart';

import 'palette.dart';
import 'widgets.dart';

/// AnimatedMorph between text and icons: a send button whose label becomes
/// a tick, and one shape that morphs into whichever icon (or word) is picked.
class IconsCard extends StatefulWidget {
  const IconsCard({super.key});

  @override
  State<IconsCard> createState() => _IconsCardState();
}

const _label = TextStyle(
  fontFamily: 'RedHatDisplay',
  fontWeight: FontWeight.w900,
  fontSize: 20,
  color: Colors.white,
);

/// A button whose label morphs through a request: [idle], then [busy], then
/// [result] in [resultColor], then [after] (in [afterColor]).
class StatusButton extends StatefulWidget {
  const StatusButton({
    super.key,
    required this.idle,
    required this.busy,
    required this.result,
    required this.resultColor,
    required this.after,
    required this.afterColor,
  });

  final String idle;
  final String busy;
  final MorphContent result;
  final Color resultColor;
  final String after;
  final Color afterColor;

  @override
  State<StatusButton> createState() => _StatusButtonState();
}

class _StatusButtonState extends State<StatusButton> {
  late MorphContent _content = MorphContent.text(widget.idle, style: _label);
  var _color = Palette.blue;
  var _busy = false;

  Future<void> _press() async {
    if (_busy) return;
    _busy = true;
    setState(() {
      _content = MorphContent.text(widget.busy, style: _label);
      _color = Palette.blue;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    setState(() {
      _content = widget.result;
      _color = widget.resultColor;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    setState(() {
      _content = MorphContent.text(widget.after, style: _label);
      _color = widget.afterColor;
    });
    _busy = false;
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<Color?>(
    tween: ColorTween(end: _color),
    duration: const Duration(milliseconds: 250),
    builder: (context, color, child) => Material(
      color: color,
      borderRadius: BorderRadius.circular(28),
      child: child,
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: _press,
      child: SizedBox(
        width: 156,
        height: 56,
        child: Center(child: AnimatedMorph(_content)),
      ),
    ),
  );
}

/// Words and their icons. A pick flips the shape between text and icon, so
/// every transition is a word flowing into an icon or out of one.
const _pairs = <(String, IconData)>[
  ('Done', Icons.check_rounded),
  ('Close', Icons.close_rounded),
  ('Love', Icons.favorite),
  ('Star', Icons.star_rounded),
  ('Menu', Icons.menu_rounded),
  ('Search', Icons.search_rounded),
  ('Home', Icons.home_rounded),
  ('Play', Icons.play_arrow_rounded),
];

const _word = TextStyle(
  fontFamily: 'Fraunces',
  fontWeight: FontWeight.w600,
  fontSize: 60,
);

class _IconsCardState extends State<IconsCard> {
  var _shape = 0;

  /// Whether the shape shows the pick's icon (or its word).
  var _icon = true;

  MorphContent get _content {
    final (word, icon) = _pairs[_shape];
    return _icon
        ? MorphContent.icon(icon, semanticsLabel: word)
        : MorphContent.text(word, style: _word);
  }

  /// Picks [k] and flips between text and icon: from an icon to the pick's
  /// word, from a word to the pick's icon.
  void _pick(int k) => setState(() {
    _shape = k;
    _icon = !_icon;
  });

  @override
  Widget build(BuildContext context) => DemoCard(
    title: 'AnimatedMorph',
    note:
        'Text and icons morph into each other. Each pick flips between word '
        'and icon: tap one twice to see a word become its own icon.',
    children: [
      const SizedBox(height: 20),
      const Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          StatusButton(
            key: Key('send'),
            idle: 'Send',
            busy: 'Sending',
            result: MorphContent.icon(
              Icons.check_rounded,
              size: 30,
              color: Colors.white,
              semanticsLabel: 'Sent',
            ),
            resultColor: Palette.green,
            after: 'Send',
            afterColor: Palette.blue,
          ),
          StatusButton(
            key: Key('upload'),
            idle: 'Upload',
            busy: 'Uploading',
            result: MorphContent.icon(
              Icons.close_rounded,
              size: 30,
              color: Colors.white,
              semanticsLabel: 'Failed',
            ),
            resultColor: Palette.red,
            after: 'Retry',
            afterColor: Palette.red,
          ),
        ],
      ),
      const SizedBox(height: 28),
      SizedBox(
        height: 96,
        child: Center(
          child: IconTheme(
            data: const IconThemeData(size: 80, color: Palette.ink),
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: Palette.ink),
              child: AnimatedMorph(_content, key: const Key('shape')),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var k = 0; k < _pairs.length; k++)
            ActionChip(
              key: ValueKey('pair-${_pairs[k].$1}'),
              avatar: Icon(_pairs[k].$2, size: 18),
              label: Text(_pairs[k].$1),
              backgroundColor: k == _shape ? const Color(0xffe3ebfa) : null,
              onPressed: () => _pick(k),
            ),
        ],
      ),
    ],
  );
}
