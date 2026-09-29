import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  /// Override with `--dart-define=API_BASE_URL=https://api.example.com`.
  static const _override = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    // The Android emulator reaches the host machine through 10.0.2.2.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  static String get wsBaseUrl => apiBaseUrl.replaceFirst(RegExp('^http'), 'ws');

  /// Camera OCR uses on-device ML Kit, which only ships for Android and iOS.
  static bool get supportsOcr =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
}
