/// Whether this device has shown the guide to the story screen (kept in memory only).
class ReadingGuideStore {
  static bool _seen = false;

  Future<bool> seen() async => _seen;

  Future<void> markSeen() async {
    _seen = true;
  }
}
