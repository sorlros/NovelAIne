import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants.dart'; // Added missing import
import '../../core/theme/app_palette.dart';
import 'story_generation_screen.dart';
import 'story_screen.dart';

import 'creation/mode_selection_screen.dart' as creation_screen;
import 'profile/settings_screen.dart'; // Added
import '../widgets/responsive_layout.dart';
import '../providers/content_provider.dart';
import '../widgets/custom_toast.dart';
import '../../../data/models/story_model.dart';
import '../../../data/repositories/story_repository.dart';

// Isolate에서 실행될 데이터 가공 함수 (파일 최상단 유지)
List<Map<String, dynamic>> _preWarmScenesIsolate(List<dynamic> scenes) {
  return scenes
      .map(
        (scene) => {
          'id':
              scene['id']?.toString() ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          'role': scene['role'] ?? 'ai',
          'content': scene['content'] ?? "",
          'imageUrl': scene['imageUrl'] ?? scene['image_url'],
          'sceneType': scene['sceneType'] ?? scene['scene_type'] ?? 'narrative',
        },
      )
      .toList();
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      currentIndex: 0,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.0),
                      child: _HeaderSection(),
                    ),
                    const SizedBox(height: 32),
                    const _HorizontalStoryList(),
                    const SizedBox(height: 48),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: const _RecommendedThemes(),
                    ),
                    // 모바일 하단 바 높이만큼 추가 여백
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bool isMobile =
        MediaQuery.of(context).size.width < AppConstants.desktopBreakpoint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "계속 쓰기",
                    style: GoogleFonts.notoSerif(
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 28 : 32, // 모바일에서 폰트 축소
                      color: palette.text,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "당신의 상상력이 현실이 되는 곳입니다.",
                    style: GoogleFonts.lato(
                      color: palette.muted,
                      fontSize: isMobile ? 14 : 15,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                // Navigate to Settings instead if needed, or just remove
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
              icon: Icon(
                Icons.settings_outlined,
                color: palette.muted,
                size: isMobile ? 24 : 28,
              ),
              tooltip: "설정",
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const creation_screen.CreationModeSelectionScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add, size: 20),
            label: const Text(
              "새로운 이야기 시작",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.accent,
              foregroundColor: palette.onAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    ).animate().fadeIn();
  }
}

class _HorizontalStoryList extends ConsumerStatefulWidget {
  const _HorizontalStoryList();

  @override
  ConsumerState<_HorizontalStoryList> createState() =>
      _HorizontalStoryListState();
}

class _HorizontalStoryListState extends ConsumerState<_HorizontalStoryList> {
  bool _hasPreWarmed = false;

  void _preWarmRecentStory(List<StoryModel> stories) async {
    if (_hasPreWarmed || stories.isEmpty) return;
    _hasPreWarmed = true;

    try {
      final recentStory = stories.first;
      final preWarmedCache = ref.read(preWarmedScenesProvider);
      if (preWarmedCache.containsKey(recentStory.id)) return;

      final repository = ref.read(storyRepositoryProvider);
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      final scenes = await repository.getScenes(recentStory.id);
      if (scenes.isEmpty) return;

      final processedMessages = await compute(_preWarmScenesIsolate, scenes);

      if (mounted) {
        ref.read(preWarmedScenesProvider.notifier).update((state) {
          final newState = Map<String, List<Map<String, dynamic>>>.from(state);
          newState[recentStory.id] = processedMessages;
          return newState;
        });
      }
    } catch (e) {
      debugPrint("⚠️ [Pre-Warm] Failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final storiesState = ref.watch(storiesProvider);
    final bool isMobile =
        MediaQuery.of(context).size.width < AppConstants.desktopBreakpoint;

    return storiesState.when(
      data: (stories) {
        if (stories.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              "아직 작성 중인 이야기가 없습니다.",
              style: TextStyle(color: palette.muted),
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _preWarmRecentStory(stories);
        });

        return SizedBox(
          height: isMobile ? 280 : 320, // 모바일에서 높이 축소
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: stories.length,
            itemBuilder: (context, index) {
              return _StoryCard(story: stories[index], index: index);
            },
          ),
        );
      },
      loading: () => _buildShimmer(isMobile, palette),
      error: (error, _) => Center(
        child: Text('Error: $error', style: TextStyle(color: palette.danger)),
      ),
    );
  }

