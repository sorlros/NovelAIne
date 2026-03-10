import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/content_provider.dart';
import '../../../data/models/story_model.dart';
import '../../../data/models/character_model.dart';
import '../../../data/services/api_service.dart';
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
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text(
                "스토리 제목 수정",
                style: TextStyle(color: Colors.white),
              ),
              content: TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "새로운 제목",
                  hintStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF7C3AED)),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "취소",
                    style: TextStyle(color: Colors.white54),
                  ),
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
                        child: const Text(
                          "저장",
                          style: TextStyle(
                            color: Color(0xFF7C3AED),
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

  void _showCreateCharacterDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text(
                "새 캐릭터 만들기",
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "이름",
                      labelStyle: TextStyle(color: Colors.white54),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF7C3AED)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "설명",
                      labelStyle: TextStyle(color: Colors.white54),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF7C3AED)),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "취소",
                    style: TextStyle(color: Colors.white54),
                  ),
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
                          if (nameController.text.trim().isEmpty) return;
                          setState(() => isLoading = true);
                          try {
                            await ApiService().createCharacter(
                              nameController.text.trim(),
                              descController.text.trim(),
                              [
                                "용감함",
                                "호기심 많음",
                              ], // Hardcoded default traits for now
                            );
                            ref.invalidate(charactersProvider);
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            setState(() => isLoading = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("생성 실패: $e")),
                              );
                            }
                          }
                        },
                        child: const Text(
                          "생성",
                          style: TextStyle(
                            color: Color(0xFF7C3AED),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesState = ref.watch(storiesProvider);
    final charactersState = ref.watch(charactersProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      children: [
        const Text(
          "내 스토리",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ).animate().fadeIn().slideX(),
        const SizedBox(height: 16),
        storiesState.when(
          data: (stories) {
            if (stories.isEmpty) {
              return const Text(
                "아직 작성된 스토리가 없습니다.",
                style: TextStyle(color: Colors.white54),
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
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
          ),
          error: (err, _) =>
              Text("Error: $err", style: const TextStyle(color: Colors.red)),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "내 캐릭터",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Color(0xFF7C3AED)),
              onPressed: () => _showCreateCharacterDialog(context, ref),
            ),
          ],
        ).animate().fadeIn().slideX(delay: 200.ms),
        const SizedBox(height: 16),
        charactersState.when(
          data: (characters) {
            if (characters.isEmpty) {
              return const Text(
                "아직 생성된 캐릭터가 없습니다.",
                style: TextStyle(color: Colors.white54),
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
                return _buildCharacterCard(char, index);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) =>
              Text("Error: $err", style: const TextStyle(color: Colors.red)),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Dark card background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withOpacity(0.15), // Purple tint
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.menu_book, color: Color(0xFF7C3AED)),
        ),
        title: Text(
          story.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            '상태: ${story.status}',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white54),
              onPressed: () {
                _showEditStoryDialog(context, ref, story);
              },
            ),
            _DeleteStoryButton(storyId: story.id.toString()),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(delay: (300 + index * 100).ms);
  }

  Widget _buildCharacterCard(CharacterModel char, int index) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, size: 36, color: Color(0xFF7C3AED)),
          ),
          const SizedBox(height: 16),
          Text(
            char.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                char.description.isNotEmpty ? char.description : 'Unknown Role',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white54,
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
        ref.refresh(storiesProvider);
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
        ? const Padding(
            padding: EdgeInsets.all(12.0),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.redAccent,
              ),
            ),
          )
        : IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: _deleteStory,
          );
  }
}
