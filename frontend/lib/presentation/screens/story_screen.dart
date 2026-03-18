import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
import '../widgets/character_card.dart';
import '../widgets/custom_loading_indicator.dart';
import '../widgets/custom_toast.dart';

// 화면 전용 상태 관리
final messageProvider = StateProvider.autoDispose<List<Map<String, dynamic>>>((ref) => []);
final isLoadingProvider = StateProvider.autoDispose<bool>((ref) => false);
final currentBackdropProvider = StateProvider.autoDispose<String?>((ref) => null);
final streamingMessageIdProvider = StateProvider.autoDispose<String?>((ref) => null);
final isInitialLoadDoneProvider = StateProvider.autoDispose<bool>((ref) => false);
final isUIReadyProvider = StateProvider.autoDispose<bool>((ref) => false);

// 캐릭터 관련 상태 추가
final storyCharactersProvider = StateProvider.autoDispose<List<Map<String, dynamic>>>((ref) => []);
final presentCharacterNamesProvider = StateProvider.autoDispose<List<String>>((ref) => []);
final importantCharacterNamesProvider = StateProvider.autoDispose<List<String>>((ref) => []);

// 폰트 상태 관리 추가
final selectedFontProvider = StateProvider.autoDispose<String>((ref) => 'Noto Serif KR');
// 현재 이야기의 AI 모델 상태 관리
final currentStoryModelProvider = StateProvider.autoDispose<String>((ref) => 'google/gemini-2.0-flash-001');

