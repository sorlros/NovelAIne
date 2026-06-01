import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/auth_session_model.dart';

class AuthSessionStore {
  static const String _fileName = 'novelaine_auth_session.json';

  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File(p.join(directory.path, _fileName));
  }

  Future<AuthSessionModel?> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) {
        return null;
      }
      final raw = await file.readAsString();
      if (raw.isEmpty) {
        return null;
      }
      return AuthSessionModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> save(AuthSessionModel session) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(session.toJson()), flush: true);
  }

  Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort cleanup.
    }
  }
}
