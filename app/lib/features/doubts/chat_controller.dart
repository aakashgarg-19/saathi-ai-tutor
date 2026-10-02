import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_client.dart';
import 'doubt_repository.dart';
import 'outbox_sync.dart';

enum EntryStatus { streaming, done, queued, failed }

class ChatEntry {
  const ChatEntry({
    required this.clientId,
    required this.question,
    required this.language,
    this.answer = '',
    this.sources = const [],
    this.status = EntryStatus.streaming,
    this.doubtId,
    this.helpful,
    this.fromCache = false,
    this.error,
  });

  final String clientId;
  final String question;
  final String language;
  final String answer;
  final List<Source> sources;
  final EntryStatus status;
  final int? doubtId;
  final bool? helpful;
  final bool fromCache;
  final String? error;

  factory ChatEntry.fromDoubt(Doubt d) => ChatEntry(
    clientId: d.clientId ?? 'server-${d.id}',
    question: d.question,
    language: d.language,
    answer: d.answer,
    sources: d.sources,
    status: EntryStatus.done,
    doubtId: d.id,
    helpful: d.helpful,
    fromCache: d.fromCache,
  );

  ChatEntry copyWith({
    String? answer,
    List<Source>? sources,
    EntryStatus? status,
    int? doubtId,
    bool? helpful,
    bool? fromCache,
    String? error,
  }) => ChatEntry(
    clientId: clientId,
    question: question,
    language: language,
    answer: answer ?? this.answer,
    sources: sources ?? this.sources,
    status: status ?? this.status,
    doubtId: doubtId ?? this.doubtId,
    helpful: helpful ?? this.helpful,
    fromCache: fromCache ?? this.fromCache,
    error: error,
  );
}

class ChatState {
  const ChatState({this.entries = const [], this.loading = true});

  final List<ChatEntry> entries;
  final bool loading;

  bool get isBusy => entries.any((e) => e.status == EntryStatus.streaming);
}

/// Conversation for one chapter: history + live streaming + offline queue.
class ChatController extends Notifier<ChatState> {
  ChatController(this.chapterId);

  final int chapterId;
  static const _uuid = Uuid();

  DoubtRepository get _repo => ref.read(doubtRepositoryProvider);
  OutboxSync get _outbox => ref.read(outboxSyncProvider);

  @override
  ChatState build() {
    final sub = _outbox.synced.listen(_onSynced);
    ref.onDispose(sub.cancel);
    Future.microtask(_loadHistory);
    return const ChatState();
  }

  Future<void> _loadHistory() async {
    final queued = [
      for (final req in _outbox.pending(chapterId: chapterId))
        ChatEntry(
          clientId: req.clientId,
          question: req.question,
          language: req.language,
          status: EntryStatus.queued,
        ),
    ];
    List<ChatEntry> past = const [];
    try {
      final doubts = await _repo.history(chapterId);
      past = [for (final d in doubts.reversed) ChatEntry.fromDoubt(d)];
    } on ApiException {
      // No cache and no network: start with an empty conversation.
    }
    final live = state.entries;
    final known = {
      ...past.map((e) => e.clientId),
      ...live.map((e) => e.clientId),
    };
    state = ChatState(
      entries: [
        ...past,
        ...queued.where((e) => !known.contains(e.clientId)),
        ...live,
      ],
      loading: false,
    );
  }

  Future<void> ask(String question, String language) async {
    final req = DoubtRequest(
      clientId: _uuid.v4(),
      chapterId: chapterId,
      question: question.trim(),
      language: language,
    );
    _upsert(
      ChatEntry(
        clientId: req.clientId,
        question: req.question,
        language: language,
      ),
    );
    await _stream(req);
  }

  /// Retries with the *same* client id, so the server returns the stored answer
  /// if the first attempt actually completed.
  Future<void> retry(ChatEntry entry) => _stream(
    DoubtRequest(
      clientId: entry.clientId,
      chapterId: chapterId,
      question: entry.question,
      language: entry.language,
    ),
  );

  Future<void> _stream(DoubtRequest req) async {
    _update(
      req.clientId,
      (e) => e.copyWith(status: EntryStatus.streaming, answer: '', sources: []),
    );
    final answer = StringBuffer();
    try {
      await for (final event in _repo.askStream(req)) {
        switch (event.event) {
          case 'sources':
            final sources = [
              for (final s in event.data['sources'] as List)
                Source.fromJson(s as Map<String, dynamic>),
            ];
            _update(req.clientId, (e) => e.copyWith(sources: sources));
          case 'token':
            answer.write(event.data['text']);
            final text = answer.toString();
            _update(req.clientId, (e) => e.copyWith(answer: text));
          case 'done':
            _update(
              req.clientId,
              (e) => e.copyWith(
                status: EntryStatus.done,
                doubtId: event.data['doubt_id'] as int,
                fromCache: event.data['from_cache'] as bool,
              ),
            );
          case 'error':
            _update(
              req.clientId,
              (e) => e.copyWith(
                status: EntryStatus.failed,
                error: event.data['message'] as String,
              ),
            );
        }
      }
    } on ApiException catch (e) {
      if (e.isNetwork && answer.isEmpty) {
        await _outbox.enqueue(req);
        _update(req.clientId, (x) => x.copyWith(status: EntryStatus.queued));
      } else {
        _update(
          req.clientId,
          (x) => x.copyWith(status: EntryStatus.failed, error: e.message),
        );
      }
    }
  }

  Future<void> feedback(ChatEntry entry, bool helpful) async {
    final id = entry.doubtId;
    if (id == null) return;
    _update(entry.clientId, (e) => e.copyWith(helpful: helpful));
    try {
      await _repo.feedback(id, helpful);
    } on ApiException {
      // Feedback is best-effort; don't bother the student about it.
    }
  }

  void _onSynced(Doubt doubt) {
    if (doubt.chapterId != chapterId) return;
    _upsert(ChatEntry.fromDoubt(doubt));
  }

  void _upsert(ChatEntry entry) {
    final entries = [...state.entries];
    final i = entries.indexWhere((e) => e.clientId == entry.clientId);
    i >= 0 ? entries[i] = entry : entries.add(entry);
    state = ChatState(entries: entries, loading: state.loading);
  }

  void _update(String clientId, ChatEntry Function(ChatEntry) change) {
    state = ChatState(
      entries: [
        for (final e in state.entries) e.clientId == clientId ? change(e) : e,
      ],
      loading: state.loading,
    );
  }
}

final chatControllerProvider = NotifierProvider.autoDispose
    .family<ChatController, ChatState, int>(ChatController.new);
