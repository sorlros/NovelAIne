import 'package:flutter/foundation.dart';

class AppConstants {
  // Centralized breakpoint for desktop vs mobile layout
  static const double desktopBreakpoint = 900.0;

  static String get baseUrl {
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
