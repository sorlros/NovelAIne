import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/services/api_service.dart';
import '../../data/repositories/story_repository.dart';
import 'character_sheet_widget.dart';
import '../../data/models/story_model.dart';
import '../providers/content_provider.dart';

// 화면 전용 상태 관리
final messageProvider = StateProvider.autoDispose<List<Map<String, dynamic>>>((ref) => []);
final isLoadingProvider = StateProvider.autoDispose<bool>((ref) => false);
final currentBackdropProvider = StateProvider.autoDispose<String?>((ref) => null);

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
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialScenes();
    });
  }

  Future<void> _loadInitialScenes() async {
    if (widget.initialStory == null || _isInitLoaded) return;

    ref.read(isLoadingProvider.notifier).state = true;
    try {
      final repository = ref.read(storyRepositoryProvider);
      final scenes = await repository.getScenes(widget.initialStory!.id);
      
      if (scenes.isEmpty) {
        final remoteScenes = await repository.getScenes(widget.initialStory!.id, forceRefresh: true);
        scenes.addAll(remoteScenes);
      }

      final messages = scenes.map((scene) => {
        'id': scene['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'role': scene['role'] ?? 'ai',
        'content': scene['content'] ?? "",
        'imageUrl': scene['imageUrl'] ?? scene['image_url'],
        'sceneType': scene['sceneType'] ?? scene['scene_type'] ?? 'narrative',
      }).toList();

      if (mounted) {
        ref.read(messageProvider.notifier).state = messages;
        _isInitLoaded = true;

        final lastImage = messages.lastWhere((m) => m['imageUrl'] != null, orElse: () => {'imageUrl': null})['imageUrl'];
        if (lastImage != null) ref.read(currentBackdropProvider.notifier).state = lastImage;

        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("🚨 StoryScreen Error: $e");
    } finally {
      if (mounted) ref.read(isLoadingProvider.notifier).state = false;
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: 600.ms,
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final aiMessageId = DateTime.now().millisecondsSinceEpoch.toString();

    ref.read(messageProvider.notifier).update((state) => [
      ...state,
      {'id': 'user_${aiMessageId}', 'role': 'user', 'content': text, 'imageUrl': null},
      {'id': aiMessageId, 'role': 'ai', 'content': '...', 'imageUrl': null, 'sceneType': 'narrative'},
    ]);
    
    _controller.clear();
    _scrollToBottom();

    try {
      String fullResponse = "";
      final stream = _apiService.streamChat(text);
      bool isFirstChunk = true;
      
      await for (final chunk in stream) {
        if (isFirstChunk) {
          fullResponse = chunk;
          isFirstChunk = false;
        } else {
          fullResponse += chunk;
        }

        ref.read(messageProvider.notifier).update((state) {
          return state.map((msg) {
            if (msg['id'] == aiMessageId) return {...msg, 'content': fullResponse};
            return msg;
          }).toList();
        });
        
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }

      if (widget.initialStory != null) {
        final repository = ref.read(storyRepositoryProvider);
        await repository.getScenes(widget.initialStory!.id, forceRefresh: true);
      }
      
    } catch (e) {
      debugPrint("🚨 Stream Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messageProvider);
    final isLoading = ref.watch(isLoadingProvider);
    final backdropUrl = ref.watch(currentBackdropProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 다이내믹 배경 & 오버레이
          _buildBackdrop(backdropUrl),
          
          // 2. 메인 서사 영역 (가독성 중심 레이아웃)
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              _buildSliverAppBar(context, innerBoxIsScrolled),
            ],
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850), // 가로 폭 제한으로 가독성 확보
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 180),
                  itemCount: messages.length + (isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length) return _buildLoadingIndicator();
                    return _RefinedNarrativeCard(msg: messages[index]);
                  },
                ),
              ),
            ),
          ),
          
          // 3. 플로팅 글래스 HUD
          _buildFloatingHUD(context),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, bool isScrolled) {
    return SliverAppBar(
      expandedHeight: 180.0,
      floating: false,
      pinned: true,
      backgroundColor: isScrolled ? const Color(0xFF0D0D12).withValues(alpha: 0.9) : Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.auto_awesome_mosaic_outlined, color: Colors.white70, size: 22),
          onPressed: () => showModalBottomSheet(
            context: context, backgroundColor: Colors.transparent,
            isScrollControlled: true, builder: (context) => const CharacterSheetWidget(),
          ),
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(bottom: 16),
        centerTitle: true,
        title: isScrolled 
          ? Text(
              widget.initialStory?.title ?? "Saga",
              style: GoogleFonts.notoSerif(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            )
          : null,
        background: _buildAppBarContent(),
      ),
    );
  }

  Widget _buildAppBarContent() {
    return Container(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.initialStory?.genre?.toUpperCase() ?? "STORY",
            style: GoogleFonts.lato(
              color: const Color(0xFF7C3AED), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 5,
            ),
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.5, end: 0),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              widget.initialStory?.title ?? "Untitled",
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSerif(
                color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold, height: 1.2,
              ),
            ).animate().fadeIn(delay: 500.ms).scale(begin: const Offset(0.95, 0.95)),
          ),
          const SizedBox(height: 16),
          Container(width: 40, height: 1, color: Colors.white24),
        ],
      ),
    );
  }

  Widget _buildBackdrop(String? url) {
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: const Color(0xFF0D0D12)),
          if (url != null)
            CachedNetworkImage(
              imageUrl: url, fit: BoxFit.cover, fadeInDuration: 1.seconds,
            ),
          // Scrim & Blur
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    const Color(0xFF0D0D12).withValues(alpha: 0.85),
                    const Color(0xFF0D0D12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED))),
            const SizedBox(height: 16),
            Text("문장을 엮는 중...", style: GoogleFonts.notoSerif(color: Colors.white30, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingHUD(BuildContext context) {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(35),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(35),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: GoogleFonts.lato(color: Colors.white, fontSize: 16),
                          decoration: InputDecoration(
                            hintText: "어떻게 행동할까요?",
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      GestureDetector(
                        onTap: _sendMessage,
                        child: Container(
                          width: 48, height: 48,
                          decoration: const BoxDecoration(color: Color(0xFF7C3AED), shape: BoxShape.circle),
                          child: const Icon(Icons.auto_fix_high_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RefinedNarrativeCard extends StatelessWidget {
  final Map<String, dynamic> msg;
  const _RefinedNarrativeCard({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg['role'] == 'user';
    
    if (isUser) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Align(
          alignment: Alignment.centerRight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "당신의 행동",
                style: GoogleFonts.lato(color: const Color(0xFF7C3AED), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
                  border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
                ),
                child: Text(
                  msg['content'],
                  style: GoogleFonts.notoSerif(color: Colors.white, fontSize: 17, height: 1.6, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn().slideX(begin: 0.05);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (msg['imageUrl'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: CachedNetworkImage(
                  imageUrl: msg['imageUrl'], fit: BoxFit.cover,
                  placeholder: (context, url) => Container(height: 200, color: Colors.white.withValues(alpha: 0.05)),
                ),
              ),
            ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0.98, 0.98)),
          
          MarkdownBody(
            data: msg['content'],
            styleSheet: MarkdownStyleSheet(
              p: GoogleFonts.notoSerif(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 19, // 폰트 사이즈 상향
                height: 2.0,  // 행간 최적화
                letterSpacing: 0.4,
              ),
              strong: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.bold),
              blockquote: BoxDecoration(
                border: const Border(left: BorderSide(color: Color(0xFF7C3AED), width: 4)),
                color: Colors.white.withValues(alpha: 0.03),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }
}
