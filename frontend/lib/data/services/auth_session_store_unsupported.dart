import '../models/auth_session_model.dart';

class AuthSessionStore {
  AuthSessionModel? _session;

  Future<AuthSessionModel?> load() async => _session;

  Future<void> save(AuthSessionModel session) async {
    _session = session;
  }

  Future<void> clear() async {
    _session = null;
  }
}
