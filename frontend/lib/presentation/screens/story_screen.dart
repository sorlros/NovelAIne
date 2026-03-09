import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../data/services/api_service.dart';
import 'character_sheet_widget.dart';
import '../../data/models/story_model.dart';

// Simple State Management for the story
final messageProvider = StateProvider<List<Map<String, dynamic>>>((ref) => []);
final isLoadingProvider = StateProvider<bool>((ref) => false);
final isGeneratingImageProvider = StateProvider<bool>((ref) => false);

class StoryScreen extends ConsumerStatefulWidget {
  final StoryModel? initialStory;
  const StoryScreen({super.key, this.initialStory});

  @override
  ConsumerState<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends ConsumerState<StoryScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ApiService _apiService = ApiService();
  final AudioPlayer _audioPlayer = AudioPlayer(); // BGM Player

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose(); // Release resources
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final userMessageId = DateTime.now().millisecondsSinceEpoch.toString();

    // Add user message
    ref
        .read(messageProvider.notifier)
        .update(
          (state) => [
            ...state,
            {
              'id': userMessageId,
              'role': 'user',
              'content': text,
              'imageUrl': null,
            },
          ],
        );
    _controller.clear();
    _scrollToBottom();

    // Set loading
    ref.read(isLoadingProvider.notifier).state = true;

    try {
      // Call API
      final responseMap = await _apiService.chat(text);
      final aiText = responseMap['response'] as String;
      final bgmUrl = responseMap['bgmUrl'] as String?;
      final aiMessageId = DateTime.now().millisecondsSinceEpoch.toString();

      // Play BGM if valid
      if (bgmUrl != null && bgmUrl.isNotEmpty) {
        try {
          // Attempt to play the new BGM, sweeping out the old one
          await _audioPlayer.play(UrlSource(bgmUrl));
        } catch (e) {
          debugPrint("BGM Play Error: $e");
        }
      }

      // Determine scene type heuristically for demo
      final isDialogue = aiText.contains('"') || aiText.contains('「');
      final sceneType = isDialogue ? 'dialogue' : 'event';

      // Add AI response
      ref
          .read(messageProvider.notifier)
          .update(
            (state) => [
              ...state,
              {
                'id': aiMessageId,
                'role': 'ai',
                'content': aiText,
                'imageUrl': null,
                'bgmUrl': bgmUrl,
                'sceneType': sceneType,
              },
            ],
          );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      ref.read(isLoadingProvider.notifier).state = false;
    }
  }

  Future<void> _generateImageForMessage(
    String messageId,
    String prompt,
    String type,
  ) async {
    // 1. Lock check: Prevent simultaneous generations
    if (ref.read(isGeneratingImageProvider)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("현재 다른 이미지가 생성 중입니다.")));
      return;
    }

    ref.read(isGeneratingImageProvider.notifier).state = true;

    try {
      final apiService = ApiService();
      // Generate using API with story ID context for appearance injection
      final imageUrl = await apiService.generateImage(
        messageId,
        prompt,
        type,
        storyId: widget.initialStory?.id,
      );

      // Update state with new image
      ref.read(messageProvider.notifier).update((state) {
        return state.map((msg) {
          if (msg['id'] == messageId) {
            return {...msg, 'imageUrl': imageUrl};
          }
          return msg;
        }).toList();
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("이미지 생성 실패: $e")));
      }
    } finally {
      ref.read(isGeneratingImageProvider.notifier).state = false;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showCharacterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const CharacterSheetWidget(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messageProvider);
    final isLoading = ref.watch(isLoadingProvider);
    final isGenerating = ref.watch(isGeneratingImageProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.initialStory?.title ?? "The Lost World",
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            onPressed: _showCharacterSheet,
          ),
          IconButton(icon: const Icon(Icons.menu_rounded), onPressed: () {}),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF121212), // Dark theme background
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: kToolbarHeight + 20),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: messages.length + (isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == messages.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                        );
                      }

                      final msg = messages[index];
                      final isUser = msg['role'] == 'user';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: isUser
                            ? _UserNarrative(
                                content: msg['content']!,
                                imageUrl: msg['imageUrl'],
                                onGenerateImage: () => _generateImageForMessage(
                                  msg['id'],
                                  msg['content'],
                                  'dialogue',
                                ),
                                isGenerating: isGenerating,
                              )
                            : _AINarrative(
                                content: msg['content']!,
                                sceneType: msg['sceneType'],
                                imageUrl: msg['imageUrl'],
                                onGenerateImage: () => _generateImageForMessage(
                                  msg['id'],
                                  msg['content'],
                                  msg['sceneType'],
                                ),
                                isGenerating: isGenerating,
                              ),
                      );
                    },
                  ),
                ),
              ),
              _CommandBar(controller: _controller, onSend: _sendMessage),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserNarrative extends StatelessWidget {
  final String content;
  final String? imageUrl;
  final VoidCallback onGenerateImage;
  final bool isGenerating;

  const _UserNarrative({
    required this.content,
    this.imageUrl,
    required this.onGenerateImage,
    required this.isGenerating,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "> $content",
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF7C3AED),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.right,
            ),
          ],
        ),
      ).animate().fadeIn().slideX(begin: 0.05, end: 0),
    );
  }
}

