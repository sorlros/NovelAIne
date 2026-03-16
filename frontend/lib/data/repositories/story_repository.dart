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
    try {
      final localScenes = await (database.select(database.scenes)
        ..where((t) => t.storyId.equals(storyId))
        ..orderBy([(t) => OrderingTerm(expression: t.sequence)]))
        .get();

      if (localScenes.isNotEmpty && !forceRefresh) {
        debugPrint("🟢 [Cache] Found ${localScenes.length} scenes for story $storyId.");
        return localScenes.map((s) => {
          'id': s.id,
          'storyId': s.storyId,
          'sequence': s.sequence,
          'content': s.content,
          'sceneType': s.sceneType,
          'imageUrl': s.imageUrl,
          'bgmUrl': s.bgmUrl,
          'role': 'ai', 
        }).toList();
      }
    } catch (e) {
      debugPrint("⚠️ [Cache] Failed to read scenes from local DB: $e");
    }

    // Fetch from API
    try {
      debugPrint("☁️ [API] Fetching scenes for story $storyId from Supabase...");
      final remoteScenes = await apiService.fetchScenes(storyId);
      
      if (remoteScenes.isEmpty) {
        debugPrint("🟡 [API] No scenes found on server for story $storyId.");
        return [];
      }

      // Sync to local
      try {
        for (var s in remoteScenes) {
          // 백엔드 응답에서 내용(content)을 찾기 위해 가능한 모든 필드명 확인
          final String contentBody = s['content'] ?? s['text'] ?? s['body'] ?? "";
          
          if (contentBody.isEmpty) {
            debugPrint("⚠️ [Cache] Warning: Scene ${s['id']} has no content. Raw: $s");
          }

          await database.into(database.scenes).insertOnConflictUpdate(
            ScenesCompanion.insert(
              id: s['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
              storyId: storyId,
              sequence: s['sequence'] ?? 0,
              content: contentBody,
              sceneType: Value(s['scene_type'] ?? s['sceneType'] ?? 'narrative'),
              imageUrl: Value(s['image_url'] ?? s['imageUrl']),
              bgmUrl: Value(s['bgm_url'] ?? s['bgmUrl']),
            )
          );
        }
        debugPrint("💾 [Cache] Synced ${remoteScenes.length} scenes to local DB.");
      } catch (dbErr) {
        debugPrint("⚠️ [Cache] Sync failed: $dbErr");
      }

      // Return formatted data
      return remoteScenes.map((s) => {
        'id': s['id'],
        'content': s['content'] ?? s['text'] ?? s['body'] ?? "내용을 불러올 수 없습니다.",
        'role': s['role'] ?? 'ai',
        'imageUrl': s['image_url'] ?? s['imageUrl'],
        'bgmUrl': s['bgm_url'] ?? s['bgmUrl'],
        'sceneType': s['scene_type'] ?? s['sceneType'] ?? 'narrative',
      }).toList();
    } catch (apiErr) {
      debugPrint("🚨 [API] Failed to fetch scenes: $apiErr");
      rethrow;
    }
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

  // 4. Delete Story (Sync local & remote)
  Future<void> deleteStory(String storyId) async {
    // 1. Remote Delete
    await apiService.deleteStory(storyId);
    
    // 2. Local Delete (Drift will handle cascade for related scenes/links)
    await (database.delete(database.stories)..where((t) => t.id.equals(storyId))).go();
    
    debugPrint("🗑️ [Cache] Successfully deleted story $storyId from local and remote.");
  }

  // 5. [추가] 단일 스토리 수동 캐싱 (생성 직후 사용)
  Future<void> cacheStory(StoryModel s, {String? userId}) async {
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
    debugPrint("💾 [Cache] Manually cached new story: ${s.title}");
  }
}
