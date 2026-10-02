import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saathi/core/api/api_client.dart';
import 'package:saathi/features/doubts/chat_controller.dart';
import 'package:saathi/features/doubts/doubt_repository.dart';
import 'package:saathi/features/doubts/outbox_sync.dart';

class FakeRepo implements DoubtRepository {
  Stream<SseEvent> Function(DoubtRequest req) onAsk = (_) =>
      const Stream.empty();
  final requests = <DoubtRequest>[];

  @override
  Stream<SseEvent> askStream(DoubtRequest req) {
    requests.add(req);
    return onAsk(req);
  }

  @override
  Future<List<Doubt>> history(int chapterId) async => [];

  @override
  Future<void> feedback(int doubtId, bool helpful) async {}

  @override
  Future<Doubt> ask(DoubtRequest req) => throw UnimplementedError();
}

class FakeOutbox implements OutboxSync {
  final queued = <DoubtRequest>[];
  final _synced = StreamController<Doubt>.broadcast();

  @override
  Stream<Doubt> get synced => _synced.stream;

  void emitSynced(Doubt d) => _synced.add(d);

  @override
  Future<void> enqueue(DoubtRequest req) async => queued.add(req);

  @override
  List<DoubtRequest> pending({int? chapterId}) => queued;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Stream<SseEvent> _events(List<SseEvent> events) => Stream.fromIterable(events);

void main() {
  late FakeRepo repo;
  late FakeOutbox outbox;
  late ProviderContainer container;

  setUp(() {
    repo = FakeRepo();
    outbox = FakeOutbox();
    container = ProviderContainer(
      overrides: [
        doubtRepositoryProvider.overrideWithValue(repo),
        outboxSyncProvider.overrideWithValue(outbox),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<ChatController> controller() async {
    container.listen(chatControllerProvider(1), (_, _) {});
    await Future<void>.delayed(Duration.zero); // let history load
    return container.read(chatControllerProvider(1).notifier);
  }

  ChatState state() => container.read(chatControllerProvider(1));

  test('streams tokens into one answer and records server metadata', () async {
    repo.onAsk = (_) => _events([
      (
        event: 'sources',
        data: {
          'sources': [
            {
              'ref': 'S1',
              'concept': 'Photosynthesis',
              'excerpt': '…',
              'page': null,
            },
          ],
        },
      ),
      (event: 'token', data: {'text': 'Plants make '}),
      (event: 'token', data: {'text': 'food [S1]'}),
      (event: 'done', data: {'doubt_id': 42, 'from_cache': true}),
    ]);

    await (await controller()).ask('What is photosynthesis?', 'en');

    final entry = state().entries.single;
    expect(entry.answer, 'Plants make food [S1]');
    expect(entry.sources.single.concept, 'Photosynthesis');
    expect(entry.status, EntryStatus.done);
    expect(entry.doubtId, 42);
    expect(entry.fromCache, isTrue);
  });

  test('offline before any token queues the doubt in the outbox', () async {
    repo.onAsk = (_) => Stream.error(ApiException('offline', isNetwork: true));

    await (await controller()).ask('Why is the sky blue?', 'hi');

    expect(state().entries.single.status, EntryStatus.queued);
    expect(outbox.queued.single.question, 'Why is the sky blue?');
    expect(outbox.queued.single.language, 'hi');
  });

  test('a queued doubt is filled in when the outbox syncs it', () async {
    repo.onAsk = (_) => Stream.error(ApiException('offline', isNetwork: true));
    await (await controller()).ask('What are stomata?', 'en');
    final clientId = outbox.queued.single.clientId;

    outbox.emitSynced(
      Doubt(
        id: 9,
        chapterId: 1,
        question: 'What are stomata?',
        language: 'en',
        answer: 'Tiny pores on leaves.',
        concepts: const ['Stomata'],
        clientId: clientId,
        fromCache: false,
        helpful: null,
        createdAt: DateTime(2026),
        sources: const [],
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final entry = state().entries.single;
    expect(entry.status, EntryStatus.done);
    expect(entry.answer, 'Tiny pores on leaves.');
  });

  test('retry after a mid-answer failure reuses the same client id', () async {
    repo.onAsk = (_) async* {
      yield (event: 'token', data: {'text': 'Half an ans'});
      throw ApiException('Connection lost', isNetwork: true);
    };
    final chat = await controller();
    await chat.ask('Explain fungi', 'en');
    expect(state().entries.single.status, EntryStatus.failed);
    expect(
      outbox.queued,
      isEmpty,
      reason: 'partial answers are retried, not queued',
    );

    repo.onAsk = (_) => _events([
      (event: 'token', data: {'text': 'Fungi feed on dead matter.'}),
      (event: 'done', data: {'doubt_id': 3, 'from_cache': false}),
    ]);
    await chat.retry(state().entries.single);

    expect(repo.requests[0].clientId, repo.requests[1].clientId);
    expect(state().entries.single.answer, 'Fungi feed on dead matter.');
  });
}
