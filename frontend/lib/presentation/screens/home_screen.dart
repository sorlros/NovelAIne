import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'story_screen.dart';
import 'creation/mode_selection_screen.dart' as creation_screen;
import '../profile/profile_screen.dart';
import 'explore_screen.dart';
import 'community_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/content_provider.dart';
import '../../../data/services/api_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF121212),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: _HeaderSection(),
                ),
                SizedBox(height: 32),
                _HorizontalStoryList(),
                SizedBox(height: 48),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: _RecommendedThemes(),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _CrispBottomNavBar(),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "계속 쓰기",
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.quickStart,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const creation_screen.CreationModeSelectionScreen(),
              ),
            );
          },
          icon: const Icon(Icons.add, size: 18),
          label: Text(
            AppLocalizations.of(context)!.startNewAdventure,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED), // Vibrant purple
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
      ],
    ).animate().fadeIn();
  }
}

class _HorizontalStoryList extends ConsumerWidget {
  const _HorizontalStoryList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesState = ref.watch(storiesProvider);

    return storiesState.when(
      data: (stories) {
        if (stories.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              "아직 작성 중인 이야기가 없습니다.",
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        return SizedBox(
          height:
              440, // Height for the horizontal cards increased to prevent overflow
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: stories.length,
            itemBuilder: (context, index) {
              final story = stories[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: _StoryCard(story: story, index: index),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Error: $error',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  final dynamic story;
  final int index;
  const _StoryCard({required this.story, required this.index});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoryScreen(initialStory: story),
          ),
        );
      },
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E), // Slightly lighter than background
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image Area
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(19),
                      ),
                      image: story.coverImageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(story.coverImageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                      color: Colors.black26,
                    ),
                    child: story.coverImageUrl == null
                        ? const Center(
                            child: Icon(
                              Icons.auto_awesome,
                              color: Colors.white24,
                              size: 40,
                            ),
                          )
                        : null,
                  ),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(19),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          const Color(0xFF1E1E1E).withOpacity(0.9),
                        ],
                      ),
                    ),
                  ),
                  // Tags and Time
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildTag(story.genre ?? "판타지"),
                            const SizedBox(width: 8),
                            _buildTag(
                              "다크",
                            ), // Hardcoded example for demo as per mockup
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                "15분 전", // Hardcoded example
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _DeleteStoryButton(storyId: story.id.toString()),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Content Area
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      story.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Text(
                        story.description ??
                            "어둠 속에서 들려오는 목소리. 그것은 구원일까, 또 다른 저주일까?",
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white60,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Progress bar - Visual placeholder for completeness 65%
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: const LinearProgressIndicator(
                              value: 0.65,
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF7C3AED),
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "65%",
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn().slideY(delay: (200 + index * 100).ms),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RecommendedThemes extends StatelessWidget {
  const _RecommendedThemes();

  @override
  Widget build(BuildContext context) {
    final themes = ["현대판타지", "로맨스 판타지", "무협", "SF", "미스터리", "성장물"];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "추천 테마",
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ).animate().fadeIn().slideX(delay: 400.ms),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: themes.map((theme) {
            return InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Text(
                  theme,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ).animate().fadeIn().slideX(delay: 500.ms),
      ],
    );
  }
}

class _CrispBottomNavBar extends StatelessWidget {
  const _CrispBottomNavBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF151515), // Solid dark background
        border: Border(
          top: BorderSide(color: Colors.white10, width: 1), // Subtle top border
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavBarIcon(Icons.home_outlined, Icons.home, true, () {}),
              _NavBarIcon(Icons.search, Icons.search, false, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ExploreScreen(),
                  ),
                );
              }),
              _NavBarIcon(
                Icons.add_circle_outline,
                Icons.add_circle,
                false,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const creation_screen.CreationModeSelectionScreen(),
                    ),
                  );
                },
              ),
              _NavBarIcon(Icons.forum_outlined, Icons.forum, false, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CommunityScreen(),
                  ),
                );
              }),
              _NavBarIcon(Icons.person_outline, Icons.person, false, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBarIcon extends StatelessWidget {
  final IconData iconOutlined;
  final IconData iconSolid;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarIcon(
    this.iconOutlined,
    this.iconSolid,
    this.isSelected,
    this.onTap,
  );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Icon(
          isSelected ? iconSolid : iconOutlined,
          color: isSelected ? const Color(0xFF7C3AED) : Colors.white54,
          size: 28,
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

  Future<void> _deleteStory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('스토리 삭제', style: TextStyle(color: Colors.white)),
        content: const Text(
          '정말로 이 스토리를 삭제하시겠습니까?\\n이 작업은 취소할 수 없습니다.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      await ApiService().deleteStory(widget.storyId);
      if (mounted) {
        ref.invalidate(storiesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('스토리가 삭제되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('삭제 실패: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.redAccent,
            ),
          )
        : GestureDetector(
            onTap: _deleteStory,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline,
                color: Colors.white70,
                size: 16,
              ),
            ),
          );
  }
}
