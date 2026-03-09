import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      final data = await _apiService.login(email, password);
      final user = UserModel.fromJson(data['user']);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signup(String email, String password, String username) async {
    state = const AsyncValue.loading();
    try {
      final data = await _apiService.signup(email, password, username);
      final user = UserModel.fromJson(data['user']);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  void logout() {
    state = const AsyncValue.data(null);
  }
}