  Widget _buildShimmer(bool isMobile, AppPalette palette) {
    return SizedBox(
      height: isMobile ? 280 : 320,
      child: Shimmer.fromColors(
        baseColor: palette.raised,
        highlightColor: palette.line,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 3,
          itemBuilder: (context, index) => Container(
            width: isMobile ? 170 : 200,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  final StoryModel story;
  final int index;
  const _StoryCard({required this.story, required this.index});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bool isMobile =
        MediaQuery.of(context).size.width < AppConstants.desktopBreakpoint;
    // The title sits on the cover under a dark gradient; a card without a cover shows it in the theme's own colours.
    final bool hasCover = story.coverImageUrl != null;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => story.isGenerating
                ? StoryGenerationScreen(story: story)
                : StoryScreen(initialStory: story),
          ),
        );
      },
      child: Container(
        width: isMobile ? 170 : 200, // 모바일에서 가로폭 축소
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: palette.surface,
          image: story.coverImageUrl != null
              ? DecorationImage(
                  image: CachedNetworkImageProvider(story.coverImageUrl!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.3),
                    BlendMode.darken,
                  ),
                )
              : null,
        ),
        child: Stack(
          children: [
            if (story.coverImageUrl == null)
              Center(
                child: Icon(
                  Icons.book,
                  color: palette.line,
                  size: isMobile ? 48 : 64,
                ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                  gradient: hasCover
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.8),
                          ],
                        )
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      story.title,
                      style: GoogleFonts.notoSerif(
                        color: hasCover ? Colors.white : palette.text,
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 14 : 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      story.genre.toUpperCase(),
                      style: GoogleFonts.lato(
                        color: hasCover ? Colors.white70 : palette.muted,
                        fontWeight: FontWeight.w900,
                        fontSize: 9,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (story.isGenerating)
              Positioned(
                top: 12,
                left: 12,
                child: _GenerationBadge(failed: story.status == 'failed'),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: _DeleteStoryButton(storyId: story.id),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.2, end: 0);
  }
}

class _GenerationBadge extends StatelessWidget {
  final bool failed;
  const _GenerationBadge({required this.failed});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: failed ? palette.danger : palette.accent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        failed ? '생성 실패' : '생성 중',
        style: TextStyle(
          color: failed ? palette.ground : palette.onAccent,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _DeleteStoryButton extends ConsumerStatefulWidget {
  final String storyId;
  const _DeleteStoryButton({required this.storyId});

  @override
  ConsumerState<_DeleteStoryButton> createState() => _DeleteStoryButtonState();
}

class _DeleteStoryButtonState extends ConsumerState<_DeleteStoryButton> {
  bool _isLoading = false;

  Future<void> _handleDelete() async {
    final palette = context.palette;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('스토리 삭제'),
        content: const Text('이 이야기를 정말 삭제하시겠습니까? 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소', style: TextStyle(color: palette.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('삭제', style: TextStyle(color: palette.danger)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    HapticFeedback.vibrate();
    setState(() => _isLoading = true);

    try {
      await ref.read(storyRepositoryProvider).deleteStory(widget.storyId);
      if (mounted) {
        ref.invalidate(storiesProvider);
        CustomToast.show(context, '스토리가 삭제되었습니다.');
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '삭제 실패: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return _isLoading
        ? SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: palette.danger,
            ),
          )
        : GestureDetector(
            onTap: _handleDelete,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline,
                color: Colors.white70,
                size: 18,
              ),
            ),
          );
  }
}

class _RecommendedThemes extends StatelessWidget {
  const _RecommendedThemes();

  @override
  Widget build(BuildContext context) {
    final themes = [
      {'title': '다크 판타지', 'icon': Icons.auto_awesome},
      {'title': '사이버펑크', 'icon': Icons.memory},
      {'title': '로맨스 스릴러', 'icon': Icons.favorite},
    ];

    final palette = context.palette;
    final bool isMobile =
        MediaQuery.of(context).size.width < AppConstants.desktopBreakpoint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.trending_up, color: palette.accent, size: 24),
            const SizedBox(width: 12),
            Text(
              "추천 테마",
              style: GoogleFonts.notoSerif(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.bold,
                color: palette.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: themes
              .map(
                (t) => _buildThemeChip(
                  t['title'] as String,
                  t['icon'] as IconData,
                  palette,
                ),
              )
              .toList(),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildThemeChip(String label, IconData icon, AppPalette palette) {
    return GestureDetector(
      onTap: () => HapticFeedback.lightImpact(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: palette.accent, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: palette.muted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
