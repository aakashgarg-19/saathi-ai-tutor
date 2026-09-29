import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// JWT persisted in the platform keystore, mirrored in memory for synchronous
/// access from the HTTP interceptor.
class TokenStorage {
  static const _key = 'access_token';
  final _secure = const FlutterSecureStorage();
  String? _token;

  String? get token => _token;

  Future<String?> load() async => _token = await _secure.read(key: _key);

  Future<void> save(String token) async {
    _token = token;
    await _secure.write(key: _key, value: token);
  }

  Future<void> clear() async {
    _token = null;
    await _secure.delete(key: _key);
  }
}
