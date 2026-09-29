import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Renders an LLM answer: `**bold**` key terms and tappable `[S1]` citations.
/// Tiny on purpose: the model is told to emit only these two constructs.
class AnswerText extends StatefulWidget {
  const AnswerText(this.text, {super.key, this.onCitationTap, this.style});

  final String text;
  final void Function(String ref)? onCitationTap;
  final TextStyle? style;

  @override
  State<AnswerText> createState() => _AnswerTextState();
}

class _AnswerTextState extends State<AnswerText> {
  static final _token = RegExp(r'\*\*(.+?)\*\*|\[(S\d+)\]');
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final scheme = Theme.of(context).colorScheme;
    final base = widget.style ?? Theme.of(context).textTheme.bodyLarge;
    final spans = <InlineSpan>[];
    var last = 0;

    for (final m in _token.allMatches(widget.text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: widget.text.substring(last, m.start)));
      }
      if (m.group(1) != null) {
        spans.add(
          TextSpan(
            text: m.group(1),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      } else {
        final ref = m.group(2)!;
        final recognizer = TapGestureRecognizer()
          ..onTap = () => widget.onCitationTap?.call(ref);
        _recognizers.add(recognizer);
        spans.add(
          TextSpan(
            text: ' ${ref.substring(1)} ',
            recognizer: recognizer,
            style: TextStyle(
              fontSize: (base?.fontSize ?? 16) * 0.75,
              fontWeight: FontWeight.w700,
              color: scheme.onPrimaryContainer,
              backgroundColor: scheme.primaryContainer,
            ),
          ),
        );
      }
      last = m.end;
    }
    if (last < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(last)));
    }
    return SelectableText.rich(TextSpan(style: base, children: spans));
  }
}