// 데이터 변환을 위한 Isolate용 최상단 함수 (메인 스레드 밖에서 실행)
List<Map<String, dynamic>> _processScenesIsolate(List<dynamic> scenes) {
  return scenes.map((scene) => {
    'id': scene['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
    'role': scene['role'] ?? 'ai',
    'content': scene['content'] ?? "",
    'imageUrl': scene['imageUrl'] ?? scene['image_url'],
    'sceneType': scene['sceneType'] ?? scene['scene_type'] ?? 'narrative',
  }).toList();
}

final List<String> availableFonts = [
  'Noto Serif KR',
  'Gowun Batang',
  'Nanum Myeongjo',
  'Song Myung',
  'Gowun Dodum',
];

const List<String> _fontFallbacks = [
  'Apple SD Gothic Neo',
  'Malgun Gothic',
  'sans-serif',
];

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
    _preCacheFonts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _preCacheFonts() {
    // 폰트 전환 시 랙 방지를 위한 사전 로딩
    for (var font in availableFonts) {
      GoogleFonts.getFont(font);
    }
  }

  Future<void> _loadInitialData() async {
    if (widget.initialStory == null || _isInitLoaded) return;

    // --- [초고속 패스] 사전 로드된 데이터가 있는지 확인 ---
    final preWarmedCache = ref.read(preWarmedScenesProvider);
    if (preWarmedCache.containsKey(widget.initialStory!.id)) {
      final preWarmedMessages = preWarmedCache[widget.initialStory!.id]!;
      
      if (mounted) {
        _isInitLoaded = true;
        ref.read(messageProvider.notifier).state = preWarmedMessages;
        
        // 즉시 UI 준비 완료
        ref.read(isInitialLoadDoneProvider.notifier).state = true;
        ref.read(isUIReadyProvider.notifier).state = true;

        final lastImage = preWarmedMessages.lastWhere((m) => m['imageUrl'] != null, orElse: () => {'imageUrl': null})['imageUrl'];
        if (lastImage != null) ref.read(currentBackdropProvider.notifier).state = lastImage;

        // 백그라운드에서 가볍게 API만 갱신 (캐릭터 정보 등)
        _fetchBackgroundDetails();

        _scrollToBottom();
        return; // 즉시 종료
      }
    }
    // -----------------------------------------------------

    // 1. 사전 데이터가 없을 경우 정상적인 로딩 시퀀스 진행
    await Future.delayed(const Duration(milliseconds: 30));

    try {
      final repository = ref.read(storyRepositoryProvider);

      // 2. Fetch Story & Characters (병렬 처리로 시간 단축)
      final results = await Future.wait([
        _apiService.fetchStory(widget.initialStory!.id),
        repository.getScenes(widget.initialStory!.id),
      ]);

      final storyData = results[0] as Map<String, dynamic>;
      final allScenes = results[1] as List<dynamic>;

      if (!mounted) return;

      // 3. 가벼운 정보 업데이트
      if (storyData['llm_model'] != null) {
        ref.read(currentStoryModelProvider.notifier).state = storyData['llm_model'];
      }
      final List<dynamic> chars = storyData['characters'] ?? [];
      ref.read(storyCharactersProvider.notifier).state = chars.map((c) => Map<String, dynamic>.from(c)).toList();

      // 4. [핵심 최적화] 무거운 맵 변환 작업을 Isolate(별도 스레드)에서 수행
      // compute를 사용하여 UI 스레드 멈춤 현상을 근본적으로 차단합니다.
      final processedMessages = await compute(_processScenesIsolate, allScenes);

      if (mounted) {
        _isInitLoaded = true;
        
        // 5. [핵심] 프레임 단위 점진적 주입 (Staggered Loading)
        // 5개씩 끊어서 UI에 넣음으로써 마크다운 레이아웃 폭주 방지
        final int total = processedMessages.length;
        final int firstBatchSize = total > 5 ? 5 : total;
        
        // 첫 5개 즉시 노출
        ref.read(messageProvider.notifier).state = processedMessages.sublist(0, firstBatchSize);
        
        // 즉시 로딩 해제 (애니메이션 멈춤 방지)
        ref.read(isInitialLoadDoneProvider.notifier).state = true;
        ref.read(isUIReadyProvider.notifier).state = true;

        // 배경 설정
        final lastImage = processedMessages.lastWhere((m) => m['imageUrl'] != null, orElse: () => {'imageUrl': null})['imageUrl'];
        if (lastImage != null) ref.read(currentBackdropProvider.notifier).state = lastImage;

        // 사전 캐시 업데이트 (다음 진입 시 더 빠르게)
        ref.read(preWarmedScenesProvider.notifier).update((state) {
          final newState = Map<String, List<Map<String, dynamic>>>.from(state);
          newState[widget.initialStory!.id] = processedMessages;
          return newState;
        });

        // 6. 나머지 데이터는 프레임에 맞춰 부드럽게 추가
        if (total > 5) {
          Future(() async {
            for (int i = 5; i < total; i += 3) {
              await Future.delayed(const Duration(milliseconds: 100)); // 각 배치 사이 짧은 휴식
              if (!mounted) break;
              final end = (i + 3 > total) ? total : i + 3;
              final nextBatch = processedMessages.sublist(i, end);
              ref.read(messageProvider.notifier).update((state) => [...state, ...nextBatch]);
            }
            _scrollToBottom();
          });
        } else {
          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint("🚨 StoryScreen High-Load Error: $e");
      if (mounted) {
        ref.read(isUIReadyProvider.notifier).state = true;
        CustomToast.show(context, "데이터를 불러오는 중 문제가 발생했습니다.", type: ToastType.error);
      }
    }
  }

  Future<void> _fetchBackgroundDetails() async {
    try {
      final storyData = await _apiService.fetchStory(widget.initialStory!.id);
      if (!mounted) return;
      if (storyData['llm_model'] != null) {
        ref.read(currentStoryModelProvider.notifier).state = storyData['llm_model'];
      }
      final List<dynamic> chars = storyData['characters'] ?? [];
      ref.read(storyCharactersProvider.notifier).state = chars.map((c) => Map<String, dynamic>.from(c)).toList();
    } catch (e) {
      debugPrint("Background detail fetch failed: $e");
    }
  }

  Future<void> _analyzeCharacters(String content) async {
    if (widget.initialStory == null || content.isEmpty || content == "...") return;
    
    // 캐릭터 목록이 비어있으면 잠시 대기 (데이터 로딩 타이밍 고려)
    var characters = ref.read(storyCharactersProvider);
    if (characters.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 500));
      characters = ref.read(storyCharactersProvider);
      if (characters.isEmpty) return;
    }

    final charNames = characters.map((c) => c['name'].toString()).toList();
    
    try {
      final analysis = await _apiService.analyzeScene(widget.initialStory!.id, content, charNames);
      
      if (mounted) {
        final List<String> present = List<String>.from(analysis['present_characters'] ?? []);
        final List<String> important = List<String>.from(analysis['important_characters'] ?? []);
        
        // [보정] 주인공은 항상 '등장' 상태로 강제 추가
        final protagonist = characters.firstWhere(
          (c) => c['role_in_story'] == 'protagonist',
          orElse: () => {},
        );
        if (protagonist.isNotEmpty && !present.contains(protagonist['name'])) {
          present.add(protagonist['name']);
        }

        // 상태 업데이트 및 로그 출력
        ref.read(presentCharacterNamesProvider.notifier).state = present;
        ref.read(importantCharacterNamesProvider.notifier).state = important;
        debugPrint("👥 Detected Characters: Present($present), Important($important)");
      }
    } catch (e) {
      debugPrint("🚨 Character Analysis Error: $e");
      // 에러 발생 시 최소한 주인공은 보여주도록 폴백
      if (mounted && ref.read(presentCharacterNamesProvider).isEmpty) {
        final protagonist = characters.firstWhere((c) => c['role_in_story'] == 'protagonist', orElse: () => {});
        if (protagonist.isNotEmpty) {
          ref.read(presentCharacterNamesProvider.notifier).state = [protagonist['name']];
        }
      }
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
      final stream = _apiService.streamChat(widget.initialStory!.id, text);
      bool isFirstChunk = true;
      
      ref.read(streamingMessageIdProvider.notifier).state = aiMessageId;

      // 성능 최적화: 스트리밍 업데이트 스로틀링
      int lastUpdateTimestamp = DateTime.now().millisecondsSinceEpoch;

      await for (final chunk in stream) {
        if (isFirstChunk) {
          fullResponse = chunk;
          isFirstChunk = false;
        } else {
          fullResponse += chunk;
        }

        final now = DateTime.now().millisecondsSinceEpoch;
        // 100ms마다 UI 업데이트 (너무 잦은 리렌더링 방지)
        if (now - lastUpdateTimestamp > 100) {
          ref.read(messageProvider.notifier).update((state) {
            return state.map((msg) {
              if (msg['id'] == aiMessageId) return {...msg, 'content': fullResponse};
              return msg;
            }).toList();
          });
          lastUpdateTimestamp = now;
          
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        }
      }

      // 최종 업데이트
      ref.read(messageProvider.notifier).update((state) {
        return state.map((msg) {
          if (msg['id'] == aiMessageId) return {...msg, 'content': fullResponse};
          return msg;
        }).toList();
      });

      ref.read(streamingMessageIdProvider.notifier).state = null;
      _analyzeCharacters(fullResponse);

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
    final isUIReady = ref.watch(isUIReadyProvider);
    final backdropUrl = ref.watch(currentBackdropProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 다이내믹 배경 & 오버레이
          _buildBackdrop(backdropUrl),
          
          // 2. 메인 서사 영역
          AnimatedOpacity(
            opacity: isUIReady ? 1.0 : 0.0,
            duration: 800.ms,
            curve: Curves.easeIn,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                _buildSliverAppBar(context, innerBoxIsScrolled),
              ],
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 850),
                  child: ListView.builder(
                    controller: _scrollController,
                    // 상단은 AppBar 영역(180px)을 고려하여 충분히 띄움, 하단은 FloatingControls 공간 확보
                    padding: const EdgeInsets.fromLTRB(24, 180, 24, 250), 
                    itemCount: messages.length,
                    cacheExtent: 300,
                    addAutomaticKeepAlives: true,
                    addRepaintBoundaries: true,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      return _RefinedNarrativeCard(
                        key: ValueKey(msg['id'].toString()),
                        msg: msg,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          
          // 3. 플로팅 컨트롤 (캐릭터 카드 + 입력창)
          if (isUIReady) _buildFloatingControls(context),

          // 4. 전체 화면 로딩 오버레이
          if (!isUIReady)
            _buildFullScreenLoading(),
        ],
      ),
    );
  }

  Widget _buildFullScreenLoading() {
    return Container(
      color: const Color(0xFF0D0D12),
      child: const StoryCreationLoadingWidget(),
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
          icon: const Icon(Icons.psychology_rounded, color: Colors.white70, size: 22),
          onPressed: () => _showModelSettings(context),
          tooltip: "AI 엔진 변경",
        ),
        IconButton(
          icon: const Icon(Icons.text_fields_rounded, color: Colors.white70, size: 22),
          onPressed: () => _showFontSettings(context),
          tooltip: "서체 설정",
        ),
        IconButton(
          icon: const Icon(Icons.history_edu_rounded, color: Colors.white70, size: 22),
          onPressed: () {
            // TODO: Show log/history
          },
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(bottom: 16),
        centerTitle: true,
        title: isScrolled 
          ? Text(
              widget.initialStory?.title ?? "Saga",
              style: GoogleFonts.notoSerif(
                color: Colors.white, 
                fontSize: 16, 
                fontWeight: FontWeight.bold
              ).copyWith(fontFamilyFallback: _fontFallbacks),
            )
          : null,
        background: _buildAppBarContent(),
      ),
    );
  }

  void _showFontSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final currentFont = ref.watch(selectedFontProvider);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A24),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "서체 설정",
                  style: GoogleFonts.notoSerif(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: availableFonts.map((font) {
                    final isSelected = currentFont == font;
                    return GestureDetector(
                      onTap: () => ref.read(selectedFontProvider.notifier).state = font,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF7C3AED) : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isSelected ? Colors.transparent : Colors.white10),
                        ),
                        child: Text(
                          font,
                          style: GoogleFonts.getFont(font, color: Colors.white, fontSize: 14),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showModelSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final currentModel = ref.watch(currentStoryModelProvider);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A24),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "AI 스토리 엔진 전환",
                  style: GoogleFonts.notoSerif(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  "중요한 장면에서는 더 정교한 Pro 엔진을 사용해 보세요.",
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                ),
                const SizedBox(height: 24),
                _buildModelToggleOption(
                  ref,
                  "Gemini 2.0 Flash",
                  "빠르고 가벼운 대화와 전개",
                  'google/gemini-2.0-flash-001',
                  currentModel == 'google/gemini-2.0-flash-001',
                ),
                const SizedBox(height: 12),
                _buildModelToggleOption(
                  ref,
                  "Gemini 1.5 Pro",
                  "치밀한 묘사와 깊이 있는 서사",
                  'google/gemini-pro-1.5',
                  currentModel == 'google/gemini-pro-1.5',
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildModelToggleOption(WidgetRef ref, String title, String sub, String modelId, bool isSelected) {
    return GestureDetector(
      onTap: () async {
        if (isSelected) return;
        try {
          // 1. 서버 업데이트 시도
          await _apiService.updateStory(widget.initialStory!.id, {'llm_model': modelId});
          
          // 2. 성공 시 상태 업데이트 (여기서 UI 리렌더링 발생)
          ref.read(currentStoryModelProvider.notifier).state = modelId;
          
          if (mounted) {
            Navigator.pop(context);
            CustomToast.show(context, "$title 엔진으로 전환되었습니다.");
          }
        } catch (e) {
          if (mounted) CustomToast.show(context, "엔진 전환 실패: $e", type: ToastType.error);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7C3AED).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? const Color(0xFF7C3AED) : Colors.white10, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, color: isSelected ? const Color(0xFF7C3AED) : Colors.white24, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(sub, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
                ],
              ),
            ),
            if (isSelected) 
              const Icon(Icons.check_circle, color: Color(0xFF7C3AED), size: 20).animate().scale(duration: 200.ms),
          ],
        ),
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

  Widget _buildFloatingControls(BuildContext context) {
    final characters = ref.watch(storyCharactersProvider);
    final presentNames = ref.watch(presentCharacterNamesProvider);
    final importantNames = ref.watch(importantCharacterNamesProvider);

    // 필터링: 등장 중이거나 중요한 캐릭터
    final visibleCharacters = characters.where((c) {
      final name = c['name'].toString();
      final isProtagonist = c['role_in_story'] == 'protagonist';
      return isProtagonist || presentNames.contains(name) || importantNames.contains(name);
    }).toList();

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
            constraints: const BoxConstraints(maxWidth: 850),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 캐릭터 카드 리스트 (입력창 바로 위)
                if (visibleCharacters.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: SizedBox(
                      height: 90,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        cacheExtent: 300,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        itemCount: visibleCharacters.length,
                        itemBuilder: (context, index) {
                          final char = visibleCharacters[index];
                          final name = char['name'];
                          final isProtagonist = char['role_in_story'] == 'protagonist';
                          final isImportant = importantNames.contains(name);
                          
                          return CharacterCard(
                            name: name,
                            imageUrl: char['image_url'],
                            isProtagonist: isProtagonist,
                            isImportant: isImportant,
                            onTap: () => showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (context) => CharacterSheetWidget(
                                character: char,
                                isProtagonist: isProtagonist,
                              ),
                            ),
                          );
                        },
                      ),
                    ).animate().fadeIn().slideY(begin: 0.2, end: 0),
                  ),
                
                // 입력창
                ClipRRect(
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RefinedNarrativeCard extends ConsumerWidget {
  final Map<String, dynamic> msg;
  final bool isStreaming;
  const _RefinedNarrativeCard({super.key, required this.msg, this.isStreaming = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFont = ref.watch(selectedFontProvider);
    final isInitialLoadDone = ref.watch(isInitialLoadDoneProvider);
    final isUser = msg['role'] == 'user';
    
    // 폰트 스타일 공통화 및 폴백 설정
    TextStyle getBaseStyle({double fontSize = 19, FontStyle fontStyle = FontStyle.normal, double height = 2.0}) {
      return GoogleFonts.getFont(
        selectedFont,
        color: Colors.white.withValues(alpha: 0.92),
        fontSize: fontSize,
        height: height,
        fontStyle: fontStyle,
        letterSpacing: 0.4,
      ).copyWith(
        // 폰트 로딩 실패 시 시스템 폰트 사용 (Tofu 현상 방지)
        fontFamilyFallback: _fontFallbacks,
      );
    }

    if (isUser) {
      return RepaintBoundary(
        child: Padding(
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
                    style: getBaseStyle(fontSize: 17, fontStyle: FontStyle.italic, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn().slideX(begin: 0.05),
      );
    }

    // 초기 로딩 중이거나 스트리밍 중에는 일반 Text 위젯 사용 (성능 최적화)
    final bool useSimpleText = isStreaming || !isInitialLoadDone;

    return RepaintBoundary(
      child: Padding(
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
                    imageUrl: msg['imageUrl'], 
                    fit: BoxFit.cover,
                    memCacheWidth: 800,
                    placeholder: (context, url) => Container(height: 200, color: Colors.white.withValues(alpha: 0.05)),
                  ),
                ),
              ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0.98, 0.98)),
            
            if (useSimpleText)
              Text(
                msg['content'],
                style: getBaseStyle(),
              )
            else
              MarkdownBody(
                data: msg['content'],
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: getBaseStyle(),
                  strong: getBaseStyle().copyWith(color: const Color(0xFF7C3AED), fontWeight: FontWeight.bold),
                  blockquoteDecoration: BoxDecoration(
                    border: const Border(left: BorderSide(color: Color(0xFF7C3AED), width: 4)),
                    color: Colors.white.withValues(alpha: 0.03),
                  ),
                  blockquote: getBaseStyle(fontStyle: FontStyle.italic).copyWith(color: Colors.white.withValues(alpha: 0.7)),
                ),
              ),
          ],
        ),
      ).animate().fadeIn(duration: isStreaming ? 0.ms : 600.ms),
    );
  }
}
