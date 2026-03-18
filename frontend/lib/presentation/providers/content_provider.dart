import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/story_model.dart';
import '../../data/models/character_model.dart';
import '../../data/services/api_service.dart';
import '../../data/repositories/story_repository.dart';
import 'auth_provider.dart';

// Provider for Stories (Cached via Repository)
// AI 모델 상태 관리
final selectedModelProvider = StateProvider<String>((ref) => 'google/gemini-2.0-flash-001');

// 최근 스토리의 사전 파싱된 데이터를 담아둘 프로바이더 (앱 구동 랙 방지용)
final preWarmedScenesProvider = StateProvider<Map<String, List<Map<String, dynamic>>>>((ref) => {});

final storiesProvider = FutureProvider<List<StoryModel>>((ref) async {
  final repository = ref.watch(storyRepositoryProvider);
  final authState = ref.watch(authProvider);
  
  return authState.when(
    data: (user) {
      if (user == null) {
        return []; 
      }
      return repository.getStories(userId: user.id);
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

// Provider for Scenes (Cached via Repository)
final scenesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, storyId) async {
  final repository = ref.watch(storyRepositoryProvider);
  return repository.getScenes(storyId);
});
