import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/language_toggle.dart';
import '../../core/widgets/offline_banner.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../chapters/chapters_repository.dart';
import '../doubts/outbox_sync.dart';
import '../quiz/quiz_repository.dart';
import 'classroom_repository.dart';

class StudentHome extends ConsumerStatefulWidget {
  const StudentHome({super.key});

  @override
  ConsumerState<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends ConsumerState<StudentHome> {
  var _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authControllerProvider).value;
    ref.watch(outboxSyncProvider); // start background sync for the session

    return Scaffold(
      appBar: AppBar(
        title: Text(
          user == null
              ? l10n.appName
              : 'Namaste, ${user.name.split(' ').first}',
        ),
        actions: [
          const LanguageToggle(),
          IconButton(
            tooltip: l10n.logout,
            onPressed: ref.read(authControllerProvider.notifier).logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: const [_LearnTab(), _QuizzesTab()],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book_rounded),
            label: l10n.learn,
          ),
          NavigationDestination(
            icon: const Icon(Icons.quiz_outlined),
            selectedIcon: const Icon(Icons.quiz_rounded),
            label: l10n.quizzes,
          ),
        ],
      ),
    );
  }
}

class _LearnTab extends ConsumerWidget {
  const _LearnTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final classrooms = ref.watch(myClassroomsProvider).value ?? const [];
    final chapters = ref.watch(chaptersProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref
          ..invalidate(myClassroomsProvider)
          ..invalidate(chaptersProvider);
        await ref.read(chaptersProvider.future);
      },
      child: AsyncView(
        value: chapters,
        onRetry: () => ref.invalidate(chaptersProvider),
        data: (list) {
          final ready = list.where((c) => c.isReady).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (classrooms.isEmpty) ...[
                const _JoinClassCard(),
                const SizedBox(height: 20),
              ] else
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final c in classrooms)
                        Chip(
                          avatar: const Icon(Icons.groups_rounded, size: 18),
                          label: Text(c.name),
                        ),
                    ],
                  ),
                ),
              Text(
                l10n.chapters,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final chapter in ready) ...[
                _ChapterCard(chapter: chapter),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({required this.chapter});

  final Chapter chapter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/student/chapter/${chapter.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: scheme.primaryContainer,
                child: Icon(Icons.science_outlined, color: scheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chapter.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${l10n.classLabel(chapter.grade)} · ${chapter.subject} · '
                      '${chapter.concepts.length} topics',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _JoinClassCard extends ConsumerStatefulWidget {
  const _JoinClassCard();

  @override
  ConsumerState<_JoinClassCard> createState() => _JoinClassCardState();
}

class _JoinClassCardState extends ConsumerState<_JoinClassCard> {
  final _code = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final room = await ref
          .read(classroomRepositoryProvider)
          .join(_code.text.trim());
      ref.invalidate(myClassroomsProvider);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.joinedClass(room.name))),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.joinClass,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(hintText: l10n.joinCodeHint),
                    onSubmitted: (_) => _join(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy ? null : _join,
                  child: Text(l10n.join),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizzesTab extends ConsumerWidget {
  const _QuizzesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final quizzes = ref.watch(studentQuizzesProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(studentQuizzesProvider.future),
      child: AsyncView(
        value: quizzes,
        onRetry: () => ref.invalidate(studentQuizzesProvider),
        data: (list) => list.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 120),
                  const Icon(Icons.quiz_outlined, size: 48),
                  const SizedBox(height: 12),
                  Text(l10n.noQuizzes, textAlign: TextAlign.center),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final quiz = list[i];
                  final done = quiz.myScore != null;
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: Icon(
                        done
                            ? Icons.check_circle_rounded
                            : Icons.pending_actions_rounded,
                        color: done
                            ? Colors.green
                            : Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(quiz.title),
                      subtitle: Text(
                        l10n.questionsCount(quiz.questions.length),
                      ),
                      trailing: done
                          ? Text(
                              l10n.score(quiz.myScore!, quiz.questions.length),
                            )
                          : FilledButton.tonal(
                              onPressed: () =>
                                  context.push('/student/quiz/${quiz.id}'),
                              child: Text(l10n.start),
                            ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
