import 'dart:convert';

import 'package:web/web.dart' as web;

import '../models/auth_session_model.dart';

class AuthSessionStore {
  static const String _key = 'novelaine.auth.session.v1';

  Future<AuthSessionModel?> load() async {
    final raw = web.window.localStorage.getItem(_key);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return AuthSessionModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      web.window.localStorage.removeItem(_key);
      return null;
    }
  }

  Future<void> save(AuthSessionModel session) async {
    web.window.localStorage.setItem(_key, jsonEncode(session.toJson()));
  }

  Future<void> clear() async {
    web.window.localStorage.removeItem(_key);
  }
}
