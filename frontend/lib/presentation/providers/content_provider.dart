import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/story_model.dart';
import '../../data/models/character_model.dart';
import '../../data/services/api_service.dart';
import 'auth_provider.dart';

// Provider for Stories
final storiesProvider = FutureProvider<List<StoryModel>>((ref) async {
  final apiService = ApiService();
  final authState = ref.watch(authProvider);
  
  return authState.when(
    data: (user) {
      if (user == null) {
        return []; // Return empty list if not logged in
      }
      return apiService.fetchStories(userId: user.id);
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

// Provider for Characters
final charactersProvider = FutureProvider<List<CharacterModel>>((ref) async {
  final apiService = ApiService();
  final data = await apiService.fetchCharacters();
  return data
      .map<CharacterModel>(
        (json) => CharacterModel.fromJson(json as Map<String, dynamic>),
      )
      .toList();
});
