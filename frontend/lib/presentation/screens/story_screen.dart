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
        duration: 500.ms,
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final aiMessageId = DateTime.now().millisecondsSinceEpoch.toString();

    // 1. UI에 유저 메시지와 빈 AI 메시지 즉시 추가
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

        // 2. 실시간 텍스트 업데이트
        ref.read(messageProvider.notifier).update((state) {
          return state.map((msg) {
            if (msg['id'] == aiMessageId) return {...msg, 'content': fullResponse};
            return msg;
          }).toList();
        });
        
        // 스크롤을 끝까지 내림 (애니메이션 없이 빠르게)
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }

      // 3. [중요] 스트리밍 완료 후 백엔드 DB와 로컬 캐시 동기화
      if (widget.initialStory != null) {
        final repository = ref.read(storyRepositoryProvider);
        await repository.getScenes(widget.initialStory!.id, forceRefresh: true);
      }
      
    } catch (e) {
      debugPrint("🚨 Stream Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('통신 오류: $e'), backgroundColor: Colors.redAccent),
        );
      }
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
        children: [
          // 1. 다이내믹 배경 레이어
          _buildBackdrop(backdropUrl),
          
          // 2. 스크롤 가능한 콘텐츠 (Sliver 구조)
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              _buildSliverAppBar(context, innerBoxIsScrolled),
            ],
            body: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 150),
                    itemCount: messages.length + (isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == messages.length) return _buildLoadingIndicator();
                      return _NarrativeCard(msg: messages[index]);
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // 3. 플로팅 입력 HUD
          _buildFloatingCommandBar(context),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, bool isScrolled) {
    return SliverAppBar(
      expandedHeight: 220.0,
      floating: false,
      pinned: true,
      backgroundColor: isScrolled ? Colors.black.withValues(alpha: 0.8) : Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.person_outline_rounded, color: Colors.white70),
          onPressed: () => showModalBottomSheet(
            context: context, backgroundColor: Colors.transparent,
            isScrollControlled: true, builder: (context) => const CharacterSheetWidget(),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        titlePadding: const EdgeInsets.only(bottom: 16),
        title: isScrolled 
          ? Text(
              widget.initialStory?.title ?? "NovelAIne",
              style: GoogleFonts.notoSerif(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            )
          : null,
        background: _buildAppBarBackground(),
      ),
    );
  }

  Widget _buildAppBarBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Text(
            widget.initialStory?.genre?.toUpperCase() ?? "ADVENTURE",
            style: GoogleFonts.lato(
              color: const Color(0xFF7C3AED), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 4,
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              widget.initialStory?.title ?? "Untitled Saga",
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSerif(
                color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, height: 1.2,
              ),
            ).animate().fadeIn(delay: 400.ms).scale(begin: const Offset(0.9, 0.9)),
          ),
          const SizedBox(height: 16),
          Container(
            width: 60, height: 1,
            color: Colors.white.withValues(alpha: 0.3),
          ).animate().fadeIn(delay: 600.ms).scaleX(begin: 0, end: 1, curve: Curves.easeOut),
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
              imageUrl: url,
              fit: BoxFit.cover,
              fadeInDuration: 1.seconds,
            ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    const Color(0xFF0D0D12).withValues(alpha: 0.9),
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(30.0),
        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED)),
      ),
    );
  }

  Widget _buildFloatingCommandBar(BuildContext context) {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.whatActionToTake,
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF7C3AED)),
                    onPressed: _sendMessage,
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

class _NarrativeCard extends StatelessWidget {
  final Map<String, dynamic> msg;
  const _NarrativeCard({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg['role'] == 'user';
    
    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                blurRadius: 10, offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            msg['content'],
            style: GoogleFonts.lato(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ).animate().fadeIn().slideX(begin: 0.1);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (msg['imageUrl'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CachedNetworkImage(imageUrl: msg['imageUrl'], fit: BoxFit.cover),
              ),
            ),
          MarkdownBody(
            data: msg['content'],
            styleSheet: MarkdownStyleSheet(
              p: GoogleFonts.notoSerif(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 18, height: 1.9, letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }
}