class _AINarrative extends StatelessWidget {
  final String content;
  final String sceneType; // 'dialogue' or 'event'
  final String? imageUrl;
  final VoidCallback onGenerateImage;
  final bool isGenerating;

  const _AINarrative({
    required this.content,
    required this.sceneType,
    this.imageUrl,
    required this.onGenerateImage,
    required this.isGenerating,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sceneType == 'event') ...[
          _EventImagePlaceholder(
            imageUrl: imageUrl,
            onGenerate: onGenerateImage,
            isGenerating: isGenerating,
          ),
          const SizedBox(height: 16),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sceneType == 'dialogue') ...[
              _AvatarBox(
                imageUrl: imageUrl,
                onGenerate: onGenerateImage,
                isGenerating: isGenerating,
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Text(
                content,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                  height: 1.6,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn().moveY(begin: 10, end: 0);
  }
}

class _EventImagePlaceholder extends StatelessWidget {
  final String? imageUrl;
  final VoidCallback onGenerate;
  final bool isGenerating;

  const _EventImagePlaceholder({
    this.imageUrl,
    required this.onGenerate,
    required this.isGenerating,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrl!,
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
        ),
      ).animate().fadeIn();
    }

    return GestureDetector(
      onTap: isGenerating ? null : onGenerate,
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isGenerating ? const Color(0xFF7C3AED) : Colors.white10,
            width: isGenerating ? 2 : 1,
          ),
        ),
        child: Center(
          child: isGenerating
              ? const CircularProgressIndicator(color: Color(0xFF7C3AED))
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.auto_fix_high, color: Colors.white54, size: 36),
                    SizedBox(height: 8),
                    Text(
                      "클릭하여 씬 일러스트 생성",
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _AvatarBox extends StatelessWidget {
  final String? imageUrl;
  final VoidCallback onGenerate;
  final bool isGenerating;

  const _AvatarBox({
    this.imageUrl,
    required this.onGenerate,
    required this.isGenerating,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isGenerating ? null : onGenerate,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20), // Squircle
          border: Border.all(
            color: isGenerating ? const Color(0xFF7C3AED) : Colors.white10,
            width: isGenerating ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: imageUrl != null
              ? Image.network(imageUrl!, fit: BoxFit.cover)
              : Center(
                  child: isGenerating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF7C3AED),
                          ),
                        )
                      : const Icon(
                          Icons.person_add_alt_1,
                          color: Colors.white24,
                          size: 24,
                        ),
                ),
        ),
      ),
    );
  }
}

class _CommandBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _CommandBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white10),
                ),
                child: TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "어떤 행동을 하시겠습니까?",
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF7C3AED),
                shape: BoxShape.circle, // Vibrant Purple send button
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white),
                onPressed: onSend,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
