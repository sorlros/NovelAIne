import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Whether this device has shown the guide to the story screen.
class ReadingGuideStore {
  static const String _fileName = 'novelaine_reading_guide_seen';

  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File(p.join(directory.path, _fileName));
  }

  Future<bool> seen() async {
    try {
      return await (await _file()).exists();
    } catch (_) {
      return false;
    }
  }

  Future<void> markSeen() async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString('1', flush: true);
    } catch (_) {
      // Best effort: at worst the guide shows again.
    }
  }
}
