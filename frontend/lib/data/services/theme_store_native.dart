import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The screen theme picked on this device.
class ThemeStore {
  static const String _fileName = 'novelaine_theme';

  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File(p.join(directory.path, _fileName));
  }

  Future<String?> read() async {
    try {
      final file = await _file();
      return await file.exists() ? (await file.readAsString()).trim() : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String choice) async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(choice, flush: true);
    } catch (_) {
      // Best effort: at worst the default theme shows next time.
    }
  }
}
