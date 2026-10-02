import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/cached_get.dart';
import '../../core/storage/local_store.dart';

class Source {
  const Source(this.ref, this.concept, this.excerpt, this.page);

  final String ref;
  final String concept;
  final String excerpt;
  final int? page;

  factory Source.fromJson(Map<String, dynamic> json) => Source(
    json['ref'] as String,
    json['concept'] as String,
    json['excerpt'] as String,
    json['page'] as int?,
  );
}

class Doubt {
  const Doubt({
    required this.id,
    required this.chapterId,
    required this.question,
    required this.language,
    required this.answer,
    required this.concepts,
    required this.clientId,
    required this.fromCache,
    required this.helpful,
    required this.createdAt,
    required this.sources,
  });

  final int id;
  final int chapterId;
  final String question;
  final String language;
  final String answer;
  final List<String> concepts;
  final String? clientId;
  final bool fromCache;
  final bool? helpful;
  final DateTime createdAt;
  final List<Source> sources;

  factory Doubt.fromJson(Map<String, dynamic> json) => Doubt(
    id: json['id'] as int,
    chapterId: json['chapter_id'] as int,
    question: json['question'] as String,
    language: json['language'] as String,
    answer: json['answer'] as String,
    concepts: (json['concepts'] as List).cast<String>(),
    clientId: json['client_id'] as String?,
    fromCache: json['from_cache'] as bool,
    helpful: json['helpful'] as bool?,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    sources: [
      for (final s in json['sources'] as List? ?? const [])
        Source.fromJson(s as Map<String, dynamic>),
    ],
  );
}

class DoubtRequest {
  const DoubtRequest({
    required this.clientId,
    required this.chapterId,
    required this.question,
    required this.language,
  });

  final String clientId;
  final int chapterId;
  final String question;
  final String language;

  Map<String, dynamic> toJson() => {
    'client_id': clientId,
    'chapter_id': chapterId,
    'question': question,
    'language': language,
  };

  factory DoubtRequest.fromJson(Map<String, dynamic> json) => DoubtRequest(
    clientId: json['client_id'] as String,
    chapterId: json['chapter_id'] as int,
    question: json['question'] as String,
    language: json['language'] as String,
  );
}

class DoubtRepository {
  DoubtRepository(this._api, this._store);

  final ApiClient _api;
  final LocalStore _store;

  /// Streamed answer: `sources`, then `token`*, then `done` | `error`.
  Stream<SseEvent> askStream(DoubtRequest req) =>
      _api.postStream('/doubts/ask/stream', body: req.toJson());

  /// Non-streaming, idempotent on `client_id`. Used to replay the offline outbox.
  Future<Doubt> ask(DoubtRequest req) async =>
      Doubt.fromJson(await _api.post('/doubts', body: req.toJson()));

  Future<List<Doubt>> history(int chapterId) => cachedGet(
    _api,
    _store,
    '/doubts',
    query: {'chapter_id': chapterId},
    (json) => [
      for (final d in json as List) Doubt.fromJson(d as Map<String, dynamic>),
    ],
  );

  Future<void> feedback(int doubtId, bool helpful) =>
      _api.post('/doubts/$doubtId/feedback', body: {'helpful': helpful});
}

final doubtRepositoryProvider = Provider(
  (ref) => DoubtRepository(
    ref.watch(apiClientProvider),
    ref.watch(localStoreProvider),
  ),
);
