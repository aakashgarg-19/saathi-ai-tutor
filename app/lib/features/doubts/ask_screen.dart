import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/locale_controller.dart';
import '../../core/widgets/answer_text.dart';
import '../../core/widgets/offline_banner.dart';
import '../../l10n/app_localizations.dart';
import '../chapters/chapters_repository.dart';
import 'chat_controller.dart';
import 'device_ai.dart';
import 'doubt_repository.dart';

class AskScreen extends ConsumerStatefulWidget {
  const AskScreen({super.key, required this.chapterId});

  final int chapterId;

  @override
  ConsumerState<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends ConsumerState<AskScreen> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _ask(String question) {
    final language = ref.read(localeProvider).languageCode;
    ref
        .read(chatControllerProvider(widget.chapterId).notifier)
        .ask(question, language);
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final chapter = ref.watch(chapterProvider(widget.chapterId));
    final chat = ref.watch(chatControllerProvider(widget.chapterId));
    final l10n = AppLocalizations.of(context);

    ref.listen(
      chatControllerProvider(widget.chapterId).select((s) => s.entries.length),
      (_, _) => _scrollToEnd(),
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(chapter?.title ?? ''),
            if (chapter != null)
              Text(
                '${l10n.classLabel(chapter.grade)} · ${chapter.subject}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: chat.loading
                ? const Center(child: CircularProgressIndicator())
                : chat.entries.isEmpty
                ? _EmptyChat(chapter: chapter, onAsk: _ask)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: chat.entries.length,
                    itemBuilder: (context, i) => _EntryView(
                      entry: chat.entries[i],
                      chapterId: widget.chapterId,
                    ),
                  ),
          ),
          _Composer(onSend: _ask, busy: chat.isBusy),
        ],
      ),
    );
  }
}

class _EmptyChat extends ConsumerWidget {
  const _EmptyChat({required this.chapter, required this.onAsk});

  final Chapter? chapter;
  final void Function(String) onAsk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hindi = ref.watch(localeProvider).languageCode == 'hi';
    final suggestions = [
      for (final c in (chapter?.concepts ?? const <String>[]).take(4))
        hindi ? '$c क्या है?' : 'Explain ${c.toLowerCase()} simply',
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 32),
        Icon(Icons.forum_outlined, size: 56, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          l10n.emptyChatTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.emptyChatBody,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in suggestions)
              ActionChip(label: Text(s), onPressed: () => onAsk(s)),
          ],
        ),
      ],
    );
  }
}

class _EntryView extends ConsumerWidget {
  const _EntryView({required this.entry, required this.chapterId});

  final ChatEntry entry;
  final int chapterId;

  void _showSource(BuildContext context, String ref) {
    final source = entry.sources.where((s) => s.ref == ref).firstOrNull;
    if (source == null) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _SourceSheet(source: source),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(chatControllerProvider(chapterId).notifier);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              margin: const EdgeInsets.only(left: 48, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(18)
                    .copyWith(bottomRight: const Radius.circular(4)),
              ),
              child: Text(
                entry.question,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onPrimary,
                ),
              ),
            ),
          ),
          switch (entry.status) {
            EntryStatus.queued => _StatusNote(
              icon: Icons.schedule_rounded,
              text: l10n.queuedOffline,
            ),
            EntryStatus.failed => _StatusNote(
              icon: Icons.error_outline_rounded,
              text: entry.error ?? l10n.somethingWrong,
              color: scheme.error,
              action: TextButton(
                onPressed: () => controller.retry(entry),
                child: Text(l10n.retry),
              ),
            ),
            _ => Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (entry.answer.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: LinearProgressIndicator(),
                      )
                    else
                      AnswerText(
                        entry.answer,
                        onCitationTap: (r) => _showSource(context, r),
                      ),
                    if (entry.sources.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(l10n.sources, style: theme.textTheme.labelMedium),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final s in entry.sources)
                            ActionChip(
                              visualDensity: VisualDensity.compact,
                              avatar: CircleAvatar(
                                backgroundColor: scheme.primaryContainer,
                                child: Text(
                                  s.ref.substring(1),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              label: Text(s.concept),
                              onPressed: () => _showSource(context, s.ref),
                            ),
                        ],
                      ),
                    ],
                    if (entry.status == EntryStatus.done)
                      _AnswerActions(entry: entry, controller: controller),
                  ],
                ),
              ),
            ),
          },
        ],
      ),
    );
  }
}

