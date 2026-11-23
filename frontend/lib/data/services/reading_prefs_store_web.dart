import 'package:web/web.dart' as web;

/// How this device sets the story text (font, size, spacing).
class ReadingPrefsStore {
  static const String _key = 'novelaine.reading.v1';

  Future<String?> read() async => web.window.localStorage.getItem(_key);

  Future<void> write(String choice) async {
    web.window.localStorage.setItem(_key, choice);
  }
}
