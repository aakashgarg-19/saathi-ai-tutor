import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/storage/local_store.dart';

enum UserRole { student, teacher }

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  final int id;
  final String name;
  final String email;
  final UserRole role;

  bool get isTeacher => role == UserRole.teacher;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as int,
    name: json['name'] as String,
    email: json['email'] as String,
    role: UserRole.values.byName(json['role'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role.name,
  };
}

/// `null` = signed out. Restores the session offline-first: the cached user is
/// shown immediately and the token is validated in the background.
class AuthController extends AsyncNotifier<AppUser?> {
  static const _userKey = 'user';

  ApiClient get _api => ref.read(apiClientProvider);
  LocalStore get _store => ref.read(localStoreProvider);

  @override
  Future<AppUser?> build() async {
    ref.read(unauthorizedHookProvider).handler = logout;
    final token = await ref.read(tokenStorageProvider).load();
    final cached = _store.setting(_userKey);
    if (token == null || cached == null) return null;
    _refreshProfile();
    return AppUser.fromJson(jsonDecode(cached) as Map<String, dynamic>);
  }

  Future<void> _refreshProfile() async {
    try {
      final json = await _api.get<Map<String, dynamic>>('/auth/me');
      await _store.setSetting(_userKey, jsonEncode(json));
      state = AsyncData(AppUser.fromJson(json));
    } on ApiException {
      // Offline: keep the cached profile. A 401 triggers logout via the hook.
    }
  }

  Future<void> login(String email, String password) => _authenticate(
    '/auth/login',
    {'email': email.trim(), 'password': password},
  );

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) => _authenticate('/auth/register', {
    'name': name.trim(),
    'email': email.trim(),
    'password': password,
    'role': role.name,
  });

  Future<void> _authenticate(String path, Map<String, dynamic> body) async {
    final json = await _api.post<Map<String, dynamic>>(path, body: body);
    final user = AppUser.fromJson(json['user'] as Map<String, dynamic>);
    await ref.read(tokenStorageProvider).save(json['access_token'] as String);
    await _store.setSetting(_userKey, jsonEncode(user.toJson()));
    state = AsyncData(user);
  }

  Future<void> logout() async {
    await ref.read(tokenStorageProvider).clear();
    await _store.clearUserData();
    state = const AsyncData(null);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(
  AuthController.new,
);
