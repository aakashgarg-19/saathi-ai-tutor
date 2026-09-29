import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

/// Small offline store on top of Hive. Values are JSON so no type adapters
/// or code generation are needed, and the same code runs on web (IndexedDB).
class LocalStore {
  LocalStore._(this._cache, this._queue, this._settings);

  final Box<String> _cache;
  final Box<String> _queue;
  final Box<String> _settings;

  static Future<LocalStore> open() async {
    await Hive.initFlutter('saathi');
    return LocalStore._(
      await Hive.openBox<String>('cache'),
      await Hive.openBox<String>('outbox'),
      await Hive.openBox<String>('settings'),
    );
  }

  // --- read-through cache for API responses ---
  T? readCache<T>(String key) {
    final raw = _cache.get(key);
    return raw == null ? null : jsonDecode(raw) as T;
  }

  Future<void> writeCache(String key, Object? value) =>
      _cache.put(key, jsonEncode(value));

  // --- outbox: actions created offline, replayed when back online ---
  List<Map<String, dynamic>> outbox() =>
      _queue.values.map((v) => jsonDecode(v) as Map<String, dynamic>).toList()
        ..sort(
          (a, b) => (a['created_at'] as String).compareTo(b['created_at']),
        );

  Future<void> enqueue(String id, Map<String, dynamic> item) =>
      _queue.put(id, jsonEncode(item));

  Future<void> dequeue(String id) => _queue.delete(id);

  Stream<int> watchOutboxCount() async* {
    yield _queue.length;
    yield* _queue.watch().map((_) => _queue.length);
  }

  // --- settings ---
  String? setting(String key) => _settings.get(key);

  Future<void> setSetting(String key, String value) =>
      _settings.put(key, value);

  /// Called on logout so the next user never sees someone else's data.
  Future<void> clearUserData() async {
    await _cache.clear();
    await _queue.clear();
  }
}

/// Overridden in `main()` once Hive has opened.
final localStoreProvider = Provider<LocalStore>(
  (ref) => throw UnimplementedError('LocalStore not initialised'),
);
