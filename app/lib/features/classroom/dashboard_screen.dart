import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../l10n/app_localizations.dart';
import '../quiz/create_quiz_sheet.dart';
import '../quiz/quiz_repository.dart';
import 'classroom_repository.dart';
import 'live_feed.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key, required this.classroomId});

  final int classroomId;

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Live events arrive in bursts; refetch aggregates at most once per second.
  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), () {
      ref.invalidate(insightsProvider(widget.classroomId));
      ref.invalidate(classroomQuizzesProvider(widget.classroomId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final id = widget.classroomId;
    final insights = ref.watch(insightsProvider(id));
    final classroom = ref
        .watch(myClassroomsProvider)
        .value
        ?.where((c) => c.id == id)
        .firstOrNull;

    ref.listen(
      liveFeedProvider(id).select((s) => s.events.length),
      (_, _) => _scheduleRefresh(),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(classroom?.name ?? l10n.dashboard),
        actions: [
          if (classroom != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                label: Text('${l10n.joinCode}: ${classroom.joinCode}'),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCreateQuizSheet(
          context,
          classroomId: id,
          suggestedConcepts: [
            for (final c in insights.value?.concepts ?? const <ConceptStat>[])
              c.concept,
          ].take(3).toList(),
        ),
        icon: const Icon(Icons.auto_awesome_rounded),
        label: Text(l10n.createQuiz),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(insightsProvider(id).future),
        child: AsyncView(
          value: insights,
          onRetry: () => ref.invalidate(insightsProvider(id)),
          data: (data) => LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 960;
              final main = [
                _StatsRow(insights: data),
                const SizedBox(height: 16),
                _ConceptsCard(insights: data),
                const SizedBox(height: 16),
                _QuizzesCard(classroomId: id),
              ];
              final feed = _LiveFeedCard(classroomId: id, insights: data);
              if (!wide) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [...main, const SizedBox(height: 16), feed],
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: Column(children: main)),
                    const SizedBox(width: 24),
                    Expanded(flex: 2, child: feed),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.insights});

  final Insights insights;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rate = insights.helpfulRate;
    return Row(
      children: [
        _StatTile(
          icon: Icons.question_answer_rounded,
          label: l10n.doubtsThisWeek,
          value: '${insights.totalDoubts}',
        ),
        const SizedBox(width: 12),
        _StatTile(
          icon: Icons.groups_rounded,
          label: l10n.activeStudents,
          value: '${insights.activeStudents}/${insights.totalStudents}',
        ),
        const SizedBox(width: 12),
        _StatTile(
          icon: Icons.thumb_up_rounded,
          label: l10n.helpfulRate,
          value: rate == null ? '–' : '${(rate * 100).round()}%',
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                value,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(label, style: theme.textTheme.bodySmall, maxLines: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConceptsCard extends StatelessWidget {
  const _ConceptsCard({required this.insights});

  final Insights insights;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final concepts = insights.concepts;
    final max = concepts.isEmpty ? 1 : concepts.first.count;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.confusingConcepts, style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            if (concepts.isEmpty) Text(l10n.noDoubtsYet),
            for (final c in concepts) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.concept, style: theme.textTheme.bodyLarge),
                        Text(c.chapterTitle, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Text('${c.count}', style: theme.textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 6),
              _ConceptBar(
                fraction: c.count / max,
                unhelpful: c.unhelpful / c.count,
              ),
              if (c.unhelpful > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    l10n.unhelpfulCount(c.unhelpful),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

/// Horizontal bar: total doubts for a concept, with the share students marked
/// "not helpful" highlighted, since that's where the teacher should step in.
class _ConceptBar extends StatelessWidget {
  const _ConceptBar({required this.fraction, required this.unhelpful});

  final double fraction;
  final double unhelpful;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * fraction;
        return Stack(
          children: [
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              height: 10,
              width: width,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            if (unhelpful > 0)
              Container(
                height: 10,
                width: width * unhelpful,
                decoration: BoxDecoration(
                  color: AppTheme.saffron,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuizzesCard extends ConsumerWidget {
  const _QuizzesCard({required this.classroomId});

  final int classroomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final quizzes = ref.watch(classroomQuizzesProvider(classroomId));
    final list = quizzes.value ?? const <Quiz>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                l10n.quizzes,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (quizzes.isLoading && list.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              ),
            for (final q in list)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: const Icon(Icons.quiz_rounded),
                title: Text(q.title),
                subtitle: Text(
                  '${l10n.questionsCount(q.questions.length)} · '
                  '${DateFormat.MMMd().format(q.createdAt)}',
                ),
                trailing: Text(l10n.attempts(q.attemptCount)),
                onTap: () => context.push('/teacher/quiz/${q.id}'),
              ),
          ],
        ),
      ),
    );
  }
}

class _LiveFeedCard extends ConsumerWidget {
  const _LiveFeedCard({required this.classroomId, required this.insights});

  final int classroomId;
  final Insights insights;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final feed = ref.watch(liveFeedProvider(classroomId));
    final time = DateFormat.jm();

    final live = [
      for (final e in feed.events)
        if (e.type == 'doubt_created')
          (
            title: e.data['question'] as String,
            subtitle:
                '${e.data['student_name']} · ${time.format(e.receivedAt)}',
            icon: Icons.help_outline_rounded,
            isNew: true,
          )
        else if (e.type == 'quiz_attempted')
          (
            title:
                '${e.data['student_name']}: ${e.data['score']}/${e.data['total']}',
            subtitle: time.format(e.receivedAt),
            icon: Icons.emoji_events_outlined,
            isNew: true,
          ),
    ];
    final liveKeys = {
      for (final e in feed.events)
        if (e.type == 'doubt_created')
          '${e.data['question']}|${e.data['student_name']}',
    };
    final history = [
      for (final d in insights.recent)
        if (!liveKeys.contains('${d.question}|${d.studentName}'))
          (
            title: d.question,
            subtitle:
                '${d.studentName} · ${DateFormat.MMMd().add_jm().format(d.createdAt)}',
            icon: Icons.help_outline_rounded,
            isNew: false,
          ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(l10n.liveFeed, style: theme.textTheme.titleMedium),
                  const Spacer(),
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: feed.connected ? Colors.green : theme.disabledColor,
                  ),
                  const SizedBox(width: 6),
                  Text(l10n.live, style: theme.textTheme.labelMedium),
                ],
              ),
            ),
            for (final item in [...live, ...history].take(15))
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: Icon(
                  item.icon,
                  color: item.isNew ? theme.colorScheme.primary : null,
                ),
                title: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(item.subtitle),
                tileColor: item.isNew
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
