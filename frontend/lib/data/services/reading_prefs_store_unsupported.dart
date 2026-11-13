/// How this device sets the story text (font, size, spacing) (kept in memory only).
class ReadingPrefsStore {
  static String? _choice;

  Future<String?> read() async => _choice;

  Future<void> write(String choice) async {
    _choice = choice;
  }
}
