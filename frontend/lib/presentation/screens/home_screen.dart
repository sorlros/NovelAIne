import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'story_screen.dart';
import 'creation/mode_selection_screen.dart' as creation_screen;
import '../profile/profile_screen.dart';
import 'explore_screen.dart';
import 'community_screen.dart';
import '../widgets/responsive_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/content_provider.dart';
import '../../../data/services/api_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      currentIndex: 0,
      bottomNavigationBar: const _CrispBottomNavBar(),
      child: const Scaffold(
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
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "계속 쓰기",
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "당신의 상상력이 현실이 되는 곳입니다.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white54,
                  fontSize: 15,
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
          icon: const Icon(Icons.add, size: 20),
          label: const Text(
            "새로운 이야기 시작",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6B4EFF), // Exact purple/blue from mockup
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 800;
            final cardWidth = isDesktop ? 252.0 : 196.0; // 70% of 360 / 280
            final listHeight = isDesktop ? 336.0 : 308.0; // 70% of 480 / 440

            return SizedBox(
              height: listHeight,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: stories.length,
                itemBuilder: (context, index) {
                  final story = stories[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: SizedBox(
                      width: cardWidth,
                      child: _StoryCard(story: story, index: index),
                    ),
                  );
                },
              ),
            );
          },
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
        decoration: BoxDecoration(
          color: const Color(0xFF151515), // Darker card background
          borderRadius: BorderRadius.circular(16), // Slightly smaller radius
          border: Border.all(color: Colors.white10, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image Area
            Expanded(
              flex: 11,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(15),
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
                              size: 32, // Scaled down icon
                            ),
                          )
                        : null,
                  ),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(15),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          const Color(0xFF151515).withOpacity(0.95),
                        ],
                      ),
                    ),
                  ),
                  // Tags and Time
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.access_time, color: Colors.white70, size: 12),
                            const SizedBox(width: 4),
                            const Text(
                              "2시간 전", // Hardcoded example
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            _buildTag(story.genre ?? "판타지", const Color(0xFF3F3B6C)),
                            const SizedBox(width: 4),
                            _buildTag("다크", const Color(0xFF3F3B6C)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Delete Button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Transform.scale(
                      scale: 0.85,
                      child: _DeleteStoryButton(storyId: story.id.toString()),
                    ),
                  ),
                ],
              ),
            ),
            // Content Area
            Expanded(
              flex: 9,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      story.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18, // Reduced font size
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        story.description ??
                            "어둠 속에서 들려오는 목소리. 그것은 구원일까, 또 다른 저주일까?",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12, // Reduced font size
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Progress Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "진행도",
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                        const Text(
                          "45%",
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: const LinearProgressIndicator(
                        value: 0.45,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF6B4EFF),
                        ),
                        minHeight: 4, // Scaled down height
                      ),
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

  Widget _buildTag(String text, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
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
    final themes = ["현대판타지", "로맨스 판타지", "무협", "스페이스 오페라", "아포칼립스", "대체역사"];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.trending_up, color: Color(0xFF6B4EFF), size: 28),
            const SizedBox(width: 12),
            Text(
              "추천 테마",
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Colors.white,
              ),
            ),
          ],
        ).animate().fadeIn().slideX(delay: 400.ms),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: themes.map((theme) {
            return InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white24, width: 1.5),
                ),
                child: Text(
                  theme,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
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
