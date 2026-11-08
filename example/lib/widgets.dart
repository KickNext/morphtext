import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/link.dart';

import 'palette.dart';

const _install = 'flutter pub add morphtext';

const _pubDev = 'https://pub.dev/packages/morphtext';

const _gitHub = 'https://github.com/drei-gg/morphtext';

class PageHeader extends StatelessWidget {
  const PageHeader({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Expanded(
            child: Text(
              'morphtext',
              style: TextStyle(
                fontFamily: 'Fraunces',
                fontWeight: FontWeight.w600,
                fontSize: 40,
                height: 1,
                color: Palette.ink,
              ),
            ),
          ),
          LinkText('pub.dev', _pubDev),
          const SizedBox(width: 16),
          LinkText('GitHub', _gitHub),
        ],
      ),
      const SizedBox(height: 12),
      const Text(
        'Text that morphs letter by letter, outline into outline, in Flutter. '
        'Weight, size, colour, one font into another, one word into another, '
        'and words into icons.',
        style: TextStyle(color: Palette.muted, fontSize: 16, height: 1.4),
      ),
      const SizedBox(height: 16),
      const InstallLine(),
    ],
  );
}

class InstallLine extends StatefulWidget {
  const InstallLine({super.key});

  @override
  State<InstallLine> createState() => _InstallLineState();
}

class _InstallLineState extends State<InstallLine> {
  var _copied = false;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Material(
      color: Palette.ink,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          await Clipboard.setData(const ClipboardData(text: _install));
          if (!mounted) return;
          setState(() => _copied = true);
          await Future<void>.delayed(const Duration(seconds: 2));
          if (mounted) setState(() => _copied = false);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Flexible(
                child: Text(
                  _install,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                _copied ? Icons.check : Icons.copy,
                size: 16,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class LinkText extends StatelessWidget {
  const LinkText(this.label, this.url, {super.key});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) => Link(
    uri: Uri.parse(url),
    target: LinkTarget.blank,
    builder: (context, follow) => InkWell(
      onTap: follow,
      child: Text(
        label,
        style: const TextStyle(
          color: Palette.blue,
          fontSize: 15,
          decoration: TextDecoration.underline,
          decorationColor: Palette.blue,
        ),
      ),
    ),
  );
}

class DemoCard extends StatelessWidget {
  const DemoCard({
    super.key,
    required this.title,
    required this.note,
    required this.children,
  });

  final String title;
  final String note;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Palette.card,
      border: Border.all(color: Palette.line),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: Palette.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: const TextStyle(color: Palette.muted, fontSize: 13),
          ),
          ...children,
        ],
      ),
    ),
  );
}

class Swatch extends StatelessWidget {
  const Swatch({
    super.key,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: 'colour',
    child: InkResponse(
      onTap: onTap,
      radius: 20,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Palette.paper : color,
              width: 3,
            ),
            boxShadow: [if (selected) BoxShadow(color: color, spreadRadius: 2)],
          ),
        ),
      ),
    ),
  );
}

class WordField extends StatelessWidget {
  const WordField({
    super.key,
    required this.label,
    required this.initial,
    required this.onChanged,
  });

  final String label;
  final String initial;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: initial,
    maxLength: 16,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
      counterText: '',
    ),
    onChanged: onChanged,
  );
}

/// One line of the code a setting stands for.
class CodeLine extends StatelessWidget {
  const CodeLine(this.code, {super.key});

  final String code;

  @override
  Widget build(BuildContext context) => Text(
    code,
    style: const TextStyle(
      fontFamily: 'monospace',
      fontSize: 12,
      color: Palette.muted,
    ),
  );
}

class PageFooter extends StatelessWidget {
  const PageFooter({super.key});

  @override
  Widget build(BuildContext context) => const Text(
    'MIT. Built on morphnext by KickNext. '
    'Fonts: Fraunces and Red Hat Display (SIL OFL 1.1). '
    'Fraunces here is a Latin-1 subset. A drei.gg project.',
    textAlign: TextAlign.center,
    style: TextStyle(color: Palette.muted, fontSize: 12, height: 1.5),
  );
}
