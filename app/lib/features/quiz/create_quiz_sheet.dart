import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/locale_controller.dart';
import '../../l10n/app_localizations.dart';
import '../chapters/chapters_repository.dart';
import 'quiz_repository.dart';

Future<void> showCreateQuizSheet(
  BuildContext context, {
  required int classroomId,
  required List<String> suggestedConcepts,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _CreateQuizSheet(
    classroomId: classroomId,
    suggestedConcepts: suggestedConcepts,
  ),
);

class _CreateQuizSheet extends ConsumerStatefulWidget {
  const _CreateQuizSheet({
    required this.classroomId,
    required this.suggestedConcepts,
  });

  final int classroomId;
  final List<String> suggestedConcepts;

  @override
  ConsumerState<_CreateQuizSheet> createState() => _CreateQuizSheetState();
}

class _CreateQuizSheetState extends ConsumerState<_CreateQuizSheet> {
  int? _chapterId;
  var _count = 5.0;
  late var _language = ref.read(localeProvider).languageCode;
  final _concepts = <String>{};
  var _busy = false;
  String? _error;

  Future<void> _generate() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(quizRepositoryProvider)
          .generate(
            classroomId: widget.classroomId,
            chapterId: _chapterId!,
            numQuestions: _count.round(),
            language: _language,
            concepts: _concepts.toList(),
          );
      ref.invalidate(classroomQuizzesProvider(widget.classroomId));
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.quizCreated)));
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final chapters = (ref.watch(chaptersProvider).value ?? const <Chapter>[])
        .where((c) => c.isReady)
        .toList();
    final chapter = chapters.where((c) => c.id == _chapterId).firstOrNull;
    // Concepts the class asked about float to the top of the chip list.
    final conceptOptions = chapter == null
        ? const <String>[]
        : [
            ...widget.suggestedConcepts.where(chapter.concepts.contains),
            ...chapter.concepts.where(
              (c) => !widget.suggestedConcepts.contains(c),
            ),
          ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.createQuiz, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _chapterId,
              decoration: InputDecoration(labelText: l10n.chapter),
              items: [
                for (final c in chapters)
                  DropdownMenuItem(value: c.id, child: Text(c.title)),
              ],
              onChanged: (id) => setState(() {
                _chapterId = id;
                _concepts.clear();
              }),
            ),
            const SizedBox(height: 16),
            Text('${l10n.numQuestions}: ${_count.round()}'),
            Slider(
              value: _count,
              min: 3,
              max: 10,
              divisions: 7,
              onChanged: (v) => setState(() => _count = v),
            ),
            Text(l10n.language),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'en', label: Text('English')),
                ButtonSegment(value: 'hi', label: Text('हिंदी')),
              ],
              selected: {_language},
              onSelectionChanged: (s) => setState(() => _language = s.first),
            ),
            if (conceptOptions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l10n.focusConcepts),
              Text(l10n.focusConceptsHint, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in conceptOptions)
                    FilterChip(
                      label: Text(c),
                      avatar: widget.suggestedConcepts.contains(c)
                          ? const Icon(Icons.trending_up_rounded, size: 16)
                          : null,
                      selected: _concepts.contains(c),
                      onSelected: (on) => setState(
                        () => on ? _concepts.add(c) : _concepts.remove(c),
                      ),
                    ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _chapterId == null || _busy ? null : _generate,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(_busy ? l10n.generating : l10n.createQuiz),
            ),
          ],
        ),
      ),
    );
  }
}
