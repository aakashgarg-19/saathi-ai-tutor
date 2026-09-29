import '../storage/local_store.dart';
import 'api_client.dart';

/// Network-first GET that falls back to the last good response when offline.
Future<T> cachedGet<T>(
  ApiClient api,
  LocalStore store,
  String path,
  T Function(dynamic json) parse, {
  Map<String, dynamic>? query,
}) async {
  final key = query == null
      ? path
      : '$path?${Uri(queryParameters: query.map((k, v) => MapEntry(k, '$v'))).query}';
  try {
    final json = await api.get<dynamic>(path, query: query);
    await store.writeCache(key, json);
    return parse(json);
  } on ApiException catch (e) {
    final cached = e.isNetwork ? store.readCache<dynamic>(key) : null;
    if (cached == null) rethrow;
    return parse(cached);
  }
}