class _AnswerActions extends ConsumerWidget {
  const _AnswerActions({required this.entry, required this.controller});

  final ChatEntry entry;
  final ChatController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final speaker = ref.watch(speakerProvider);

    return Row(
      children: [
        ValueListenableBuilder(
          valueListenable: speaker.speaking,
          builder: (context, speakingId, _) {
            final isSpeaking = speakingId == entry.clientId;
            return TextButton.icon(
              onPressed: () => isSpeaking
                  ? speaker.stop()
                  : speaker.speak(entry.clientId, entry.answer, entry.language),
              icon: Icon(
                isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
              ),
              label: Text(isSpeaking ? l10n.stop : l10n.listen),
            );
          },
        ),
        if (entry.fromCache)
          Tooltip(
            message: l10n.cachedAnswer,
            child: Icon(Icons.bolt_rounded, size: 18, color: scheme.tertiary),
          ),
        const Spacer(),
        IconButton(
          tooltip: l10n.wasHelpful,
          isSelected: entry.helpful == true,
          selectedIcon: Icon(Icons.thumb_up_rounded, color: scheme.primary),
          icon: const Icon(Icons.thumb_up_outlined, size: 20),
          onPressed: () => controller.feedback(entry, true),
        ),
        IconButton(
          tooltip: l10n.wasHelpful,
          isSelected: entry.helpful == false,
          selectedIcon: Icon(Icons.thumb_down_rounded, color: scheme.error),
          icon: const Icon(Icons.thumb_down_outlined, size: 20),
          onPressed: () => controller.feedback(entry, false),
        ),
      ],
    );
  }
}

class _StatusNote extends StatelessWidget {
  const _StatusNote({
    required this.icon,
    required this.text,
    this.color,
    this.action,
  });

  final IconData icon;
  final String text;
  final Color? color;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 18, color: c),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(color: c)),
        ),
        ?action,
      ],
    );
  }
}

class _SourceSheet extends StatelessWidget {
  const _SourceSheet({required this.source});

  final Source source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(source.concept, style: theme.textTheme.titleMedium),
          if (source.page != null)
            Text('p. ${source.page}', style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          Text(source.excerpt, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _Composer extends ConsumerStatefulWidget {
  const _Composer({required this.onSend, required this.busy});

  final void Function(String) onSend;
  final bool busy;

  @override
  ConsumerState<_Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<_Composer> {
  final _text = TextEditingController();
  var _listening = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String get _language => ref.read(localeProvider).languageCode;

  void _send() {
    final q = _text.text.trim();
    if (q.length < 3 || widget.busy) return;
    _text.clear();
    widget.onSend(q);
  }

  Future<void> _toggleVoice() async {
    final voice = ref.read(voiceInputProvider);
    if (_listening) {
      await voice.stop();
      return;
    }
    final ok = await voice.start(
      language: _language,
      onResult: (text, isFinal) {
        _text.text = text;
        if (isFinal) {
          setState(() => _listening = false);
          _send();
        }
      },
      onDone: () {
        if (mounted) setState(() => _listening = false);
      },
    );
    setState(() => _listening = ok);
  }

  Future<void> _scan() async {
    final l10n = AppLocalizations.of(context);
    final text = await ref
        .read(questionScannerProvider)
        .scan(language: _language);
    if (!mounted || text == null) return;
    if (text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.ocrNoText)));
    } else {
      // Let the student review OCR output before sending.
      _text.text = text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final canSend = _text.text.trim().length >= 3 && !widget.busy;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (AppConfig.supportsOcr)
              IconButton(
                tooltip: l10n.scanQuestion,
                onPressed: _scan,
                icon: const Icon(Icons.document_scanner_outlined),
              ),
            Expanded(
              child: TextField(
                controller: _text,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: _listening ? l10n.listening : l10n.askHint,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (canSend)
              IconButton.filled(
                onPressed: _send,
                icon: const Icon(Icons.send_rounded),
              )
            else
              IconButton.filled(
                onPressed: widget.busy ? null : _toggleVoice,
                style: IconButton.styleFrom(
                  backgroundColor: _listening ? scheme.error : null,
                ),
                icon: Icon(_listening ? Icons.stop_rounded : Icons.mic_rounded),
              ),
          ],
        ),
      ),
    );
  }
}
