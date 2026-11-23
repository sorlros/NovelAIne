/// The screen theme picked on this device (kept in memory only).
class ThemeStore {
  static String? _choice;

  Future<String?> read() async => _choice;

  Future<void> write(String choice) async {
    _choice = choice;
  }
}
