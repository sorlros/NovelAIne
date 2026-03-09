import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/story_model.dart';
import '../../data/models/character_model.dart';
import '../../data/services/api_service.dart';

// Provider for Stories
final storiesProvider = FutureProvider<List<StoryModel>>((ref) async {
  final apiService = ApiService();
  return apiService.fetchStories();
});

// Provider for Characters
final charactersProvider = FutureProvider<List<CharacterModel>>((ref) async {
  final apiService = ApiService();
  final data = await apiService.fetchCharacters();
  return data.map((json) => CharacterModel.fromJson(json)).toList();
});
