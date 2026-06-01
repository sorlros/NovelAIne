import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/auth_session_model.dart';
import '../../data/models/user_model.dart';
import '../../data/services/api_service.dart';
import '../../data/services/auth_session_store.dart';

final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>((ref) {
      return AuthNotifier();
    });

class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  AuthNotifier() : super(const AsyncValue.loading()) {
    ApiService.setAccessTokenRefresher(_ensureFreshSession);
    _restoreSession();
  }
  final ApiService _apiService = ApiService();
  final AuthSessionStore _sessionStore = AuthSessionStore();

  Future<void> _restoreSession() async {
    try {
      final session = await _sessionStore.load();
      if (session == null) {
        await _sessionStore.clear();
        ApiService.clearAccessToken();
        state = const AsyncValue.data(null);
        return;
      }

      if (session.shouldRefreshSoon || session.isExpired) {
        final token = await _refreshStoredSession(session);
        if (token == null) {
          return;
        }
        return;
      }

      ApiService.setAccessToken(session.accessToken);
      state = AsyncValue.data(session.user);
    } catch (e, st) {
      debugPrint('Session restore failed: $e');
      ApiService.clearAccessToken();
      state = AsyncValue.error(e, st);
      state = const AsyncValue.data(null);
    }
  }

  Future<String?> _ensureFreshSession() async {
    final session = await _sessionStore.load();
    if (session == null) {
      ApiService.clearAccessToken();
      return null;
    }
    if (!session.shouldRefreshSoon && !session.isExpired) {
      ApiService.setAccessToken(session.accessToken);
      return session.accessToken;
    }
    return _refreshStoredSession(session);
  }

  Future<String?> _refreshStoredSession(AuthSessionModel session) async {
    final refreshToken = session.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      if (session.isExpired) {
        await _clearSession();
      } else {
        ApiService.setAccessToken(session.accessToken);
        state = AsyncValue.data(session.user);
        return session.accessToken;
      }
      return null;
    }

    try {
      final data = await _apiService.refreshSession(refreshToken);
      final refreshedSession = AuthSessionModel.fromAuthResponse(data);
      await _sessionStore.save(refreshedSession);
      ApiService.setAccessToken(refreshedSession.accessToken);
      state = AsyncValue.data(refreshedSession.user);
      return refreshedSession.accessToken;
    } catch (e) {
      debugPrint('Session refresh failed: $e');
      if (!session.isExpired) {
        ApiService.setAccessToken(session.accessToken);
        state = AsyncValue.data(session.user);
        return session.accessToken;
      }
      await _clearSession();
      return null;
    }
  }

  Future<void> _clearSession() async {
    await _sessionStore.clear();
    ApiService.clearAccessToken();
    state = const AsyncValue.data(null);
  }

  Future<UserModel> _activateAuthData(Map<String, dynamic> data) async {
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    final sessionData = data['session'];
    if (sessionData is Map<String, dynamic>) {
      final session = AuthSessionModel.fromAuthResponse(data);
      ApiService.setAccessToken(session.accessToken);
      await _sessionStore.save(session);
    } else {
      ApiService.clearAccessToken();
      await _sessionStore.clear();
    }
    return user;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      debugPrint('Starting login for $email...');
      final data = await _apiService.login(email, password);

      if (data['user'] != null) {
        final user = await _activateAuthData(data);
        state = AsyncValue.data(user);
        debugPrint('Login success: ${user.username}');
      } else {
        throw Exception('사용자 정보를 불러올 수 없습니다.');
      }
    } catch (e, st) {
      debugPrint('Login error: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signup(String email, String password, String username) async {
    state = const AsyncValue.loading();
    try {
      debugPrint('Starting signup for $email...');
      final data = await _apiService.signup(email, password, username);

      if (data['user'] != null) {
        final user = await _activateAuthData(data);
        state = AsyncValue.data(user);
        debugPrint('Signup success: ${user.username}');
      } else {
        // 백엔드 응답에서 data['user']가 없을 경우 처리
        throw Exception('회원가입은 성공했으나 사용자 정보를 불러올 수 없습니다.');
      }
    } catch (e, st) {
      debugPrint('Signup error: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    await _apiService.logout();
    await _clearSession();
  }
}
