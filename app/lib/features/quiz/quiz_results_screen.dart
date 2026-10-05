import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/async_view.dart';
import '../../l10n/app_localizations.dart';
import 'quiz_repository.dart';

class QuizResultsScreen extends ConsumerWidget {
  const QuizResultsScreen({super.key, required this.quizId});

  final int quizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final quiz = ref.watch(quizProvider(quizId));
    final results = ref.watch(quizResultsProvider(quizId));

    return Scaffold(
      appBar: AppBar(title: Text(quiz.value?.title ?? l10n.results)),
      body: AsyncView(
        value: results,
        onRetry: () => ref.invalidate(quizResultsProvider(quizId)),
        data: (r) {
          final questions = quiz.value?.questions ?? const <QuizQuestion>[];
          final attempts = r.attempts.length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.perQuestion,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < r.perQuestionCorrect.length; i++) ...[
                        Text(
                          'Q${i + 1}. ${i < questions.length ? questions[i].question : ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(
                                value: attempts == 0
                                    ? 0
                                    : r.perQuestionCorrect[i] / attempts,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text('${r.perQuestionCorrect[i]}/$attempts'),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        l10n.attempts(attempts),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    for (final a in r.attempts)
                      ListTile(
                        leading: CircleAvatar(child: Text(a.name[0])),
                        title: Text(a.name),
                        trailing: Text(
                          '${a.score}/${a.total}',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
