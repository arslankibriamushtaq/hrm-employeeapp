import 'package:flutter/foundation.dart';

class AppConfig {
  /// Override at build time: flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080
  static const String _fromEnv = String.fromEnvironment('API_BASE_URL');

  /// Every backend route lives under this prefix (see ApiPaths.V1 in the backend).
  static const String apiPrefix = '/api/v1';

  static String get defaultBaseUrl {
    if (_fromEnv.isNotEmpty) return _fromEnv;
    // The Android emulator reaches the host machine's localhost through 10.0.2.2.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }
}
