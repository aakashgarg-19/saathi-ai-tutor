import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/widgets/async_view.dart';
import '../../l10n/app_localizations.dart';
import 'quiz_repository.dart';

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key, required this.quizId});

  final int quizId;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  final _answers = <int, int>{};
  var _index = 0;
  var _submitting = false;
  AttemptResult? _result;

  Future<void> _submit(Quiz quiz) async {
    setState(() => _submitting = true);
    try {
      final result = await ref.read(quizRepositoryProvider).attempt(quiz.id, [
        for (var i = 0; i < quiz.questions.length; i++) _answers[i]!,
      ]);
      ref.invalidate(studentQuizzesProvider);
      setState(() => _result = result);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quiz = ref.watch(quizProvider(widget.quizId));
    return Scaffold(
      appBar: AppBar(title: Text(quiz.value?.title ?? '')),
      body: AsyncView(
        value: quiz,
        onRetry: () => ref.invalidate(quizProvider(widget.quizId)),
        data: (quiz) => _result != null
            ? _ResultView(result: _result!)
            : _questionView(quiz),
      ),
    );
  }

  Widget _questionView(Quiz quiz) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final q = quiz.questions[_index];
    final isLast = _index == quiz.questions.length - 1;
    final selected = _answers[_index];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: (_index + 1) / quiz.questions.length,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              '${_index + 1} / ${quiz.questions.length} · ${q.concept}',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 16),
            Text(q.question, style: theme.textTheme.titleLarge),
            const SizedBox(height: 20),
            Expanded(
              child: RadioGroup<int>(
                groupValue: selected,
                onChanged: (v) => setState(() => _answers[_index] = v!),
                child: ListView(
                  children: [
                    for (var i = 0; i < q.options.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          color: selected == i
                              ? theme.colorScheme.primaryContainer
                              : null,
                          child: RadioListTile<int>(
                            value: i,
                            title: Text(q.options[i]),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            FilledButton(
              onPressed: selected == null || _submitting
                  ? null
                  : () => isLast ? _submit(quiz) : setState(() => _index++),
              child: Text(isLast ? l10n.submit : l10n.next),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result});

  final AttemptResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(l10n.yourResult, style: theme.textTheme.titleMedium),
        Text(
          l10n.score(result.score, result.total),
          style: theme.textTheme.displaySmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < result.review.length; i++) ...[
          _ReviewCard(
            question: result.review[i],
            chosen: result.yourAnswers[i],
          ),
          const SizedBox(height: 12),
        ],
        FilledButton(onPressed: () => context.pop(), child: Text(l10n.done)),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.question, required this.chosen});

  final QuizQuestion question;
  final int chosen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final correct = question.answerIndex == chosen;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: correct ? Colors.green : theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    question.question,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!correct)
              Text(
                '✗ ${question.options[chosen]}',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            Text(
              '✓ ${question.options[question.answerIndex!]}',
              style: const TextStyle(color: Colors.green),
            ),
            if (question.explanation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(question.explanation, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
