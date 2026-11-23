import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// How this device sets the story text (font, size, spacing).
class ReadingPrefsStore {
  static const String _fileName = 'novelaine_reading';

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
      // Best effort: at worst the default text settings show next time.
    }
  }
}
