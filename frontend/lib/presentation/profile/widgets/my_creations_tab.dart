import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_style.dart';
import '../../providers/content_provider.dart';
import '../../../data/models/story_model.dart';
import '../../../data/models/character_model.dart';
import '../../../data/services/api_service.dart';
import '../../../data/repositories/story_repository.dart'; // Added
import '../../screens/story_generation_screen.dart';
import '../../screens/story_screen.dart';
import '../../screens/profile/character_builder_screen.dart';
import '../../widgets/custom_toast.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MyCreationsTab extends ConsumerWidget {
  const MyCreationsTab({super.key});

  void _showEditStoryDialog(
    BuildContext context,
    WidgetRef ref,
    StoryModel story,
  ) {
    final titleController = TextEditingController(text: story.title);
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final palette = context.palette;
            return AlertDialog(
              title: const Text("스토리 제목 수정"),
              content: TextField(
                controller: titleController,
                style: TextStyle(color: palette.text),
                decoration: InputDecoration(
                  hintText: "새로운 제목",
                  hintStyle: TextStyle(color: palette.faint),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: palette.line),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: palette.accent),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("취소", style: TextStyle(color: palette.muted)),
                ),
                isLoading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : TextButton(
                        onPressed: () async {
                          if (titleController.text.trim().isEmpty) return;
                          setState(() => isLoading = true);
                          try {
                            await ApiService().updateStory(story.id, {
                              "title": titleController.text.trim(),
                            });
                            // Refresh Riverpod provider
                            ref.invalidate(storiesProvider);
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            setState(() => isLoading = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("수정 실패: $e")),
                              );
                            }
                          }
                        },
                        child: Text(
                          "저장",
                          style: TextStyle(
                            color: palette.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ],
            );
          },
        );
      },
    );
  }

  // Replaced by CharacterBuilderScreen

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final style = context.appStyle;
    final storiesState = ref.watch(storiesProvider);
    final charactersState = ref.watch(vaultCharactersProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      children: [
        Text(
          "내 스토리",
          style: style.title(
            TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: palette.text,
            ),
          ),
        ).animate().fadeIn().slideX(),
        const SizedBox(height: 16),
        storiesState.when(
          data: (stories) {
            if (stories.isEmpty) {
              return Text(
                "아직 작성된 스토리가 없습니다.",
                style: TextStyle(color: palette.muted),
              );
            }
            return Column(
              children: stories
                  .asMap()
                  .entries
                  .map(
                    (entry) =>
                        _buildStoryCard(context, ref, entry.value, entry.key),
                  )
                  .toList(),
            );
          },
          loading: () =>
              Center(child: CircularProgressIndicator(color: palette.accent)),
          error: (err, _) =>
              Text("Error: $err", style: TextStyle(color: palette.danger)),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "내 캐릭터",
              style: style.title(
                TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: palette.text,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_circle, color: palette.accent),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CharacterBuilderScreen(),
                  ),
                );
              },
            ),
          ],
        ).animate().fadeIn().slideX(delay: 200.ms),
        const SizedBox(height: 16),
        charactersState.when(
          data: (characters) {
            if (characters.isEmpty) {
              return Text(
                "아직 생성된 캐릭터가 없습니다.",
                style: TextStyle(color: palette.muted),
              );
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.72,
              ),
              itemCount: characters.length,
              itemBuilder: (context, index) {
                final char = characters[index];
                return _buildCharacterCard(palette, style, char, index);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) =>
              Text("Error: $err", style: TextStyle(color: palette.danger)),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStoryCard(
    BuildContext context,
    WidgetRef ref,
    StoryModel story,
    int index,
  ) {
    final palette = context.palette;
    final style = context.appStyle;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: style.card(palette),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => story.isGenerating
                  ? StoryGenerationScreen(story: story)
                  : StoryScreen(initialStory: story),
            ),
          );
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(style.radiusSmall),
          ),
          child: Icon(Icons.menu_book, color: palette.accent),
        ),
        title: Text(
          story.title,
          style: style.title(
            TextStyle(fontWeight: FontWeight.bold, color: palette.text),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            story.isPublic ? '공개 중 · ${story.status}' : '비공개 · ${story.status}',
            style: TextStyle(color: palette.muted, fontSize: 13),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit_outlined, color: palette.muted),
              onPressed: () {
                _showEditStoryDialog(context, ref, story);
              },
            ),
            _VisibilityStoryButton(story: story),
            _DeleteStoryButton(storyId: story.id.toString()),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(delay: (300 + index * 100).ms);
  }

  Widget _buildCharacterCard(
    AppPalette palette,
    AppStyle style,
    CharacterModel char,
    int index,
  ) {
    return Container(
      decoration: style.card(palette),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (char.imageUrl != null && char.imageUrl!.isNotEmpty)
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: palette.accent.withValues(alpha: 0.5),
                ),
              ),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: char.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(strokeWidth: 1),
                  ),
                  errorWidget: (context, url, error) =>
                      Icon(Icons.broken_image_outlined, color: palette.faint),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, size: 36, color: palette.accent),
            ),
          const SizedBox(height: 16),
          Text(
            char.name,
            style: style.title(
              TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: palette.text,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                char.description.isNotEmpty
                    ? char.description.replaceAll('\\n', '\n')
                    : 'Unknown Role',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: palette.muted,
                  height: 1.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ).animate().fadeIn().slideY(delay: (400 + index * 100).ms);
  }
}

class _VisibilityStoryButton extends ConsumerStatefulWidget {
  final StoryModel story;

  const _VisibilityStoryButton({required this.story});

  @override
  ConsumerState<_VisibilityStoryButton> createState() =>
      _VisibilityStoryButtonState();
}

class _VisibilityStoryButtonState
    extends ConsumerState<_VisibilityStoryButton> {
  bool _isLoading = false;

  Future<void> _toggleVisibility() async {
    setState(() => _isLoading = true);
    final nextVisibility = widget.story.isPublic ? 'private' : 'public';

    try {
      await ApiService().updateStory(widget.story.id, {
        'visibility': nextVisibility,
      });
      await ref.read(storyRepositoryProvider).syncStory(widget.story.id);
      ref.invalidate(storiesProvider);
      if (mounted) {
        CustomToast.show(
          context,
          nextVisibility == 'public' ? '공개 서재에 게시했습니다.' : '비공개로 전환했습니다.',
        );
      }
    } catch (error) {
      if (mounted) {
        CustomToast.show(context, '공개 상태 변경 실패: $error', type: ToastType.error);
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
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return IconButton(
      tooltip: widget.story.isPublic ? '비공개로 전환' : '공개 서재에 게시',
      icon: Icon(
        widget.story.isPublic
            ? Icons.public_rounded
            : Icons.public_off_outlined,
        color: widget.story.isPublic ? palette.accent : palette.muted,
      ),
      onPressed: _toggleVisibility,
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
        title: const Text('스토리 삭제'),
        content: const Text('정말로 이 스토리를 삭제하시겠습니까?\n이 작업은 취소할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소', style: TextStyle(color: context.palette.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('삭제', style: TextStyle(color: context.palette.danger)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final repository = ref.read(storyRepositoryProvider);
      await repository.deleteStory(widget.storyId);

      if (mounted) {
        ref.invalidate(storiesProvider);
        CustomToast.show(context, '스토리가 삭제되었습니다.');
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '삭제 실패: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return _isLoading
        ? Padding(
            padding: const EdgeInsets.all(12.0),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.danger,
              ),
            ),
          )
        : IconButton(
            icon: Icon(Icons.delete_outline, color: palette.danger),
            onPressed: _deleteStory,
          );
  }
}
