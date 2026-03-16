import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../local/app_database.dart';
import '../services/api_service.dart';
import '../models/story_model.dart';

final storyRepositoryProvider = Provider<StoryRepository>((ref) {
  return StoryRepository(
    apiService: ApiService(),
    database: AppDatabase(), // In real app, might want to provide via singleton
  );
});

class StoryRepository {
  final ApiService apiService;
  final AppDatabase database;

  StoryRepository({required this.apiService, required this.database});

  // 1. Stories Caching
  Future<List<StoryModel>> getStories({String? userId, bool forceRefresh = false}) async {
    try {
      // Check local DB first
      final localStories = await database.select(database.stories).get();
      
      if (localStories.isNotEmpty && !forceRefresh) {
        debugPrint("🟢 [Cache] Found ${localStories.length} stories in Local DB.");
        return localStories.map((s) => StoryModel(
          id: s.id,
          title: s.title,
          genre: s.genre ?? 'fantasy',
          description: s.description ?? '',
          status: s.status,
          totalScenes: s.totalScenes,
          coverImageUrl: s.coverImageUrl,
          createdAt: s.createdAt,
        )).toList();
      }
      
      if (forceRefresh) {
        debugPrint("🔄 [Cache] Force refresh requested. Fetching from API...");
      } else {
        debugPrint("🟡 [Cache] Local DB is empty. Fetching from API...");
      }
    } catch (e) {
      debugPrint("❌ [Cache] Database read failed or not supported: $e");
      debugPrint("ℹ️ Falling back to Remote API...");
    }

    // Fetch from API
    try {
      final remoteStories = await apiService.fetchStories(userId: userId);
      debugPrint("☁️ [API] Fetched ${remoteStories.length} stories from Supabase.");
      
      // Attempt to save to local DB (Update/Insert) silently
      try {
        for (var s in remoteStories) {
          await database.into(database.stories).insertOnConflictUpdate(
            StoriesCompanion.insert(
              id: s.id,
              title: s.title,
              description: Value(s.description),
              genre: Value(s.genre),
              status: Value(s.status),
              totalScenes: Value(s.totalScenes),
              coverImageUrl: Value(s.coverImageUrl),
              createdAt: Value(s.createdAt),
              userId: Value(userId),
            )
          );
        }
        debugPrint("💾 [Cache] Successfully synced ${remoteStories.length} stories to Local DB.");
      } catch (dbErr) {
        debugPrint("⚠️ [Cache] Failed to sync to local DB: $dbErr");
      }

      return remoteStories;
    } catch (apiErr) {
      debugPrint("🚨 [API] Critical Error: $apiErr");
      rethrow;
    }
  }

  // 2. Scenes Caching
  Future<List<Map<String, dynamic>>> getScenes(String storyId, {bool forceRefresh = false}) async {
    final localScenes = await (database.select(database.scenes)
      ..where((t) => t.storyId.equals(storyId))
      ..orderBy([(t) => OrderingTerm(expression: t.sequence)]))
      .get();

    if (localScenes.isNotEmpty && !forceRefresh) {
      return localScenes.map((s) => {
        'id': s.id,
        'storyId': s.storyId,
        'sequence': s.sequence,
        'content': s.content,
        'sceneType': s.sceneType,
        'imageUrl': s.imageUrl,
        'bgmUrl': s.bgmUrl,
        'role': 'ai', // Default role for scenes from API
      }).toList();
    }

    final remoteScenes = await apiService.fetchScenes(storyId);
    
    // Sync to local
    for (var s in remoteScenes) {
      await database.into(database.scenes).insertOnConflictUpdate(
        ScenesCompanion.insert(
          id: s['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          storyId: storyId,
          sequence: s['sequence'] ?? 0,
          content: s['content'],
          sceneType: Value(s['sceneType'] ?? 'narrative'),
          imageUrl: Value(s['imageUrl']),
          bgmUrl: Value(s['bgmUrl']),
        )
      );
    }

    return remoteScenes.map((s) => Map<String, dynamic>.from(s)).toList();
  }

  // 3. Sync Single Story (useful after creation)
  Future<void> syncStory(String storyId) async {
    final storyData = await apiService.fetchStory(storyId);
    
    // Update Story
    await database.into(database.stories).insertOnConflictUpdate(
      StoriesCompanion.insert(
        id: storyData['id'],
        title: storyData['title'],
        description: Value(storyData['description']),
        genre: Value(storyData['genre']),
        status: Value(storyData['status']),
        coverImageUrl: Value(storyData['cover_image_url']),
      )
    );

    // Update Characters linked
    final characters = storyData['characters'] as List?;
    if (characters != null) {
      for (var c in characters) {
        await database.into(database.characters).insertOnConflictUpdate(
          CharactersCompanion.insert(
            id: c['id'],
            name: c['name'],
            description: Value(c['description']),
            imageUrl: Value(c['image_url']),
            personalityTraits: Value(c['personality_traits']?.toString()),
          )
        );

        await database.into(database.storyCharacters).insertOnConflictUpdate(
          StoryCharactersCompanion.insert(
            storyId: storyId,
            characterId: c['id'],
            roleInStory: Value(c['role_in_story']),
          )
        );
      }
    }
  }
}
