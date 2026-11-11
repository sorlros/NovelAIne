import 'package:web/web.dart' as web;

/// Whether this device has shown the guide to the story screen.
class ReadingGuideStore {
  static const String _key = 'novelaine.reading_guide.seen.v1';

  Future<bool> seen() async => web.window.localStorage.getItem(_key) == '1';

  Future<void> markSeen() async {
    web.window.localStorage.setItem(_key, '1');
  }
}
