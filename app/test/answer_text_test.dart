import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saathi/core/widgets/answer_text.dart';

void main() {
  testWidgets('renders bold terms and makes citations tappable', (
    tester,
  ) async {
    String? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnswerText(
            '**Stomata** are tiny pores [S1] on leaves [S2].',
            onCitationTap: (ref) => tapped = ref,
          ),
        ),
      ),
    );

    final rich = tester.widget<SelectableText>(find.byType(SelectableText));
    final spans = (rich.textSpan!.children!).cast<TextSpan>();

    expect(spans.first.text, 'Stomata');
    expect(spans.first.style?.fontWeight, FontWeight.w700);
    expect(
      rich.textSpan!.toPlainText(),
      'Stomata are tiny pores  1  on leaves  2 .',
    );

    final citation = spans.firstWhere((s) => s.text == ' 2 ');
    (citation.recognizer! as TapGestureRecognizer).onTap!();
    expect(tapped, 'S2');
  });
}
