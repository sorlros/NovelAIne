import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/content_provider.dart';
import '../../screens/story_screen.dart';

class MyLibraryTab extends ConsumerWidget {
  const MyLibraryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesState = ref.watch(storiesProvider);

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
          child: storiesState.when(
            data: (stories) {
              if (stories.isEmpty) {
                return Center(
                  child: const Text(
                    "아직 작성된 스토리가 없습니다.",
                    style: TextStyle(color: Colors.white54),
                  ).animate().fadeIn(),
                );
              }
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: stories.length,
                itemBuilder: (context, index) {
                  final story = stories[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              StoryScreen(initialStory: story),
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
                                image: story.coverImageUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(
                                          story.coverImageUrl!,
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                border: Border.all(color: Colors.white10),
                              ),
                              child: story.coverImageUrl == null
                                  ? const Center(
                                      child: Icon(
                                        Icons.menu_book,
                                        size: 40,
                                        color: Colors.white24,
                                      ),
                                    )
                                  : null,
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
                            story.genre ?? "모험",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn().slideX(delay: (100 + index * 100).ms),
                  );
                },
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
        Container(
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
        ).animate().fadeIn().slideY(delay: 300.ms),
      ],
    );
  }
}
