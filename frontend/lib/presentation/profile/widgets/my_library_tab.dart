import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/content_provider.dart';
import '../../screens/story_screen.dart';

class MyLibraryTab extends ConsumerWidget {
  const MyLibraryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesState = ref.watch(storiesProvider);

    return storiesState.when(
      data: (stories) {
        final activeStories = stories.where((s) => s.status == 'active').toList();
        final completedStories = stories.where((s) => s.status == 'completed').toList();

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          children: [
            const Text(
              "읽고 있는 이야기",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ).animate().fadeIn().slideX(),
            const SizedBox(height: 16),
            SizedBox(
              height: 240,
              child: activeStories.isEmpty
                  ? Center(
                      child: const Text(
                        "아직 작성 중인 이야기가 없습니다.",
                        style: TextStyle(color: Colors.white54),
                      ).animate().fadeIn(),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: activeStories.length,
                      itemBuilder: (context, index) {
                        final story = activeStories[index];
                        return _buildStoryCard(context, story, index);
                      },
                    ),
            ),
            const SizedBox(height: 32),
            const Text(
              "완독한 이야기",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ).animate().fadeIn().slideX(delay: 200.ms),
            const SizedBox(height: 16),
            completedStories.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Center(
                      child: Text(
                        "아직 완독한 이야기가 없습니다.",
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ).animate().fadeIn().slideY(delay: 300.ms)
                : SizedBox(
                    height: 240,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: completedStories.length,
                      itemBuilder: (context, index) {
                        final story = completedStories[index];
                        return _buildStoryCard(context, story, index);
                      },
                    ),
                  ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
      ),
      error: (err, _) => const Center(
        child: Text(
          "스토리를 불러오는데 실패했습니다.",
          style: TextStyle(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildStoryCard(BuildContext context, dynamic story, int index) {
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
        width: 140,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                clipBehavior: Clip.antiAlias,
                child: story.coverImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: story.coverImageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white24,
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.menu_book,
                          size: 40,
                          color: Colors.white24,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              story.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              story.genre,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideX(delay: (100 + index * 100).ms);
  }
}
