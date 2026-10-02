import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/storage/local_store.dart';
import 'doubt_repository.dart';

/// Replays doubts asked while offline as soon as connectivity returns.
///
/// Every queued doubt carries a client-generated id, and the server dedupes on
/// it, so a replay interrupted halfway can safely be retried.
class OutboxSync {
  OutboxSync(this._store, this._repo);

  final LocalStore _store;
  final DoubtRepository _repo;
  final _synced = StreamController<Doubt>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _flushing = false;

  /// Emits each doubt once the server has answered it.
  Stream<Doubt> get synced => _synced.stream;

  void start() {
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) flush();
    });
    flush();
  }

  Future<void> enqueue(DoubtRequest req) => _store.enqueue(req.clientId, {
    ...req.toJson(),
    'created_at': DateTime.now().toUtc().toIso8601String(),
  });

  List<DoubtRequest> pending({int? chapterId}) => [
    for (final item in _store.outbox())
      if (chapterId == null || item['chapter_id'] == chapterId)
        DoubtRequest.fromJson(item),
  ];

  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      for (final req in pending()) {
        try {
          final doubt = await _repo.ask(req);
          await _store.dequeue(req.clientId);
          _synced.add(doubt);
        } on ApiException catch (e) {
          // Still offline, or the AI quota is busy: keep it and try later.
          if (e.isNetwork || (e.statusCode ?? 500) >= 500) break;
          // Permanently rejected (e.g. chapter deleted): drop it so it can't block the queue.
          debugPrint('Dropping outbox item ${req.clientId}: ${e.message}');
          await _store.dequeue(req.clientId);
        }
      }
    } finally {
      _flushing = false;
    }
  }

  void dispose() {
    _sub?.cancel();
    _synced.close();
  }
}

final outboxSyncProvider = Provider<OutboxSync>((ref) {
  final sync = OutboxSync(
    ref.watch(localStoreProvider),
    ref.watch(doubtRepositoryProvider),
  )..start();
  ref.onDispose(sync.dispose);
  return sync;
});

final outboxCountProvider = StreamProvider<int>(
  (ref) => ref.watch(localStoreProvider).watchOutboxCount(),
);

final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  bool online(List<ConnectivityResult> r) =>
      !r.contains(ConnectivityResult.none);
  yield online(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(online);
});
