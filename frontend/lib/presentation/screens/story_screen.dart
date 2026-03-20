import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../data/services/api_service.dart';
import '../../data/repositories/story_repository.dart';
import 'character_sheet_widget.dart';
import '../../data/models/story_model.dart';
import '../providers/content_provider.dart';
import '../widgets/character_card.dart';
import '../widgets/custom_loading_indicator.dart';
import '../widgets/custom_toast.dart';
import '../widgets/writing_effect.dart';

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

// [개선] 캐릭터 등장 지속성 관리를 위한 상태 (이름: 남은 장면 수)
final characterPersistenceProvider = StateProvider.autoDispose<Map<String, int>>((ref) => {});

// 폰트 상태 관리 추가
final selectedFontProvider = StateProvider.autoDispose<String>((ref) => 'Noto Serif KR');
// 현재 이야기의 AI 모델 상태 관리
final currentStoryModelProvider = StateProvider.autoDispose<String>((ref) => 'google/gemini-2.0-flash-001');

// [신규] 원고 모드 vs 집중 모드 상태 관리
enum StoryViewMode { manuscript, focus }
final viewModeProvider = StateProvider.autoDispose<StoryViewMode>((ref) => StoryViewMode.manuscript);

// 데이터 변환을 위한 Isolate용 최상단 함수
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
  'EB Garamond',
  'JetBrains Mono',
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

