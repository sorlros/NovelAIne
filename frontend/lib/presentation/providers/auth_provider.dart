import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/user_model.dart';
import '../../data/services/api_service.dart';

final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>((ref) {
      return AuthNotifier();
    });

class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  AuthNotifier() : super(const AsyncValue.data(null));
  final ApiService _apiService = ApiService();

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      debugPrint('Starting login for $email...');
      final data = await _apiService.login(email, password);
      
      if (data != null && data['user'] != null) {
        final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
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
      
      if (data != null && data['user'] != null) {
        final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
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

  void logout() {
    state = const AsyncValue.data(null);
  }
}
