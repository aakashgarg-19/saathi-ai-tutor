import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/language_toggle.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import 'classroom_repository.dart';

class TeacherHome extends ConsumerWidget {
  const TeacherHome({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final created = await showDialog<Classroom>(
      context: context,
      builder: (_) => const _CreateClassroomDialog(),
    );
    if (created != null) ref.invalidate(myClassroomsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final classrooms = ref.watch(myClassroomsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myClassrooms),
        actions: [
          const LanguageToggle(),
          IconButton(
            tooltip: l10n.logout,
            onPressed: ref.read(authControllerProvider.notifier).logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.createClassroom),
      ),
      body: AsyncView(
        value: classrooms,
        onRetry: () => ref.invalidate(myClassroomsProvider),
        data: (list) => GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 420,
            mainAxisExtent: 150,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: list.length,
          itemBuilder: (context, i) => _ClassroomCard(classroom: list[i]),
        ),
      ),
    );
  }
}

class _ClassroomCard extends StatelessWidget {
  const _ClassroomCard({required this.classroom});

  final Classroom classroom;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/teacher/classroom/${classroom.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(classroom.name, style: theme.textTheme.titleLarge),
              Text(
                '${l10n.classLabel(classroom.grade)} · '
                '${l10n.students(classroom.studentCount)}',
                style: theme.textTheme.bodyMedium,
              ),
              const Spacer(),
              Row(
                children: [
                  Text('${l10n.joinCode}: ', style: theme.textTheme.bodySmall),
                  SelectableText(
                    classroom.joinCode,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: classroom.joinCode),
                      );
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(l10n.copied)));
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateClassroomDialog extends ConsumerStatefulWidget {
  const _CreateClassroomDialog();

  @override
  ConsumerState<_CreateClassroomDialog> createState() =>
      _CreateClassroomDialogState();
}

class _CreateClassroomDialogState
    extends ConsumerState<_CreateClassroomDialog> {
  final _name = TextEditingController();
  var _grade = 7;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().length < 2) return;
    setState(() => _busy = true);
    try {
      final room = await ref
          .read(classroomRepositoryProvider)
          .create(_name.text.trim(), _grade);
      if (mounted) Navigator.pop(context, room);
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
    return AlertDialog(
      title: Text(l10n.createClassroom),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.classroomName),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _grade,
            decoration: InputDecoration(labelText: l10n.grade),
            items: [
              for (var g = 6; g <= 12; g++)
                DropdownMenuItem(value: g, child: Text(l10n.classLabel(g))),
            ],
            onChanged: (g) => setState(() => _grade = g!),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(l10n.create),
        ),
      ],
    );
  }
}
