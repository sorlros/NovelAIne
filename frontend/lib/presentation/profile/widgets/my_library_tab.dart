import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_style.dart';
import '../../providers/content_provider.dart';
import '../../screens/home_screen.dart' show genreLabel;
import '../../screens/story_screen.dart';

class MyLibraryTab extends ConsumerWidget {
  const MyLibraryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final style = context.appStyle;
    final storiesState = ref.watch(storiesProvider);

    return storiesState.when(
      data: (stories) {
        final activeStories = stories
            .where((s) => s.status == 'active')
            .toList();
        final completedStories = stories
            .where((s) => s.status == 'completed')
            .toList();

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          children: [
            Text(
              "읽고 있는 이야기",
              style: style.title(
                TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: palette.text,
                ),
              ),
            ).animate().fadeIn().slideX(),
            const SizedBox(height: 16),
            SizedBox(
              height: 240,
              child: activeStories.isEmpty
                  ? Center(
                      child: Text(
                        "아직 작성 중인 이야기가 없습니다.",
                        style: TextStyle(color: palette.muted),
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
            Text(
              "완독한 이야기",
              style: style.title(
                TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: palette.text,
                ),
              ),
            ).animate().fadeIn().slideX(delay: 200.ms),
            const SizedBox(height: 16),
            completedStories.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(24),
                    decoration: style.card(palette),
                    child: Center(
                      child: Text(
                        "아직 완독한 이야기가 없습니다.",
                        style: TextStyle(color: palette.muted),
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
      loading: () =>
          Center(child: CircularProgressIndicator(color: palette.accent)),
      error: (err, _) => Center(
        child: Text(
          "스토리를 불러오는데 실패했습니다.",
          style: TextStyle(color: palette.danger),
        ),
      ),
    );
  }

  Widget _buildStoryCard(BuildContext context, dynamic story, int index) {
    final palette = context.palette;
    final style = context.appStyle;
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
                decoration: style.card(palette),
                clipBehavior: Clip.antiAlias,
                child: story.coverImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: story.coverImageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        errorWidget: (context, url, error) => Icon(
                          Icons.broken_image_outlined,
                          color: palette.faint,
                        ),
                      )
                    : Center(
                        child: Icon(
                          Icons.menu_book,
                          size: 40,
                          color: palette.faint,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              story.title,
              style: style.title(
                TextStyle(
                  fontWeight: FontWeight.bold,
                  color: palette.text,
                  fontSize: 14,
                ),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              genreLabel(story.genre),
              style: TextStyle(fontSize: 12, color: palette.muted),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideX(delay: (100 + index * 100).ms);
  }
}
