import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../../../data/models/creation_config.dart';
import '../../../data/repositories/story_repository.dart';
import '../../../data/services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/content_provider.dart';
import '../../widgets/custom_loading_indicator.dart';
import '../story_generation_screen.dart';
import '../story_screen.dart';

/// Asks the server for a story built from [config] and opens it.
///
/// [requestId] is one id per screen: tapping create again after a lost response
/// returns the same story instead of a second one.
Future<void> startStory(
  BuildContext context,
  WidgetRef ref,
  CreationConfig config,
  String requestId,
) async {
  showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.9),
    transitionDuration: const Duration(milliseconds: 500),
    pageBuilder: (context, anim1, anim2) => const Scaffold(
      backgroundColor: Colors.transparent,
      body: StoryCreationLoadingWidget(),
    ),
  );

  try {
    final apiService = ApiService();

    // 선택된 모델 설정
    config.llmModel = ref.read(selectedModelProvider);

    // [수정] 현재 로그인된 사용자 ID 가져오기
    final authState = ref.read(authProvider);
    final userId = authState.value?.id;

    final createdStory = await apiService.createStory(
      config,
      userId: userId,
      requestId: requestId,
    );

    final repository = ref.read(storyRepositoryProvider);

    if (createdStory.isSkeleton) {
      await repository.cacheStory(createdStory, userId: userId);
      ref.invalidate(storiesProvider);
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => StoryGenerationScreen(
            story: createdStory,
            protagonistImage: config.userImageBytes,
          ),
        ),
      );
      return;
    }

    // 1. 생성된 스토리를 로컬 DB에 수동으로 즉시 저장
    await repository.cacheStory(createdStory, userId: userId);

    // 2. 생성된 스토리의 장면들을 서버에서 가져와 '사전 파싱' 진행 (Isolate 활용)
    List<Map<String, dynamic>> processedMessages = [];
    try {
      final scenes = await repository.getScenes(
        createdStory.id,
        forceRefresh: true,
      );

      if (scenes.isNotEmpty) {
        // [성능 핵심] 무거운 맵 변환 작업을 Isolate에서 수행하여 애니메이션 멈춤 방지
        processedMessages = await compute((List<dynamic> rawScenes) {
          return rawScenes
              .map(
                (scene) => {
                  'id':
                      scene['id']?.toString() ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  'role': scene['role'] ?? 'ai',
                  'content': scene['content'] ?? "",
                  'imageUrl': scene['imageUrl'] ?? scene['image_url'],
                  'sceneType':
                      scene['sceneType'] ?? scene['scene_type'] ?? 'narrative',
                },
              )
              .toList();
        }, scenes);

        // [성능 핵심] StoryScreen에 진입하기 전, 캐시 및 메시지 프로바이더 미리 채우기
        ref.read(preWarmedScenesProvider.notifier).update((state) {
          final newState = Map<String, List<Map<String, dynamic>>>.from(state);
          newState[createdStory.id] = processedMessages;
          return newState;
        });

        // 전역 메시지 상태 미리 설정 (StoryScreen 진입 시 즉시 렌더링용)
        ref.read(messageProvider.notifier).state = processedMessages;
      }

      // [수정] 스토리 목록 동기화 강제 수행 및 프로바이더 무효화
      await repository.getStories(userId: userId, forceRefresh: true);
      ref.invalidate(storiesProvider);
    } catch (syncErr) {
      debugPrint("Initial scene sync/parsing failed: $syncErr");
    }

    // Handle character image upload (existing logic)
    if (config.userImageBytes != null) {
      try {
        final storyData = await apiService.fetchStory(createdStory.id);
        final characters = storyData['characters'] as List?;
        if (characters != null && characters.isNotEmpty) {
          final protagonistId = characters.first['id'];
          await apiService.uploadCharacterImage(
            protagonistId,
            config.userImageBytes!,
            fileName: 'protagonist_${protagonistId.substring(0, 8)}.jpg',
          );
        }
      } catch (imageErr) {
        debugPrint("Protagonist image upload failed: $imageErr");
      }
    }

    if (!context.mounted) return;

    // [성능 핵심] StoryScreen 상태 제어: 진입하자마자 UI가 보이고 초기화가 완료된 것으로 설정
    ref.read(isUIReadyProvider.notifier).state = true;
    ref.read(isInitialLoadDoneProvider.notifier).state = true;

    Navigator.pop(context); // Close loading dialog

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => StoryScreen(initialStory: createdStory),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    Navigator.pop(context); // Close loading dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e is ApiException ? e.message : "생성 실패: $e")),
    );
  }
}
