import 'package:web/web.dart' as web;

/// The screen theme picked on this device.
class ThemeStore {
  static const String _key = 'novelaine.theme.v1';

  Future<String?> read() async => web.window.localStorage.getItem(_key);

  Future<void> write(String choice) async {
    web.window.localStorage.setItem(_key, choice);
  }
}
