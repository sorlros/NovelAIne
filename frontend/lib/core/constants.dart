import 'package:flutter/foundation.dart';

class AppConstants {
  // Centralized breakpoint for desktop vs mobile layout
  static const double desktopBreakpoint = 900.0;
  // Same engines as backend/app/llm_models.py.
  static const String defaultLlmModel = 'deepseek/deepseek-v4.1-flash';
  static const String proLlmModel = 'anthropic/claude-sonnet-5.5';
  static const String fastFallbackLlmModel = 'google/gemini-3.1-flash-lite';
  static const String proFallbackLlmModel = 'google/gemini-3.1-pro-preview';

  /// A story saved with an earlier engine uses the current one of the same kind.
  static String currentLlmModel(String? model) {
    switch (model) {
      case 'google/gemini-3.1-pro-preview':
      case 'google/gemini-pro-1.5':
        return proLlmModel;
      case null:
      case 'google/gemini-3.1-flash-lite':
      case 'google/gemini-2.0-flash-001':
        return defaultLlmModel;
      default:
        return model;
    }
  }

  /// Set with --dart-define=API_BASE_URL=http://127.0.0.1:8000/api to use a
  /// local or staging backend. Empty means the defaults below.
  static const String _baseUrlOverride = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_baseUrlOverride.isNotEmpty) return _baseUrlOverride;
    if (kIsWeb) {
      // return 'http://127.0.0.1:8000/api';
      return 'https://novelaine-backend.onrender.com/api';
    }

    // 2. Android (Emulator usually uses 10.0.2.2 to access host localhost)
    if (defaultTargetPlatform == TargetPlatform.android) {
      // return 'http://10.0.2.2:8000/api';
      return 'https://novelaine-backend.onrender.com/api';
    }

    // 3. iOS / macOS / Windows -> localhost
    // return 'http://127.0.0.1:8000/api';
    return 'https://novelaine-backend.onrender.com/api';
  }
}