// Color Constants
const Color _kBackgroundColor = Color(0xFF0D0D12);
const Color _kAccentColor = Color(0xFF7C3AED);
const Color _kSurfaceColor = Color(0xFF1A1A24);

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
    _preCacheFonts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _preCacheFonts() {
    for (var font in availableFonts) {
      GoogleFonts.getFont(font);
    }
  }

  Future<void> _staggeredLoad(List<Map<String, dynamic>> allMessages) async {
    if (!mounted) return;
    
    ref.read(messageProvider.notifier).state = [];
    ref.read(isUIReadyProvider.notifier).state = true;
    
    const int batchSize = 3;
    for (int i = 0; i < allMessages.length; i += batchSize) {
      if (!mounted) return;
      
      final end = (i + batchSize < allMessages.length) ? i + batchSize : allMessages.length;
      final batch = allMessages.sublist(i, end);
      
      ref.read(messageProvider.notifier).update((state) => [...state, ...batch]);
      await Future.delayed(const Duration(milliseconds: 16));
    }
    
    if (mounted) {
      ref.read(isInitialLoadDoneProvider.notifier).state = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  Future<void> _loadInitialData() async {
    if (widget.initialStory == null || _isInitLoaded) return;

    final preWarmedCache = ref.read(preWarmedScenesProvider);
    if (preWarmedCache.containsKey(widget.initialStory!.id)) {
      final preWarmedMessages = preWarmedCache[widget.initialStory!.id]!;
      
      if (mounted) {
        _isInitLoaded = true;
        final lastImage = preWarmedMessages.lastWhere((m) => m['imageUrl'] != null, orElse: () => {'imageUrl': null})['imageUrl'];
        if (lastImage != null) ref.read(currentBackdropProvider.notifier).state = lastImage;
        _fetchBackgroundDetails();
        _staggeredLoad(preWarmedMessages);
        
        // [추가] 첫 진입 시 팁 노출
        if (preWarmedMessages.length <= 1) {
          Future.delayed(const Duration(seconds: 1), () => _showNarrativeTips());
        }
        return;
      }
    }

    try {
      final repository = ref.read(storyRepositoryProvider);
      final results = await Future.wait([
        _apiService.fetchStory(widget.initialStory!.id),
        repository.getScenes(widget.initialStory!.id),
      ]);

      final storyData = results[0] as Map<String, dynamic>;
      final allScenes = results[1] as List<dynamic>;

      if (!mounted) return;

      if (storyData['llm_model'] != null) {
        ref.read(currentStoryModelProvider.notifier).state = storyData['llm_model'];
      }
      final List<dynamic> chars = storyData['characters'] ?? [];
      ref.read(storyCharactersProvider.notifier).state = chars.map((c) => Map<String, dynamic>.from(c)).toList();

      final processedMessages = await compute(_processScenesIsolate, allScenes);

      if (mounted) {
        _isInitLoaded = true;
        final lastImage = processedMessages.lastWhere((m) => m['imageUrl'] != null, orElse: () => {'imageUrl': null})['imageUrl'];
        if (lastImage != null) ref.read(currentBackdropProvider.notifier).state = lastImage;

        ref.read(preWarmedScenesProvider.notifier).update((state) {
          final newState = Map<String, List<Map<String, dynamic>>>.from(state);
          newState[widget.initialStory!.id] = processedMessages;
          return newState;
        });
        _staggeredLoad(processedMessages);

        // [추가] 첫 진입 시 팁 노출
        if (processedMessages.length <= 1) {
          Future.delayed(const Duration(seconds: 1), () => _showNarrativeTips());
        }
      }
    } catch (e) {
      debugPrint("🚨 StoryScreen Load Error: $e");
      if (mounted) {
        ref.read(isUIReadyProvider.notifier).state = true;
        CustomToast.show(context, "데이터를 불러오는 중 문제가 발생했습니다.", type: ToastType.error);
      }
    }
  }

  void _showNarrativeTips() {
    if (!mounted) return;
    
    final type = widget.initialStory?.narrativeType ?? 'hero';
    final bool isEnsemble = type == 'ensemble';

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) => Material(
        type: MaterialType.transparency,
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A24),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isEnsemble ? Icons.groups_rounded : Icons.person_rounded,
                      color: const Color(0xFF7C3AED),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEnsemble ? "군상극 가이드" : "주인공 모드 가이드",
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  isEnsemble 
                    ? "이 서사에는 고정된 주인공이 없습니다. 당신은 세계의 운명을 결정하는 지휘자입니다."
                    : "당신은 이 이야기의 주인공입니다. 당신의 선택이 운명을 결정합니다.",
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                const Text(
                  "💡 이런 식으로 입력해 보세요:",
                  style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isEnsemble) ...[
                        const _TipItem(text: "장소의 변화: '갑자기 마을에 거대한 폭풍이 몰아친다'"),
                        const _TipItem(text: "사건의 발생: '두 가문 사이에 금지된 사랑이 시작된다'"),
                        const _TipItem(text: "집단 행동: '모든 주민들이 광장에 모여 항의한다'"),
                      ] else ...[
                        const _TipItem(text: "직접적인 행동: '조심스럽게 낡은 문을 열고 들어간다'"),
                        const _TipItem(text: "심리 묘사: '불안한 마음을 감추며 애써 미소 짓는다'"),
                        const _TipItem(text: "대화 시도: '옆에 있는 기사에게 이름을 묻는다'"),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("창작 시작하기", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
        
        final protagonist = characters.firstWhere(
          (c) => c['role_in_story'] == 'protagonist',
          orElse: () => {},
        );
        if (protagonist.isNotEmpty && !present.contains(protagonist['name'])) {
          present.add(protagonist['name']);
        }

        ref.read(presentCharacterNamesProvider.notifier).state = present;
        ref.read(importantCharacterNamesProvider.notifier).state = important;

        ref.read(characterPersistenceProvider.notifier).update((state) {
          final newState = Map<String, int>.from(state);
          newState.updateAll((name, ttl) => ttl - 1);
          for (var name in present) {
            final int ttl = important.contains(name) ? 5 : 3;
            newState[name] = ttl;
          }
          newState.removeWhere((name, ttl) => ttl <= 0);
          return newState;
        });
      }
    } catch (e) {
      debugPrint("🚨 Character Analysis Error: $e");
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

    // 햅틱 피드백 추가
    HapticFeedback.mediumImpact();

    final aiMessageId = DateTime.now().millisecondsSinceEpoch.toString();

    ref.read(messageProvider.notifier).update((state) => [
      ...state,
      {'id': 'user_$aiMessageId', 'role': 'user', 'content': text, 'imageUrl': null},
      {'id': aiMessageId, 'role': 'ai', 'content': '...', 'imageUrl': null, 'sceneType': 'narrative'},
    ]);
    
    _controller.clear();
    _scrollToBottom();

    try {
      String fullResponse = "";
      final stream = _apiService.streamChat(widget.initialStory!.id, text);
      bool isFirstChunk = true;
      ref.read(streamingMessageIdProvider.notifier).state = aiMessageId;
      int lastUpdateTimestamp = DateTime.now().millisecondsSinceEpoch;

      await for (final chunk in stream) {
        if (isFirstChunk) {
          fullResponse = chunk;
          isFirstChunk = false;
        } else {
          fullResponse += chunk;
        }

        final now = DateTime.now().millisecondsSinceEpoch;
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
    final characters = ref.watch(storyCharactersProvider);
    final presentNames = ref.watch(presentCharacterNamesProvider);
    final importantNames = ref.watch(importantCharacterNamesProvider);
    final persistence = ref.watch(characterPersistenceProvider);
    final viewMode = ref.watch(viewModeProvider);
    final bool isMobile = MediaQuery.of(context).size.width < 900; // 넓은 화면 기준 변경

    final visibleCharacters = characters.where((c) {
      final name = c['name'].toString();
      final isProtagonist = c['role_in_story'] == 'protagonist';
      if (isProtagonist) return true;
      return presentNames.any((pn) => name.contains(pn) || pn.contains(name)) ||
             importantNames.any((inm) => name.contains(inm) || inm.contains(name)) ||
             persistence.containsKey(name);
    }).toList();

    return Scaffold(
      backgroundColor: viewMode == StoryViewMode.manuscript ? const Color(0xFF16161D) : const Color(0xFF000000),
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackdrop(backdropUrl, viewMode),
          AnimatedOpacity(
            opacity: isUIReady ? 1.0 : 0.0,
            duration: 800.ms,
            curve: Curves.easeIn,
            child: Row(
              children: [
                // [데스크탑 전용] 사이드 패널
                if (!isMobile && viewMode == StoryViewMode.manuscript)
                  _buildDesktopSidePanel(context, visibleCharacters, importantNames),
                
                Expanded(
                  child: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) => [
                      _buildSliverAppBar(context, innerBoxIsScrolled),
                    ],
                    body: Stack(
                      children: [
                        Column(
                          children: [
                            if (isMobile && viewMode == StoryViewMode.manuscript)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D0D12).withValues(alpha: 0.8),
                                  border: const Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
                                ),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 850),
                                    child: _buildIntegratedCharacterSection(context, visibleCharacters, importantNames),
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 850),
                                  child: ListView.builder(
                                    controller: _scrollController,
                                    padding: EdgeInsets.fromLTRB(
                                      isMobile ? 16 : 24, 20, 
                                      isMobile ? 16 : 24, isMobile ? 180 : 250
                                    ), 
                                    itemCount: messages.length,
                                    cacheExtent: 300,
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
                          ],
                        ),
                        if (viewMode == StoryViewMode.manuscript)
                          Positioned(
                            top: isMobile ? 120 : 150, 
                            left: 0, right: 0, height: 60,
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                    colors: [
                                      (viewMode == StoryViewMode.manuscript ? const Color(0xFF16161D) : Colors.black),
                                      (viewMode == StoryViewMode.manuscript ? const Color(0xFF16161D) : Colors.black).withValues(alpha: 0.5),
                                      Colors.transparent
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isUIReady) _buildFloatingControls(context),
          if (!isUIReady) _buildFullScreenLoading(),
        ],
      ),
    );
  }

  Widget _buildDesktopSidePanel(BuildContext context, List<Map<String, dynamic>> visibleCharacters, List<String> importantNames) {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D12).withValues(alpha: 0.6),
        border: const Border(right: BorderSide(color: Colors.white10, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 80),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "인물 정보",
                  style: GoogleFonts.notoSerif(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  "현재 장면에 등장하거나 중요한 인물들입니다.",
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: visibleCharacters.length,
              itemBuilder: (context, index) {
                final char = visibleCharacters[index];
                final isProtagonist = char['role_in_story'] == 'protagonist';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (context) => CharacterSheetWidget(character: char, isProtagonist: isProtagonist),
                      );
                    },
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundImage: char['image_url'] != null ? CachedNetworkImageProvider(char['image_url']) : null,
                      backgroundColor: Colors.white10,
                      child: char['image_url'] == null ? const Icon(Icons.person, color: Colors.white24) : null,
                    ),
                    title: Text(char['name'], style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: Text(isProtagonist ? "주인공" : "조연", style: TextStyle(color: Colors.white54, fontSize: 11)),
                    trailing: isProtagonist ? const Icon(Icons.star, color: Color(0xFF7C3AED), size: 16) : null,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: Colors.white.withValues(alpha: 0.03),
                  ),
                );
              },
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("AI 어시스턴트", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Consumer(builder: (context, ref, _) {
                  final currentModel = ref.watch(currentStoryModelProvider);
                  return Column(
                    children: [
                      _buildModelToggleOption(ref, "Gemini 2.0 Flash", "빠른 전개", 'google/gemini-2.0-flash-001', currentModel == 'google/gemini-2.0-flash-001'),
                      const SizedBox(height: 12),
                      _buildModelToggleOption(ref, "Gemini 1.5 Pro", "치밀한 묘사", 'google/gemini-pro-1.5', currentModel == 'google/gemini-pro-1.5'),
                    ],
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.05, end: 0);
  }

  Widget _buildIntegratedCharacterSection(BuildContext context, List<Map<String, dynamic>> visibleCharacters, List<String> importantNames) {
    if (visibleCharacters.isEmpty) return const SizedBox(height: 20);
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              const Icon(Icons.people_outline_rounded, color: Color(0xFF7C3AED), size: 16),
              const SizedBox(width: 8),
              Text(
                "현재 현장의 인물들",
                style: GoogleFonts.lato(color: Colors.white.withValues(alpha: 0.4), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
            ],
          ),
        ),
        SizedBox(
          height: isMobile ? 90 : 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: visibleCharacters.length,
            itemBuilder: (context, index) {
              final char = visibleCharacters[index];
              final isProtagonist = char['role_in_story'] == 'protagonist';
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: CharacterCard(
                  name: char['name'],
                  imageUrl: char['image_url'],
                  isProtagonist: isProtagonist,
                  isImportant: importantNames.contains(char['name']),
                  onTap: () => showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (context) => CharacterSheetWidget(character: char, isProtagonist: isProtagonist),
                  ),
                ),
              );
            },
          ),
        ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.02, end: 0),
        Padding(
          padding: EdgeInsets.only(top: isMobile ? 12 : 16, bottom: isMobile ? 12 : 24),
          child: const Divider(color: Colors.white10, height: 1, thickness: 0.5),
        ),
      ],
    );
  }

  Widget _buildFullScreenLoading() => Container(color: const Color(0xFF0D0D12), child: const StoryCreationLoadingWidget());

  Widget _buildSliverAppBar(BuildContext context, bool isScrolled) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final viewMode = ref.watch(viewModeProvider);

    return SliverAppBar(
      expandedHeight: isMobile ? 140.0 : 180.0,
      floating: false, pinned: true,
      backgroundColor: isScrolled ? (viewMode == StoryViewMode.manuscript ? const Color(0xFF0D0D12).withValues(alpha: 0.9) : Colors.black) : Colors.transparent,
      elevation: 0, centerTitle: true,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18), onPressed: () => Navigator.pop(context)),
      actions: [
        IconButton(
          icon: Icon(
            viewMode == StoryViewMode.manuscript ? Icons.visibility_outlined : Icons.edit_note_rounded, 
            color: Colors.white, size: 20
          ), 
          onPressed: () {
            HapticFeedback.lightImpact();
            ref.read(viewModeProvider.notifier).state = 
                viewMode == StoryViewMode.manuscript ? StoryViewMode.focus : StoryViewMode.manuscript;
          },
          tooltip: viewMode == StoryViewMode.manuscript ? "집중 모드" : "원고 모드",
        ),
        IconButton(icon: const Icon(Icons.psychology_rounded, color: Colors.white, size: 20), onPressed: () => _showModelSettings(context), tooltip: "AI 엔진 변경"),
        IconButton(icon: const Icon(Icons.text_fields_rounded, color: Colors.white, size: 20), onPressed: () => _showFontSettings(context), tooltip: "서체 설정"),
        IconButton(icon: const Icon(Icons.history_edu_rounded, color: Colors.white, size: 20), onPressed: () {}),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(bottom: 16),
        centerTitle: true,
        title: isScrolled ? Text(widget.initialStory?.title ?? "Saga", style: GoogleFonts.notoSerif(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold).copyWith(fontFamilyFallback: _fontFallbacks)) : null,
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
            decoration: BoxDecoration(color: const Color(0xFF1A1A24), borderRadius: const BorderRadius.vertical(top: Radius.circular(30)), border: Border.all(color: Colors.white10)),
            child: Column(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("서체 설정", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12, runSpacing: 12,
                  children: availableFonts.map((font) {
                    final isSelected = currentFont == font;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(selectedFontProvider.notifier).state = font;
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(color: isSelected ? const Color(0xFF7C3AED) : Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? Colors.transparent : Colors.white10)),
                        child: Text(font, style: GoogleFonts.getFont(font, color: Colors.white, fontSize: 14)),
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
            decoration: BoxDecoration(color: const Color(0xFF1A1A24), borderRadius: const BorderRadius.vertical(top: Radius.circular(30)), border: Border.all(color: Colors.white10)),
            child: Column(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("AI 스토리 엔진 전환", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text("중요한 장면에서는 더 정교한 Pro 엔진을 사용해 보세요.", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
                const SizedBox(height: 24),
                _buildModelToggleOption(ref, "Gemini 2.0 Flash", "빠르고 가벼운 대화와 전개", 'google/gemini-2.0-flash-001', currentModel == 'google/gemini-2.0-flash-001'),
                const SizedBox(height: 12),
                _buildModelToggleOption(ref, "Gemini 1.5 Pro", "치밀한 묘사와 깊이 있는 서사", 'google/gemini-pro-1.5', currentModel == 'google/gemini-pro-1.5'),
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
          await _apiService.updateStory(widget.initialStory!.id, {'llm_model': modelId});
          ref.read(currentStoryModelProvider.notifier).state = modelId;
          if (mounted) { Navigator.pop(context); CustomToast.show(context, "$title 엔진으로 전환되었습니다."); }
        } catch (e) {
          if (mounted) CustomToast.show(context, "엔진 전환 실패: $e", type: ToastType.error);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: isSelected ? const Color(0xFF7C3AED).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: isSelected ? const Color(0xFF7C3AED) : Colors.white10, width: 1.5)),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, color: isSelected ? const Color(0xFF7C3AED) : Colors.white24, size: 20),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: FontWeight.bold, fontSize: 15)), const SizedBox(height: 2), Text(sub, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12))])),
            if (isSelected) const Icon(Icons.check_circle, color: Color(0xFF7C3AED), size: 20).animate().scale(duration: 200.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarContent() {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      padding: EdgeInsets.only(top: isMobile ? 40 : 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(widget.initialStory?.genre?.toUpperCase() ?? "STORY", style: GoogleFonts.lato(color: const Color(0xFF7C3AED), fontSize: isMobile ? 10 : 11, fontWeight: FontWeight.w900, letterSpacing: isMobile ? 3 : 5)).animate().fadeIn(delay: 300.ms).slideY(begin: 0.5, end: 0),
          const SizedBox(height: 12),
          Padding(padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 40), child: Text(widget.initialStory?.title ?? "Untitled", textAlign: TextAlign.center, style: GoogleFonts.notoSerif(color: Colors.white, fontSize: isMobile ? 24 : 30, fontWeight: FontWeight.bold, height: 1.2)).animate().fadeIn(delay: 500.ms).scale(begin: const Offset(0.95, 0.95))),
          const SizedBox(height: 16),
          Container(width: 40, height: 1, color: Colors.white24),
        ],
      ),
    );
  }

  Widget _buildBackdrop(String? url, StoryViewMode mode) {
    if (mode == StoryViewMode.focus) return const SizedBox.shrink();
    
    final bgColor = mode == StoryViewMode.manuscript ? const Color(0xFF16161D) : const Color(0xFF000000);

    return Positioned.fill(
      child: Container(
        color: bgColor,
        child: url == null 
          ? null 
          : ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: url, 
                    fit: BoxFit.cover, 
                    fadeInDuration: 1.seconds
                  ),
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, 
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.6), 
                            bgColor.withValues(alpha: 0.85), 
                            bgColor
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildFloatingControls(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final viewMode = ref.watch(viewModeProvider);
    final bgColor = viewMode == StoryViewMode.manuscript ? const Color(0xFF16161D) : const Color(0xFF000000);

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(isMobile ? 12 : 20, isMobile ? 12 : 20, isMobile ? 12 : 20, isMobile ? 30 : 40),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter, 
            colors: [
              Colors.transparent, 
              bgColor.withValues(alpha: 0.7), 
              bgColor
            ]
          )
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(35),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08), 
                    borderRadius: BorderRadius.circular(35), 
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12))
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _controller, 
                          style: GoogleFonts.lato(color: Colors.white, fontSize: 15), 
                          decoration: InputDecoration(
                            hintText: "어떻게 행동할까요?", 
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14), 
                            border: InputBorder.none
                          ), 
                          onSubmitted: (_) => _sendMessage()
                        )
                      ),
                      GestureDetector(
                        onTap: _sendMessage, 
                        child: Container(
                          width: 44, height: 44, 
                          decoration: const BoxDecoration(color: Color(0xFF7C3AED), shape: BoxShape.circle), 
                          child: const Icon(Icons.auto_fix_high_rounded, color: Colors.white, size: 20)
                        )
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

class _RefinedNarrativeCard extends ConsumerWidget {
  final Map<String, dynamic> msg;
  const _RefinedNarrativeCard({super.key, required this.msg});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFont = ref.watch(selectedFontProvider);
    final isInitialLoadDone = ref.watch(isInitialLoadDoneProvider);
    final streamingMessageId = ref.watch(streamingMessageIdProvider);
    final viewMode = ref.watch(viewModeProvider);
    final isStreaming = streamingMessageId == msg['id'];
    final isUser = msg['role'] == 'user';
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    
    TextStyle getBaseStyle({double fontSize = 19, FontStyle fontStyle = FontStyle.normal, double height = 2.0}) {
      return GoogleFonts.getFont(
        selectedFont, 
        color: Colors.white.withValues(alpha: 0.92), 
        fontSize: isMobile ? fontSize - 2 : fontSize, 
        height: height, 
        fontStyle: fontStyle, 
        letterSpacing: 0.4
      ).copyWith(fontFamilyFallback: _fontFallbacks);
    }

    if (isUser) {
      if (viewMode == StoryViewMode.focus) return const SizedBox.shrink();

      return RepaintBoundary(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("당신의 행동", style: GoogleFonts.lato(color: const Color(0xFF7C3AED), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.1), borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)), border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3))), child: Text(msg['content'], style: getBaseStyle(fontSize: 16, fontStyle: FontStyle.italic, height: 1.5))),
              ],
            ),
          ),
        ).animate().fadeIn().slideX(begin: 0.05),
      );
    }

    final bool isPlaceholder = msg['content'] == '...';

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg['imageUrl'] != null && viewMode == StoryViewMode.manuscript) 
              Padding(
                padding: const EdgeInsets.only(bottom: 24), 
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24), 
                  child: CachedNetworkImage(
                    imageUrl: msg['imageUrl'], 
                    fit: BoxFit.cover, 
                    memCacheWidth: 800, 
                    placeholder: (context, url) => Container(height: 180, color: Colors.white.withValues(alpha: 0.05))
                  )
                )
              ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0.98, 0.98)),
            
            if (isPlaceholder)
              Shimmer.fromColors(
                baseColor: Colors.white10,
                highlightColor: Colors.white24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: double.infinity, height: 20, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 12),
                    Container(width: double.infinity, height: 20, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 12),
                    Container(width: 200, height: 20, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              )
            else if (isStreaming) 
              Text(msg['content'], style: getBaseStyle()) 
            else if (!isInitialLoadDone)
              WritingEffect(text: msg['content'], style: getBaseStyle())
            else 
              MarkdownBody(
                data: msg['content'], 
                selectable: true, 
                styleSheet: MarkdownStyleSheet(
                  p: getBaseStyle(), 
                  strong: getBaseStyle().copyWith(color: const Color(0xFF7C3AED), fontWeight: FontWeight.bold), 
                  blockquoteDecoration: BoxDecoration(border: const Border(left: BorderSide(color: Color(0xFF7C3AED), width: 4)), color: Colors.white.withValues(alpha: 0.03)), 
                  blockquote: getBaseStyle(fontStyle: FontStyle.italic).copyWith(color: Colors.white.withValues(alpha: 0.7))
                )
              ),
          ],
        ),
      ).animate().fadeIn(duration: isStreaming ? 0.ms : 600.ms),
    );
  }
}

class _TipItem extends StatelessWidget {
  final String text;
  const _TipItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("• ", style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.bold, fontSize: 16)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
