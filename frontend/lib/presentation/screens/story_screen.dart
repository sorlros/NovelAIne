import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_style.dart';
import '../../data/services/api_service.dart';
import '../../data/services/reading_guide_store.dart';
import '../../data/repositories/story_repository.dart';
import 'character_sheet_widget.dart';
import '../widgets/story_markdown.dart';
import '../../data/models/play_models.dart';
import '../../data/models/story_model.dart';
import '../providers/content_provider.dart';
import '../providers/plan_provider.dart';
import '../providers/reading_prefs_provider.dart';
import 'profile/theme_screen.dart';
import '../widgets/character_card.dart';
import '../widgets/custom_loading_indicator.dart';
import '../widgets/custom_toast.dart';
import '../widgets/play_choices_panel.dart';
import '../widgets/reading_guide.dart';
import '../widgets/scene_progress.dart';
import '../widgets/writing_effect.dart';

// 화면 전용 상태 관리
final messageProvider = StateProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => [],
);
final isLoadingProvider = StateProvider.autoDispose<bool>((ref) => false);
final currentBackdropProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final streamingMessageIdProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final isInitialLoadDoneProvider = StateProvider.autoDispose<bool>(
  (ref) => false,
);
final isUIReadyProvider = StateProvider.autoDispose<bool>((ref) => false);

// 캐릭터 관련 상태 추가
final storyCharactersProvider =
    StateProvider.autoDispose<List<Map<String, dynamic>>>((ref) => []);
final presentCharacterNamesProvider = StateProvider.autoDispose<List<String>>(
  (ref) => [],
);
final importantCharacterNamesProvider = StateProvider.autoDispose<List<String>>(
  (ref) => [],
);

// [개선] 캐릭터 등장 지속성 관리를 위한 상태 (이름: 남은 장면 수)
final characterPersistenceProvider =
    StateProvider.autoDispose<Map<String, int>>((ref) => {});

// 현재 이야기의 AI 모델 상태 관리
final currentStoryModelProvider = StateProvider.autoDispose<String>(
  (ref) => AppConstants.defaultLlmModel,
);

// [신규] 원고 모드 vs 집중 모드 상태 관리
enum StoryViewMode { manuscript, focus }

final viewModeProvider = StateProvider.autoDispose<StoryViewMode>(
  (ref) => StoryViewMode.manuscript,
);

// 데이터 변환을 위한 Isolate용 최상단 함수
List<Map<String, dynamic>> _processScenesIsolate(List<dynamic> scenes) {
  return scenes
      .map(
        (scene) => {
          'id':
              scene['id']?.toString() ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          'role': scene['role'] ?? 'ai',
          'content': scene['content'] ?? "",
          'imageUrl': scene['imageUrl'] ?? scene['image_url'],
          'bgmUrl': scene['bgmUrl'] ?? scene['bgm_url'],
          'sceneType': scene['sceneType'] ?? scene['scene_type'] ?? 'narrative',
        },
      )
      .toList();
}

/// Index of the latest scene in [messages] (the reader's moves are not scenes), or null without one.
@visibleForTesting
int? latestSceneIndex(List<Map<String, dynamic>> messages) {
  final index = messages.lastIndexWhere((m) => m['role'] != 'user');
  return index < 0 ? null : index;
}

/// Scroll offset of [position] that puts the list item keyed `ValueKey(id)` at the top of the list,
/// or null while the lazily built list has not built that item.
@visibleForTesting
double? itemTopOffset(ScrollPosition position, String id) {
  final key = ValueKey(id);
  RenderObject? item;
  void visit(Element element) {
    if (item != null) return;
    if (element.widget.key == key) {
      item = element.renderObject;
      return;
    }
    element.visitChildren(visit);
  }

  position.context.notificationContext?.visitChildElements(visit);
  final found = item;
  if (found == null) return null;
  return RenderAbstractViewport.of(found).getOffsetToReveal(found, 0).offset;
}

/// Width of the character panel shown left of the story on wide screens.
const double _sidePanelWidth = 300;

const List<String> _fontFallbacks = [
  'Apple SD Gothic Neo',
  'Malgun Gothic',
  'sans-serif',
];

class StoryScreen extends ConsumerStatefulWidget {
  final StoryModel? initialStory;
  final bool readOnly;

  /// Opened right after the story was created: a first-time reader gets a tour of the screen.
  final bool showGuide;

  const StoryScreen({
    super.key,
    this.initialStory,
    this.readOnly = false,
    this.showGuide = false,
  });

  @override
  ConsumerState<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends ConsumerState<StoryScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ApiService _apiService = ApiService();
  late final AudioPlayer _bgmPlayer;
  StreamSubscription<PlayerState>? _bgmStateSubscription;
  String? _activeBgmUrl;
  String? _loadingBgmSceneId;
  bool _isBgmPlaying = false;
  bool _isSendingMessage = false;
  bool _isInitLoaded = false;

  /// Skeleton stories advance by choices through `/play` instead of free chat.
  late bool _isSkeleton = widget.initialStory?.isSkeleton ?? false;
  PlayStatus? _play;
  bool _playLoadFailed = false;

  /// One timer drives both the preparing and the media-pending re-fetch.
  Timer? _preparingTimer;
  bool _wasMediaPending = false;
  DateTime? _mediaPollStart;
  static const _mediaPollInterval = Duration(seconds: 10);
  static const _mediaPollLimit = Duration(minutes: 10);

  /// Streaming scene the list lifts toward the top, and the offset last set for it.
  String? _risingSceneId;
  double _risingOffset = 0;

  bool _guideChecked = false;
  bool _guideActive = false;

  /// The reader moved the list: no automatic scroll may take them elsewhere.
  bool _readerScrolled = false;
  final _guideSceneKey = GlobalKey();
  final _guideCharactersKey = GlobalKey();
  final _guideViewModeKey = GlobalKey();
  final _guideEngineKey = GlobalKey();
  final _guideFontKey = GlobalKey();
  final _guideChoicesKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _bgmPlayer = AudioPlayer();
    _bgmStateSubscription = _bgmPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _isBgmPlaying = state == PlayerState.playing);
    });
    _preCacheFonts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _preparingTimer?.cancel();
    _bgmStateSubscription?.cancel();
    _bgmPlayer.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _preCacheFonts() {
    for (var font in readingFonts) {
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

      final end = (i + batchSize < allMessages.length)
          ? i + batchSize
          : allMessages.length;
      final batch = allMessages.sublist(i, end);

      ref
          .read(messageProvider.notifier)
          .update((state) => [...state, ...batch]);
      await Future.delayed(const Duration(milliseconds: 16));
    }

    if (mounted) {
      ref.read(isInitialLoadDoneProvider.notifier).state = true;
      _readerScrolled = false;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _isSkeleton ? _scrollToLatestScene() : _scrollToBottom(),
      );
      // The text is laid out again once the web fonts arrive, which moves the scene's start.
      GoogleFonts.pendingFonts().then((_) {
        if (!mounted || !_isSkeleton || _readerScrolled) return;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToLatestScene(),
        );
      });
    }
  }

  Future<void> _loadInitialData() async {
    if (widget.initialStory == null || _isInitLoaded) return;

    final preWarmedCache = ref.read(preWarmedScenesProvider);
    if (preWarmedCache.containsKey(widget.initialStory!.id)) {
      final preWarmedMessages = preWarmedCache[widget.initialStory!.id]!;

      if (mounted) {
        _isInitLoaded = true;
        final lastImage = preWarmedMessages.lastWhere(
          (m) => m['imageUrl'] != null,
          orElse: () => {'imageUrl': null},
        )['imageUrl'];
        if (lastImage != null) {
          ref.read(currentBackdropProvider.notifier).state = lastImage;
        }
        _fetchBackgroundDetails();
        _staggeredLoad(preWarmedMessages);

        // [추가] 첫 진입 시 팁 노출
        if (preWarmedMessages.length <= 1) {
          Future.delayed(
            const Duration(seconds: 1),
            () => _showNarrativeTips(),
          );
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

      _applyStoryDetails(storyData);

      final processedMessages = await compute(_processScenesIsolate, allScenes);

      if (mounted) {
        _isInitLoaded = true;
        final lastImage = processedMessages.lastWhere(
          (m) => m['imageUrl'] != null,
          orElse: () => {'imageUrl': null},
        )['imageUrl'];
        if (lastImage != null) {
          ref.read(currentBackdropProvider.notifier).state = lastImage;
        }

        ref.read(preWarmedScenesProvider.notifier).update((state) {
          final newState = Map<String, List<Map<String, dynamic>>>.from(state);
          newState[widget.initialStory!.id] = processedMessages;
          return newState;
        });
        _staggeredLoad(processedMessages);

        // [추가] 첫 진입 시 팁 노출
        if (processedMessages.length <= 1) {
          Future.delayed(
            const Duration(seconds: 1),
            () => _showNarrativeTips(),
          );
        }
      }
    } catch (e) {
      debugPrint("🚨 StoryScreen Load Error: $e");
      if (mounted) {
        ref.read(isUIReadyProvider.notifier).state = true;
        CustomToast.show(
          context,
          "데이터를 불러오는 중 문제가 발생했습니다.",
          type: ToastType.error,
        );
      }
    }
  }

  void _showNarrativeTips() {
    // The tips are about typing free text; skeleton stories offer choices.
    if (!mounted || _isSkeleton) return;

    final palette = context.palette;
    final style = context.appStyle;
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
            decoration: style.card(palette),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isEnsemble ? Icons.groups_rounded : Icons.person_rounded,
                      color: palette.accent,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEnsemble ? "군상극 가이드" : "주인공 모드 가이드",
                      style: style.title(
                        TextStyle(
                          color: palette.text,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  isEnsemble
                      ? "이 서사에는 고정된 주인공이 없습니다. 당신은 세계의 운명을 결정하는 지휘자입니다."
                      : "당신은 이 이야기의 주인공입니다. 당신의 선택이 운명을 결정합니다.",
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "💡 이런 식으로 입력해 보세요:",
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.raised,
                    borderRadius: BorderRadius.circular(style.radius),
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
                      backgroundColor: style.primary(palette),
                      foregroundColor: style.onPrimary(palette),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(style.radiusSmall),
                        side: style.primaryEdge(palette),
                      ),
                    ),
                    child: const Text(
                      "창작 시작하기",
                      style: TextStyle(fontWeight: FontWeight.bold),
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

  Future<void> _fetchBackgroundDetails() async {
    try {
      final storyData = await _apiService.fetchStory(widget.initialStory!.id);
      if (!mounted) return;
      _applyStoryDetails(storyData);
    } catch (e) {
      debugPrint("Background detail fetch failed: $e");
    }
  }

  void _applyStoryDetails(Map<String, dynamic> storyData) {
    if (storyData['llm_model'] != null) {
      ref.read(currentStoryModelProvider.notifier).state =
          AppConstants.currentLlmModel(storyData['llm_model']);
    }
    final List<dynamic> chars = storyData['characters'] ?? [];
    ref.read(storyCharactersProvider.notifier).state = chars
        .map((c) => Map<String, dynamic>.from(c))
        .toList();
    // The cached story list does not keep the mode, so the server decides.
    if (storyData['mode'] == 'skeleton' && !_isSkeleton) {
      setState(() => _isSkeleton = true);
      // Already scrolled to the end as a chat story: move to the latest scene's start instead.
      if (ref.read(isInitialLoadDoneProvider)) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToLatestScene(),
        );
      }
    }
    if (_isSkeleton && !widget.readOnly) _loadPlay();
  }

  // ---------- skeleton stories ----------

  Future<void> _loadPlay() async {
    _preparingTimer?.cancel();
    try {
      final play = await _apiService.fetchPlay(widget.initialStory!.id);
      if (!mounted) return;
      _applyPlay(play);
    } catch (error) {
      debugPrint("Play status failed: $error");
      if (mounted) setState(() => _playLoadFailed = true);
    }
  }

  void _applyPlay(PlayStatus play) {
    setState(() {
      _play = play;
      _playLoadFailed = false;
    });
    ref.read(presentCharacterNamesProvider.notifier).state =
        play.presentCharacters;
    if (play.preparing) {
      // The server is planning what comes after a major event; ask again shortly.
      _preparingTimer = Timer(const Duration(seconds: 3), _loadPlay);
    } else if (play.mediaPending) {
      final start = _mediaPollStart ??= DateTime.now();
      if (DateTime.now().difference(start) < _mediaPollLimit) {
        _preparingTimer = Timer(_mediaPollInterval, _loadPlay);
      }
    }
    if (!play.mediaPending) _mediaPollStart = null;
    if (_wasMediaPending && !play.mediaPending) _showGeneratedMedia();
    _wasMediaPending = play.mediaPending;
    _maybeShowGuide();
  }

  Future<void> _showGeneratedMedia() async {
    try {
      final before = ref.read(messageProvider);
      final after = await _refreshScenesFromServer(
        replaceMessages: true,
        scroll: false,
      );
      final bgmUrl = newLatestSceneBgm(before, after);
      if (bgmUrl == null || !mounted) return;
      // Autoplay may be blocked by the browser; the button still works then.
      await _bgmPlayer.stop();
      await _toggleBgmPlayback(bgmUrl);
    } catch (error) {
      debugPrint("Generated media refresh failed: $error");
    }
  }

  Future<void> _maybeShowGuide() async {
    if (_guideChecked || !widget.showGuide || widget.readOnly) return;
    _guideChecked = true;
    final store = ReadingGuideStore();
    if (await store.seen()) return;
    // The screen fades in once the scenes are laid out; wait for it.
    for (var i = 0; i < 20 && mounted && !ref.read(isUIReadyProvider); i++) {
      await Future.delayed(const Duration(milliseconds: 300));
    }
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    await store.markSeen();
    setState(() => _guideActive = true);
  }

  List<GuideStep> _guideSteps(bool showsCharacters, bool premium) {
    Future<void> toTop() async {
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    }

    return [
      GuideStep(
        target: _guideSceneKey,
        reveal: toTop,
        // Pictures and music are made for the paid plan only; the free plan is told how to get them.
        text: premium
            ? "이야기는 장면 단위로 이어져요. 이야기가 고조되는 장면에서는 배경 그림과 음악이 자동으로 만들어져요."
            : "이야기는 장면 단위로 이어져요. 이야기가 고조되는 장면에서 배경 그림과 음악이 자동으로 만들어지는 기능은 유료 결제 후 열려요.",
      ),
      if (showsCharacters)
        GuideStep(
          target: _guideCharactersKey,
          reveal: toTop,
          text: "지금 장면의 등장인물이에요. 인물을 누르면 자세한 정보를 볼 수 있어요.",
        ),
      GuideStep(
        target: _guideViewModeKey,
        text: "원고 모드와 집중 모드를 바꿔요. 집중 모드에서는 배경과 인물을 숨기고 본문만 보여요.",
      ),
      GuideStep(
        target: _guideEngineKey,
        text: "장면을 쓰는 엔진을 바꿔요. 바꿔도 이야기는 그대로 이어져요.",
      ),
      GuideStep(target: _guideFontKey, text: "글자 크기와 서체, 줄 간격, 화면 테마를 바꿔요."),
      GuideStep(
        target: _guideChoicesKey,
        // The panel is the last item of a lazily built list: going to the end builds it, and building the
        // items on the way can make the list longer, so go again until the end stays put.
        reveal: () async {
          for (var i = 0; i < 5 && _scrollController.hasClients; i++) {
            final position = _scrollController.position;
            if (i > 0 && position.pixels >= position.maxScrollExtent) break;
            _scrollController.jumpTo(position.maxScrollExtent);
            await WidgetsBinding.instance.endOfFrame;
          }
        },
        text: "장면을 다 읽으면 여기서 다음 행동을 골라요. 원하는 선택지가 없으면 '직접 입력'으로 행동을 써도 돼요.",
      ),
    ];
  }

  void _endGuide() {
    setState(() => _guideActive = false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatestScene());
  }

  void _updateMessage(String messageId, Map<String, dynamic> fields) {
    ref.read(messageProvider.notifier).update((state) {
      return state.map((msg) {
        return msg['id'] == messageId ? {...msg, ...fields} : msg;
      }).toList();
    });
  }

  /// Shows [stream] in the message as it arrives and returns the whole text.
  Future<String> _streamInto(String messageId, Stream<String> stream) async {
    var text = '';
    var lastUpdate = 0;
    await for (final chunk in stream) {
      text += chunk;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastUpdate > 100 && mounted) {
        _updateMessage(messageId, {'content': text});
        lastUpdate = now;
        WidgetsBinding.instance.addPostFrameCallback((_) => _keepSceneRising());
      }
    }
    if (mounted) {
      _updateMessage(messageId, {'content': text});
      WidgetsBinding.instance.addPostFrameCallback((_) => _keepSceneRising());
    }
    return text;
  }

  Future<void> _choose(PlayChoice choice) =>
      _startTurn(label: choice.label, choiceId: choice.id);

  Future<void> _write(String text) => _startTurn(label: text, text: text);

  /// Shows the reader's move and a placeholder scene, then writes the scene.
  /// Exactly one of [choiceId] and [text] is given.
  Future<void> _startTurn({
    required String label,
    String? choiceId,
    String? text,
  }) async {
    if (widget.readOnly || _isSendingMessage) return;
    HapticFeedback.mediumImpact();
    final clientRequestId = const Uuid().v4();
    final aiMessageId = 'ai_$clientRequestId';
    ref
        .read(messageProvider.notifier)
        .update(
          (state) => [
            ...state,
            {
              'id': 'user_$clientRequestId',
              'role': 'user',
              'content': label,
              'imageUrl': null,
            },
            {
              'id': aiMessageId,
              'role': 'ai',
              'content': '...',
              'imageUrl': null,
              'sceneType': 'narrative',
              'clientRequestId': clientRequestId,
              'choiceId': choiceId,
              'inputText': text,
              'streamFailed': false,
            },
          ],
        );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToLatestScene(rising: true),
    );
    await _playTurn(
      aiMessageId,
      clientRequestId,
      choiceId: choiceId,
      text: text,
    );
  }

  /// Writes the scene after the reader's move. Retrying with the same
  /// [clientRequestId] replays a scene the server already saved.
  Future<void> _playTurn(
    String aiMessageId,
    String clientRequestId, {
    String? choiceId,
    String? text,
  }) async {
    final startedAt = _play?.beatSeq;
    setState(() => _isSendingMessage = true);
    ref.read(streamingMessageIdProvider.notifier).state = aiMessageId;
    try {
      await _streamInto(
        aiMessageId,
        _apiService.streamPlay(
          widget.initialStory!.id,
          choiceId: choiceId,
          text: text,
          clientRequestId: clientRequestId,
        ),
      );
      // The reader is reading the new scene: leave the list where it is.
      if (mounted) {
        await _refreshScenesFromServer(replaceMessages: true, scroll: false);
      }
    } catch (error) {
      debugPrint("Play turn failed: $error");
      if (!mounted) return;
      if (await _showServerStory(error, startedAt)) {
        // Nothing of this turn was saved: drop its placeholder and show the server's story.
        await _refreshScenesFromServer(replaceMessages: true);
      } else {
        _updateMessage(aiMessageId, {
          'content': '장면을 쓰지 못했습니다. 다시 시도해 주세요.',
          'streamFailed': true,
        });
      }
      if (mounted) {
        CustomToast.show(
          context,
          ApiException.messageOf(error),
          type: ToastType.error,
        );
      }
    } finally {
      _risingSceneId = null;
      if (mounted) {
        ref.read(streamingMessageIdProvider.notifier).state = null;
        setState(() => _isSendingMessage = false);
        await _loadPlay();
        ref.invalidate(planProvider);
      }
    }
  }

  /// Scenes left today for a free user; null for premium users.
  int? _freeTurnsLeft() {
    final plan = ref.watch(currentPlanProvider);
    return plan.premium ? null : plan.remaining('turn');
  }

  /// Whether a failed turn should give way to the story as the server has it: the request was refused
  /// before anything was written (another turn in progress or lost to, or today's written actions used
  /// up), or it was refused when saving, which arrives as a stream error once the story has moved on.
  Future<bool> _showServerStory(Object error, int? startedAt) async {
    if (error is ApiException &&
        (error.statusCode == 409 || error.statusCode == 429)) {
      return true;
    }
    try {
      final latest = await _apiService.fetchPlay(widget.initialStory!.id);
      return latest.beatSeq != startedAt;
    } catch (_) {
      return false;
    }
  }

  static bool _isPlayMessage(Map<String, dynamic> message) =>
      message['choiceId'] != null || message['inputText'] != null;

  Future<void> _retryTurn(Map<String, dynamic> failedMessage) async {
    if (_isSendingMessage) return;
    final aiMessageId = failedMessage['id'].toString();
    _updateMessage(aiMessageId, {'content': '...', 'streamFailed': false});
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToLatestScene(rising: true),
    );
    await _playTurn(
      aiMessageId,
      failedMessage['clientRequestId'].toString(),
      choiceId: failedMessage['choiceId']?.toString(),
      text: failedMessage['inputText']?.toString(),
    );
  }

  Future<void> _undo() async {
    if (_isSendingMessage) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('직전 선택을 되돌릴까요?'),
        content: const Text('마지막 장면이 지워지고 그 전의 선택지로 돌아갑니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('되돌리기'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isSendingMessage = true);
    try {
      final play = await _apiService.undoPlay(widget.initialStory!.id);
      if (!mounted) return;
      await _refreshScenesFromServer(replaceMessages: true);
      if (mounted) _applyPlay(play);
    } catch (error) {
      if (mounted) {
        CustomToast.show(
          context,
          ApiException.messageOf(error),
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingMessage = false);
    }
  }

  Future<void> _analyzeCharacters(String content) async {
    if (widget.initialStory == null || content.isEmpty || content == "...") {
      return;
    }

    var characters = ref.read(storyCharactersProvider);
    if (characters.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 500));
      characters = ref.read(storyCharactersProvider);
      if (characters.isEmpty) return;
    }

    final charNames = characters.map((c) => c['name'].toString()).toList();

    try {
      final analysis = await _apiService.analyzeScene(
        widget.initialStory!.id,
        content,
        charNames,
      );

      if (mounted) {
        final List<String> present = List<String>.from(
          analysis['present_characters'] ?? [],
        );
        final List<String> important = List<String>.from(
          analysis['important_characters'] ?? [],
        );

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

  /// Puts the start of the latest scene at the top of the list: a skeleton story is read from a
  /// scene's start. With [rising], a scene still too short to reach the top keeps rising as it streams in.
  void _scrollToLatestScene({bool rising = false}) {
    _risingSceneId = null;
    final messages = ref.read(messageProvider);
    final index = latestSceneIndex(messages);
    if (index == null) return;
    _revealScene(messages[index]['id'].toString(), rising: rising, tries: 4);
  }

  void _revealScene(String id, {required bool rising, required int tries}) {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final top = itemTopOffset(position, id);
    if (top == null) {
      if (tries == 0) return;
      // The list builds items lazily: go to the end, then further up, until the scene is built.
      final atEnd = position.pixels >= position.maxScrollExtent;
      _scrollController.jumpTo(
        atEnd
            ? math.max(0, position.pixels - position.viewportDimension)
            : position.maxScrollExtent,
      );
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _revealScene(id, rising: rising, tries: tries - 1),
      );
      return;
    }
    final target = math.min(top, position.maxScrollExtent);
    _scrollController.jumpTo(target);
    if (rising && top > target) {
      _risingSceneId = id;
      _risingOffset = target;
    }
  }

  /// Lifts the streaming scene toward the top as it grows, until it gets there or the reader scrolls.
  void _keepSceneRising() {
    final id = _risingSceneId;
    if (id == null || !mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final top = itemTopOffset(position, id);
    // Scrolled up by the reader, scrolled past the scene's start, or the scene is gone: stop.
    if (top == null ||
        position.pixels < _risingOffset - 1 ||
        position.pixels >= top - 1) {
      _risingSceneId = null;
      return;
    }
    final target = math.min(top, position.maxScrollExtent);
    if (target > position.pixels) _scrollController.jumpTo(target);
    _risingOffset = target;
    if (top <= target) _risingSceneId = null;
  }

  Future<List<Map<String, dynamic>>> _refreshScenesFromServer({
    bool replaceMessages = false,
    bool scroll = true,
  }) async {
    if (widget.initialStory == null) return [];

    final repository = ref.read(storyRepositoryProvider);
    final refreshedScenes = await repository.getScenes(
      widget.initialStory!.id,
      forceRefresh: true,
    );
    ref.read(preWarmedScenesProvider.notifier).update((state) {
      final newState = Map<String, List<Map<String, dynamic>>>.from(state);
      newState[widget.initialStory!.id] = refreshedScenes;
      return newState;
    });

    if (replaceMessages && mounted) {
      ref.read(messageProvider.notifier).state = refreshedScenes;
      final lastImage = refreshedScenes.lastWhere(
        (m) => m['imageUrl'] != null,
        orElse: () => {'imageUrl': null},
      )['imageUrl'];
      if (lastImage != null) {
        ref.read(currentBackdropProvider.notifier).state = lastImage;
      }
      if (scroll) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _isSkeleton ? _scrollToLatestScene() : _scrollToBottom(),
        );
      }
    }

    return refreshedScenes;
  }

  Future<void> _toggleBgmPlayback(String bgmUrl) async {
    if (_activeBgmUrl == bgmUrl && _isBgmPlaying) {
      await _bgmPlayer.pause();
      return;
    }

    if (_activeBgmUrl == bgmUrl && !_isBgmPlaying) {
      await _bgmPlayer.resume();
      return;
    }

    await _bgmPlayer.stop();
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer.setVolume(0.55);
    await _bgmPlayer.play(UrlSource(bgmUrl));
    if (mounted) {
      setState(() {
        _activeBgmUrl = bgmUrl;
        _isBgmPlaying = true;
      });
    }
  }

  Future<void> _handleBgmAction(Map<String, dynamic> msg) async {
    final existingUrl = msg['bgmUrl']?.toString();
    if (existingUrl != null && existingUrl.isNotEmpty) {
      try {
        await _toggleBgmPlayback(existingUrl);
      } catch (error) {
        if (mounted) {
          CustomToast.show(context, "오디오를 재생하지 못했습니다.", type: ToastType.error);
        }
      }
      return;
    }

    if (widget.readOnly) {
      CustomToast.show(context, "공개 작품은 BGM을 새로 생성할 수 없습니다.");
      return;
    }

    final sceneId = msg['id']?.toString();
    if (sceneId == null || sceneId.startsWith('user_')) {
      CustomToast.show(context, "저장된 장면에서만 BGM을 생성할 수 있습니다.");
      return;
    }

    setState(() => _loadingBgmSceneId = sceneId);
    try {
      final scene = await _apiService.generateSceneBgm(
        storyId: widget.initialStory!.id,
        sceneId: sceneId,
        prompt: msg['content']?.toString(),
      );
      final bgmUrl = scene['bgm_url'] ?? scene['bgmUrl'];
      if (bgmUrl == null || bgmUrl.toString().isEmpty) {
        throw Exception("BGM URL is empty");
      }

      ref.read(messageProvider.notifier).update((state) {
        return state.map((item) {
          if (item['id'] == sceneId) {
            return {...item, 'bgmUrl': bgmUrl};
          }
          return item;
        }).toList();
      });
      await _refreshScenesFromServer();
      await _toggleBgmPlayback(bgmUrl.toString());
    } catch (error) {
      if (mounted) {
        CustomToast.show(
          context,
          "BGM 생성에 실패했습니다. 잠시 후 다시 시도해주세요.",
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loadingBgmSceneId = null);
    }
  }

  Future<void> _sendMessage() async {
    if (widget.readOnly) {
      CustomToast.show(context, "공개 작품은 읽기 전용입니다.");
      return;
    }
    if (_isSendingMessage) {
      CustomToast.show(context, "이전 응답을 생성 중입니다.");
      return;
    }
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSendingMessage = true);

    HapticFeedback.mediumImpact();

    final clientRequestId = const Uuid().v4();
    final aiMessageId = 'ai_$clientRequestId';

    ref
        .read(messageProvider.notifier)
        .update(
          (state) => [
            ...state,
            {
              'id': 'user_$clientRequestId',
              'role': 'user',
              'content': text,
              'imageUrl': null,
              'clientRequestId': clientRequestId,
            },
            {
              'id': aiMessageId,
              'role': 'ai',
              'content': '...',
              'imageUrl': null,
              'sceneType': 'narrative',
              'clientRequestId': clientRequestId,
              'userMessage': text,
              'streamFailed': false,
            },
          ],
        );

    _controller.clear();
    _scrollToBottom();

    try {
      String fullResponse = "";
      final stream = _apiService.streamChat(
        widget.initialStory!.id,
        text,
        clientRequestId: clientRequestId,
      );
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
              if (msg['id'] == aiMessageId) {
                return {...msg, 'content': fullResponse};
              }
              return msg;
            }).toList();
          });
          lastUpdateTimestamp = now;
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          }
        }
      }

      ref.read(messageProvider.notifier).update((state) {
        return state.map((msg) {
          if (msg['id'] == aiMessageId) {
            return {...msg, 'content': fullResponse};
          }
          return msg;
        }).toList();
      });

      ref.read(streamingMessageIdProvider.notifier).state = null;
      _analyzeCharacters(fullResponse);

      if (widget.initialStory != null) {
        await _refreshScenesFromServer(replaceMessages: true);
      }
    } catch (e) {
      debugPrint("🚨 Stream Error: $e");
      ref.read(messageProvider.notifier).update((state) {
        return state.map((msg) {
          if (msg['id'] == aiMessageId) {
            return {
              ...msg,
              'content': '응답 생성 중 문제가 발생했습니다. 응답 복구를 시도해 주세요.',
              'streamFailed': true,
              'userMessage': text,
            };
          }
          return msg;
        }).toList();
      });
      if (mounted) {
        CustomToast.show(
          context,
          e is ApiException ? e.message : "응답 생성에 실패했습니다.",
          type: ToastType.error,
        );
      }
    } finally {
      ref.read(streamingMessageIdProvider.notifier).state = null;
      if (mounted) setState(() => _isSendingMessage = false);
    }
  }

  Future<void> _recoverStreamMessage(Map<String, dynamic> failedMessage) async {
    if (_isPlayMessage(failedMessage)) return _retryTurn(failedMessage);
    if (_isSendingMessage) {
      CustomToast.show(context, "이전 응답을 생성 중입니다.");
      return;
    }
    final clientRequestId = failedMessage['clientRequestId']?.toString();
    final userMessage = failedMessage['userMessage']?.toString();
    final aiMessageId = failedMessage['id']?.toString();
    if (clientRequestId == null ||
        clientRequestId.isEmpty ||
        userMessage == null ||
        userMessage.isEmpty ||
        aiMessageId == null ||
        aiMessageId.isEmpty ||
        widget.initialStory == null) {
      CustomToast.show(context, "복구할 요청 정보를 찾을 수 없습니다.", type: ToastType.error);
      return;
    }

    setState(() => _isSendingMessage = true);
    ref.read(streamingMessageIdProvider.notifier).state = aiMessageId;
    ref.read(messageProvider.notifier).update((state) {
      return state.map((msg) {
        if (msg['id'] == aiMessageId) {
          return {...msg, 'content': '...', 'streamFailed': false};
        }
        return msg;
      }).toList();
    });

    try {
      String fullResponse = "";
      int lastUpdateTimestamp = DateTime.now().millisecondsSinceEpoch;
      await for (final chunk in _apiService.streamChat(
        widget.initialStory!.id,
        userMessage,
        clientRequestId: clientRequestId,
      )) {
        fullResponse += chunk;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastUpdateTimestamp > 100) {
          ref.read(messageProvider.notifier).update((state) {
            return state.map((msg) {
              if (msg['id'] == aiMessageId) {
                return {...msg, 'content': fullResponse};
              }
              return msg;
            }).toList();
          });
          lastUpdateTimestamp = now;
        }
      }

      ref.read(messageProvider.notifier).update((state) {
        return state.map((msg) {
          if (msg['id'] == aiMessageId) {
            return {...msg, 'content': fullResponse, 'streamFailed': false};
          }
          return msg;
        }).toList();
      });
      _analyzeCharacters(fullResponse);
      await _refreshScenesFromServer(replaceMessages: true);
    } catch (error) {
      debugPrint("Stream recovery failed: $error");
      ref.read(messageProvider.notifier).update((state) {
        return state.map((msg) {
          if (msg['id'] == aiMessageId) {
            return {
              ...msg,
              'content': '응답 복구에 실패했습니다. 잠시 후 다시 시도해 주세요.',
              'streamFailed': true,
            };
          }
          return msg;
        }).toList();
      });
      if (mounted) {
        CustomToast.show(context, "응답 복구에 실패했습니다.", type: ToastType.error);
      }
    } finally {
      ref.read(streamingMessageIdProvider.notifier).state = null;
      if (mounted) setState(() => _isSendingMessage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final messages = ref.watch(messageProvider);
    final isUIReady = ref.watch(isUIReadyProvider);
    // Keeps the auto-disposed flag alive: while no scene card is built it would reset, and every card
    // would play the typing effect again.
    ref.watch(isInitialLoadDoneProvider);
    final backdropUrl = ref.watch(currentBackdropProvider);
    final characters = ref.watch(storyCharactersProvider);
    final presentNames = ref.watch(presentCharacterNamesProvider);
    final importantNames = ref.watch(importantCharacterNamesProvider);
    final persistence = ref.watch(characterPersistenceProvider);
    final viewMode = ref.watch(viewModeProvider);
    final isSending =
        _isSendingMessage || ref.watch(streamingMessageIdProvider) != null;
    final bool isMobile =
        MediaQuery.of(context).size.width < AppConstants.desktopBreakpoint;

    final visibleCharacters = characters.where((c) {
      final name = c['name'].toString();
      final isProtagonist = c['role_in_story'] == 'protagonist';
      if (isProtagonist) return true;
      return presentNames.any((pn) => name.contains(pn) || pn.contains(name)) ||
          importantNames.any(
            (inm) => name.contains(inm) || inm.contains(name),
          ) ||
          persistence.containsKey(name);
    }).toList();

    return Scaffold(
      backgroundColor: palette.ground,
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
                Expanded(
                  child: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) => [
                      _buildSliverAppBar(context, innerBoxIsScrolled),
                    ],
                    body: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 850),
                        child: NotificationListener<UserScrollNotification>(
                          onNotification: (notification) {
                            if (notification.direction !=
                                ScrollDirection.idle) {
                              _readerScrolled = true;
                            }
                            return false;
                          },
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.fromLTRB(
                              isMobile ? 16 : 24,
                              20,
                              isMobile ? 16 : 24,
                              _isSkeleton
                                  ? 40 + MediaQuery.of(context).padding.bottom
                                  : (isMobile ? 180 : 250),
                            ),
                            itemCount:
                                messages.length +
                                1 + // +1 for the character section header
                                (_isSkeleton
                                    ? 1
                                    : 0), // choices panel at the end
                            // ignore: deprecated_member_use
                            cacheExtent: 300,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                // Integrated Character Section as the first item in the list
                                if (isMobile &&
                                    viewMode == StoryViewMode.manuscript) {
                                  return KeyedSubtree(
                                    key: _guideCharactersKey,
                                    child: _buildIntegratedCharacterSection(
                                      context,
                                      visibleCharacters,
                                      importantNames,
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              }

                              if (_isSkeleton && index == messages.length + 1) {
                                return Padding(
                                  key: _guideChoicesKey,
                                  padding: const EdgeInsets.only(top: 8),
                                  child: PlayChoicesPanel(
                                    status: _play,
                                    busy: isSending,
                                    loadFailed: _playLoadFailed,
                                    remainingTurns: _freeTurnsLeft(),
                                    turnLimit:
                                        ref
                                            .watch(currentPlanProvider)
                                            .limits['turn'] ??
                                        10,
                                    onChoose: _choose,
                                    onWrite: _write,
                                    onUndo: _undo,
                                    onReload: _loadPlay,
                                  ),
                                );
                              }

                              final msg = messages[index - 1];
                              final card = _RefinedNarrativeCard(
                                key: ValueKey(msg['id'].toString()),
                                msg: msg,
                                activeBgmUrl: _activeBgmUrl,
                                isBgmPlaying: _isBgmPlaying,
                                loadingBgmSceneId: _loadingBgmSceneId,
                                canGenerateBgm:
                                    !widget.readOnly &&
                                    !_isSkeleton &&
                                    ref.watch(currentPlanProvider).premium,
                                onBgmPressed: _handleBgmAction,
                                onRetryPressed: _recoverStreamMessage,
                              );
                              // The opening scene, lit by the first-time guide.
                              return index == 1
                                  ? KeyedSubtree(
                                      key: _guideSceneKey,
                                      child: card,
                                    )
                                  : card;
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // [데스크탑 전용] 오른쪽 패널
                if (!isMobile && viewMode == StoryViewMode.manuscript)
                  KeyedSubtree(
                    key: _guideCharactersKey,
                    child: _buildDesktopSidePanel(
                      context,
                      visibleCharacters,
                      importantNames,
                    ),
                  ),
              ],
            ),
          ),
          if (isUIReady && !widget.readOnly && !_isSkeleton)
            _buildFloatingControls(context),
          if (!isUIReady) _buildFullScreenLoading(),
          if (_guideActive)
            Positioned.fill(
              child: ReadingGuide(
                steps: _guideSteps(
                  viewMode == StoryViewMode.manuscript &&
                      visibleCharacters.isNotEmpty,
                  ref.watch(currentPlanProvider).premium,
                ),
                onDone: _endGuide,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopSidePanel(
    BuildContext context,
    List<Map<String, dynamic>> visibleCharacters,
    List<String> importantNames,
  ) {
    final palette = context.palette;
    final style = context.appStyle;
    final prefs = ref.watch(readingPrefsProvider);
    final lastingSteps = _isSkeleton
        ? (_play?.path.where((step) => step.lasting).toList() ??
              const <PlayStep>[])
        : const <PlayStep>[];

    Widget section(String title, Widget child, {bool first = false}) {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          border: style.isPaper && !first
              ? Border(top: BorderSide(color: palette.text, width: 2))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: style.title(
                TextStyle(
                  color: palette.text,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
    }

    Widget avatar(Map<String, dynamic> char) {
      final image = char['image_url'];
      final shape = style.isNight ? BoxShape.circle : BoxShape.rectangle;
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: shape,
          borderRadius: style.isNight
              ? null
              : BorderRadius.circular(style.radiusSmall),
          color: palette.line,
          image: image != null
              ? DecorationImage(
                  image: CachedNetworkImageProvider(image),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: image == null ? Icon(Icons.person, color: palette.faint) : null,
      );
    }

    Widget sizeButton(String text, int delta) {
      final next = prefs.sizeStep + delta;
      final enabled = next >= 0 && next < ReadingPrefs.sizes.length;
      return Expanded(
        child: GestureDetector(
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  ref
                      .read(readingPrefsProvider.notifier)
                      .set(prefs.copyWith(sizeStep: next));
                }
              : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: style.control(palette, selected: false),
              child: Text(
                text,
                style: TextStyle(
                  color: style.onControl(palette, selected: false),
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final decoration = switch (style.kind) {
      StyleKind.night => BoxDecoration(
        color: palette.surface,
        border: Border(left: BorderSide(color: palette.line, width: 1)),
      ),
      StyleKind.paper => BoxDecoration(
        border: Border(left: BorderSide(color: palette.line, width: 1)),
      ),
      StyleKind.route => BoxDecoration(
        color: palette.surface,
        border: Border(left: BorderSide(color: palette.text, width: 2)),
      ),
    };

    return Container(
      width: _sidePanelWidth,
      decoration: decoration,
      child: ListView(
        padding: const EdgeInsets.only(top: 80, bottom: 100),
        children: [
          section(
            "이 장면의 인물",
            Column(
              children: [
                if (visibleCharacters.isEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "아직 없습니다.",
                      style: TextStyle(color: palette.muted, fontSize: 12),
                    ),
                  ),
                for (final char in visibleCharacters)
                  Builder(
                    builder: (context) {
                      final isProtagonist =
                          char['role_in_story'] == 'protagonist';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder: (context) => CharacterSheetWidget(
                              character: char,
                              isProtagonist: isProtagonist,
                            ),
                          );
                        },
                        leading: avatar(char),
                        title: Text(
                          char['name'],
                          style: TextStyle(
                            color: palette.text,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          isProtagonist ? "주인공" : "조연",
                          style: TextStyle(color: palette.muted, fontSize: 11),
                        ),
                        trailing: isProtagonist
                            ? Icon(Icons.star, color: palette.accent, size: 16)
                            : null,
                      );
                    },
                  ),
              ],
            ),
            first: true,
          ),
          if (_isSkeleton)
            section(
              "이야기에 남은 선택",
              lastingSteps.isEmpty
                  ? Text(
                      "아직 없습니다.",
                      style: TextStyle(color: palette.muted, fontSize: 12),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final step in lastingSteps)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "장면 ${step.seq}",
                                  style: TextStyle(
                                    color: palette.accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  step.label,
                                  style: TextStyle(
                                    color: palette.text,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          section(
            "보기",
            Row(
              children: [
                sizeButton("글자 작게", -1),
                const SizedBox(width: 8),
                sizeButton("글자 크게", 1),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.05, end: 0);
  }

  Widget _buildIntegratedCharacterSection(
    BuildContext context,
    List<Map<String, dynamic>> visibleCharacters,
    List<String> importantNames,
  ) {
    if (visibleCharacters.isEmpty) return const SizedBox(height: 20);
    final palette = context.palette;
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(
                Icons.people_outline_rounded,
                color: palette.accent,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                "현재 현장의 인물들",
                style: GoogleFonts.lato(
                  color: palette.faint,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
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
                    builder: (context) => CharacterSheetWidget(
                      character: char,
                      isProtagonist: isProtagonist,
                    ),
                  ),
                ),
              );
            },
          ),
        ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.02, end: 0),
        Padding(
          padding: EdgeInsets.only(
            top: isMobile ? 12 : 16,
            bottom: isMobile ? 12 : 24,
          ),
          child: Divider(color: palette.line, height: 1, thickness: 0.5),
        ),
      ],
    );
  }

  Widget _buildFullScreenLoading() => Container(
    color: context.palette.ground,
    child: const StoryCreationLoadingWidget(),
  );

  Widget _buildSliverAppBar(BuildContext context, bool isScrolled) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final viewMode = ref.watch(viewModeProvider);
    final palette = context.palette;
    final style = context.appStyle;
    // The expanded bar is an accent band on the route style, a dimmed scene picture at night.
    final onBand = style.isRoute && !isScrolled;
    final overPicture =
        style.isNight &&
        !isScrolled &&
        ref.watch(currentBackdropProvider) != null;
    final Color iconColor = onBand
        ? palette.onAccent
        : overPicture
        ? Colors.white
        : palette.text;

    return SliverAppBar(
      expandedHeight: isMobile ? 164.0 : 200.0,
      floating: false,
      pinned: true,
      // Opaque: the scenes scroll in their own list, so innerBoxIsScrolled stays false and a clear bar
      // would let the text show through the collapsed toolbar.
      backgroundColor: onBand
          ? palette.accent
          : isScrolled && viewMode == StoryViewMode.manuscript
          ? palette.surface
          : palette.ground,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: iconColor,
          size: 18,
        ),
        onPressed: () => Navigator.pop(context),
        tooltip: '뒤로',
      ),
      actions: [
        IconButton(
          key: _guideViewModeKey,
          icon: Icon(
            viewMode == StoryViewMode.manuscript
                ? Icons.visibility_outlined
                : Icons.edit_note_rounded,
            color: iconColor,
            size: 20,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            ref
                .read(viewModeProvider.notifier)
                .state = viewMode == StoryViewMode.manuscript
                ? StoryViewMode.focus
                : StoryViewMode.manuscript;
          },
          tooltip: viewMode == StoryViewMode.manuscript ? "집중 모드" : "원고 모드",
        ),
        IconButton(
          key: _guideEngineKey,
          icon: Icon(Icons.psychology_rounded, color: iconColor, size: 20),
          onPressed: () => _showModelSettings(context),
          tooltip: "글 쓰는 엔진",
        ),
        IconButton(
          key: _guideFontKey,
          icon: Text(
            "가",
            style: GoogleFonts.notoSerif(
              color: iconColor,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          onPressed: () => _showViewSettings(context),
          tooltip: "보기 설정",
        ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(bottom: 16),
        centerTitle: true,
        title: isScrolled
            ? Text(
                widget.initialStory?.title ?? "Saga",
                style: style
                    .title(
                      GoogleFonts.notoSerif(
                        color: palette.text,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                    .copyWith(fontFamilyFallback: _fontFallbacks),
              )
            : null,
        background: _buildAppBarContent(onBand: onBand),
      ),
    );
  }

  void _showViewSettings(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          final prefs = ref.watch(readingPrefsProvider);
          void change(ReadingPrefs next) {
            HapticFeedback.selectionClick();
            ref.read(readingPrefsProvider.notifier).set(next);
          }

          Widget label(String text) => Padding(
            padding: const EdgeInsets.only(top: 22, bottom: 10),
            child: Text(
              text,
              style: TextStyle(
                color: palette.muted,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          );

          Widget segments(
            List<String> labels,
            int selected,
            ValueChanged<int> onPick,
          ) {
            return Row(
              children: [
                for (var i = 0; i < labels.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onPick(i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: style.control(
                          palette,
                          selected: i == selected,
                        ),
                        child: Text(
                          labels[i],
                          style: TextStyle(
                            color: style.onControl(
                              palette,
                              selected: i == selected,
                            ),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          }

          return SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(style.radiusLarge),
                ),
                border: Border.all(
                  color: style.edge(palette),
                  width: style.borderWidth,
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "보기 설정",
                      style: style.title(
                        TextStyle(
                          color: palette.text,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    label("서체"),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: readingFonts.map((font) {
                        final isSelected = prefs.font == font;
                        return GestureDetector(
                          onTap: () => change(prefs.copyWith(font: font)),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: style.control(
                              palette,
                              selected: isSelected,
                            ),
                            child: Text(
                              font,
                              style: GoogleFonts.getFont(
                                font,
                                color: style.onControl(
                                  palette,
                                  selected: isSelected,
                                ),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    label("글자 크기"),
                    segments(
                      ReadingPrefs.sizeLabels,
                      prefs.sizeStep,
                      (i) => change(prefs.copyWith(sizeStep: i)),
                    ),
                    label("줄 간격"),
                    segments(
                      ReadingPrefs.spacingLabels,
                      prefs.spacingStep,
                      (i) => change(prefs.copyWith(spacingStep: i)),
                    ),
                    const SizedBox(height: 18),
                    Divider(color: palette.line, height: 1),
                    InkWell(
                      onTap: () {
                        Navigator.pop(sheetContext);
                        Navigator.of(this.context).push(
                          MaterialPageRoute(
                            builder: (_) => const ThemeScreen(),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                "화면 테마",
                                style: TextStyle(
                                  color: palette.text,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: palette.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showModelSettings(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final currentModel = ref.watch(currentStoryModelProvider);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(style.radiusLarge),
              ),
              border: Border.all(
                color: style.edge(palette),
                width: style.borderWidth,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "글 쓰는 엔진",
                  style: style.title(
                    TextStyle(
                      color: palette.text,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "중요한 장면에서는 더 정교한 고급 엔진을 써 보세요.",
                  style: TextStyle(color: palette.muted, fontSize: 13),
                ),
                const SizedBox(height: 24),
                _buildModelToggleOption(
                  ref,
                  "기본 엔진",
                  "빠르고 가벼운 대화와 전개",
                  AppConstants.defaultLlmModel,
                  currentModel == AppConstants.defaultLlmModel,
                  closesSheet: true,
                ),
                const SizedBox(height: 12),
                _buildModelToggleOption(
                  ref,
                  "고급 엔진",
                  "치밀한 묘사와 깊이 있는 서사",
                  AppConstants.proLlmModel,
                  currentModel == AppConstants.proLlmModel,
                  closesSheet: true,
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildModelToggleOption(
    WidgetRef ref,
    String title,
    String sub,
    String modelId,
    bool isSelected, {
    bool closesSheet = false,
  }) {
    final palette = context.palette;
    final style = context.appStyle;
    final locked = ref.watch(currentPlanProvider).locks(modelId);
    return GestureDetector(
      onTap: () async {
        if (isSelected) return;
        if (ref.read(currentPlanProvider).locks(modelId)) {
          CustomToast.show(
            context,
            AppConstants.premiumOnlyMessage,
            type: ToastType.error,
          );
          return;
        }
        try {
          await _apiService.updateStory(widget.initialStory!.id, {
            'llm_model': modelId,
          });
          ref.read(currentStoryModelProvider.notifier).state = modelId;
          if (mounted) {
            // Only the bottom sheet closes; the side panel's copy must not close the story.
            if (closesSheet) Navigator.pop(context);
            CustomToast.show(context, "$title으로 바꿨습니다.");
          }
        } catch (e) {
          if (mounted) {
            CustomToast.show(
              context,
              e is ApiException ? e.message : "엔진 전환 실패: $e",
              type: ToastType.error,
            );
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: style.control(palette, selected: isSelected),
        child: Row(
          children: [
            Icon(
              locked ? Icons.lock : Icons.auto_awesome,
              color: isSelected
                  ? style.onControl(palette, selected: true)
                  : palette.faint,
              size: 20,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected
                          ? style.onControl(palette, selected: true)
                          : palette.muted,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    locked ? "유료" : sub,
                    style: TextStyle(
                      color: isSelected && !style.isNight
                          ? style.onControl(palette, selected: true)
                          : palette.faint,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: style.isNight
                    ? palette.accent
                    : style.onControl(palette, selected: true),
                size: 20,
              ).animate().scale(duration: 200.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarContent({required bool onBand}) {
    final palette = context.palette;
    final style = context.appStyle;
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final backdropUrl = ref.watch(currentBackdropProvider);
    final messages = ref.watch(messageProvider);
    final bool overPicture = style.isNight && backdropUrl != null;

    // Scenes are the AI messages counted from 1; those with a picture light the progress strip.
    var scenes = 0;
    final pictured = <int>{};
    for (final m in messages) {
      if (m['role'] == 'user') continue;
      scenes++;
      final image = m['imageUrl'];
      if (image != null && image.toString().isNotEmpty) pictured.add(scenes);
    }
    final current = _isSkeleton ? (_play?.beatSeq ?? 1) : scenes;

    final Color genreColor = onBand
        ? palette.onAccent
        : overPicture
        ? Colors.white
        : palette.accent;
    final Color titleColor = onBand
        ? palette.onAccent
        : overPicture
        ? Colors.white
        : palette.text;

    final content = Container(
      padding: EdgeInsets.only(top: isMobile ? 40 : 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.initialStory?.genre.toUpperCase() ?? "STORY",
            style: GoogleFonts.lato(
              color: genreColor,
              fontSize: isMobile ? 10 : 11,
              fontWeight: FontWeight.w900,
              letterSpacing: isMobile ? 3 : 5,
            ),
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.5, end: 0),
          const SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 40),
            child:
                Text(
                      widget.initialStory?.title ?? "Untitled",
                      textAlign: TextAlign.center,
                      style: style.title(
                        GoogleFonts.notoSerif(
                          color: titleColor,
                          fontSize: isMobile ? 24 : 30,
                          fontWeight: style.isPaper
                              ? FontWeight.w900
                              : FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 500.ms)
                    .scale(begin: const Offset(0.95, 0.95)),
          ),
          const SizedBox(height: 14),
          SceneProgress(
            current: current < 1 ? 1 : current,
            pictured: pictured,
            lasting: _play?.lastingSeqs ?? const {},
            onBand: onBand,
          ),
        ],
      ),
    );
    if (!overPicture) return content;
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: backdropUrl,
          fit: BoxFit.cover,
          errorWidget: (context, url, error) => const SizedBox.shrink(),
        ),
        // Darkens the picture so the white title stays readable.
        Container(color: Colors.black.withValues(alpha: 0.6)),
        content,
      ],
    );
  }

  Widget _buildBackdrop(String? url, StoryViewMode mode) {
    if (mode == StoryViewMode.focus) return const SizedBox.shrink();

    return Positioned.fill(child: Container(color: context.palette.ground));
  }

  Widget _buildFloatingControls(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final palette = context.palette;
    final style = context.appStyle;
    final isSending =
        _isSendingMessage || ref.watch(streamingMessageIdProvider) != null;
    final bgColor = palette.ground;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          isMobile ? 12 : 20,
          isMobile ? 12 : 20,
          isMobile ? 12 : 20,
          isMobile ? 30 : 40,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              bgColor.withValues(alpha: 0.8),
              bgColor,
            ],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: palette.raised,
                borderRadius: BorderRadius.circular(
                  style.isNight ? 35 : style.radius,
                ),
                border: Border.all(
                  color: style.edge(palette),
                  width: style.borderWidth,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: GoogleFonts.lato(
                        color: palette.text,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: isSending ? "응답 생성 중..." : "어떻게 행동할까요?",
                        hintStyle: TextStyle(
                          color: palette.faint,
                          fontSize: 14,
                        ),
                        // The bar around the field is its fill and outline: none of the theme's.
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      onSubmitted: (_) {
                        if (!isSending) _sendMessage();
                      },
                    ),
                  ),
                  GestureDetector(
                    onTap: isSending ? null : _sendMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSending ? palette.line : palette.accent,
                        shape: BoxShape.circle,
                      ),
                      child: isSending
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: palette.text,
                              ),
                            )
                          : Icon(
                              Icons.auto_fix_high_rounded,
                              color: palette.onAccent,
                              size: 20,
                            ),
                    ),
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

class _RefinedNarrativeCard extends ConsumerWidget {
  final Map<String, dynamic> msg;
  final String? activeBgmUrl;
  final bool isBgmPlaying;
  final String? loadingBgmSceneId;
  final bool canGenerateBgm;
  final Future<void> Function(Map<String, dynamic> msg) onBgmPressed;
  final Future<void> Function(Map<String, dynamic> msg) onRetryPressed;

  const _RefinedNarrativeCard({
    super.key,
    required this.msg,
    required this.activeBgmUrl,
    required this.isBgmPlaying,
    required this.loadingBgmSceneId,
    required this.canGenerateBgm,
    required this.onBgmPressed,
    required this.onRetryPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final prefs = ref.watch(readingPrefsProvider);
    final isInitialLoadDone = ref.watch(isInitialLoadDoneProvider);
    final streamingMessageId = ref.watch(streamingMessageIdProvider);
    final viewMode = ref.watch(viewModeProvider);
    final isStreaming = streamingMessageId == msg['id'];
    final isUser = msg['role'] == 'user';
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final String? bgmUrl = msg['bgmUrl']?.toString();
    final bool hasBgm = bgmUrl != null && bgmUrl.isNotEmpty;
    final bool isBgmLoading = loadingBgmSceneId == msg['id']?.toString();
    final bool hasStreamFailed = msg['streamFailed'] == true;

    TextStyle getBaseStyle({
      double fontSize = 19,
      FontStyle fontStyle = FontStyle.normal,
      double? height,
    }) {
      return GoogleFonts.getFont(
        prefs.font,
        color: palette.text,
        fontSize: (isMobile ? fontSize - 2 : fontSize) * prefs.scale,
        height: height ?? prefs.lineHeight,
        fontStyle: fontStyle,
        letterSpacing: 0.4,
      ).copyWith(fontFamilyFallback: _fontFallbacks);
    }

    if (isUser) {
      if (viewMode == StoryViewMode.focus) return const SizedBox.shrink();

      final style = context.appStyle;
      final label = Container(
        padding: style.isRoute
            ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
            : EdgeInsets.zero,
        decoration: style.isRoute
            ? BoxDecoration(
                color: palette.text,
                borderRadius: BorderRadius.circular(style.radiusSmall),
              )
            : null,
        child: Text(
          "지난 선택",
          style: GoogleFonts.lato(
            color: style.isRoute ? palette.highlight : palette.accent,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      );
      return RepaintBoundary(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.only(top: 3), child: label),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  msg['content'],
                  style: getBaseStyle(
                    fontSize: 15,
                    height: 1.5,
                  ).copyWith(color: palette.muted),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(),
      );
    }

    final bool isPlaceholder = msg['content'] == '...';

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg['imageUrl'] != null)
              Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        context.appStyle.radiusLarge,
                      ),
                      child: CachedNetworkImage(
                        imageUrl: msg['imageUrl'],
                        fit: BoxFit.cover,
                        memCacheWidth: 800,
                        placeholder: (context, url) => Container(
                          height: 200,
                          color: palette.surface,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 800.ms)
                  .scale(begin: const Offset(0.98, 0.98)),

            if (isPlaceholder)
              Shimmer.fromColors(
                baseColor: palette.raised,
                highlightColor: palette.line,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 20,
                      decoration: BoxDecoration(
                        color: palette.text,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      height: 20,
                      decoration: BoxDecoration(
                        color: palette.text,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 200,
                      height: 20,
                      decoration: BoxDecoration(
                        color: palette.text,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              )
            else if (isStreaming)
              Text(msg['content'], style: getBaseStyle())
            else if (!isInitialLoadDone)
              WritingEffect(text: msg['content'], style: getBaseStyle())
            else
              StoryMarkdown(
                data: msg['content'],
                style: getBaseStyle(),
                strongStyle: getBaseStyle().copyWith(
                  color: palette.accent,
                  fontWeight: FontWeight.bold,
                ),
                quoteDecoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: palette.accent, width: 4),
                  ),
                  color: palette.surface,
                ),
                quoteStyle: getBaseStyle(
                  fontStyle: FontStyle.italic,
                ).copyWith(color: palette.muted),
              ),
            if (hasStreamFailed)
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: OutlinedButton.icon(
                  onPressed: () => onRetryPressed(msg),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('응답 복구'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.warning,
                    side: BorderSide(color: palette.warning),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        context.appStyle.isNight
                            ? 999
                            : context.appStyle.radiusSmall,
                      ),
                    ),
                  ),
                ),
              ),
            if (!hasStreamFailed &&
                !isPlaceholder &&
                !isStreaming &&
                (hasBgm || canGenerateBgm))
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: _BgmControlButton(
                  hasBgm: hasBgm,
                  isActive: hasBgm && activeBgmUrl == bgmUrl,
                  isPlaying: isBgmPlaying,
                  isLoading: isBgmLoading,
                  onPressed: () => onBgmPressed(msg),
                ),
              ),
          ],
        ),
      ).animate().fadeIn(duration: isStreaming ? 0.ms : 600.ms),
    );
  }
}

class _BgmControlButton extends StatelessWidget {
  final bool hasBgm;
  final bool isActive;
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onPressed;

  const _BgmControlButton({
    required this.hasBgm,
    required this.isActive,
    required this.isPlaying,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = isLoading
        ? 'BGM 생성 중'
        : hasBgm
        ? (isActive && isPlaying ? 'BGM 일시정지' : 'BGM 듣기')
        : 'BGM 생성';

    return OutlinedButton.icon(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: isActive ? palette.accent : palette.muted,
        side: BorderSide(color: isActive ? palette.accent : palette.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            context.appStyle.isNight ? 999 : context.appStyle.radiusSmall,
          ),
        ),
      ),
      icon: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              hasBgm
                  ? (isActive && isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded)
                  : Icons.music_note_rounded,
              size: 18,
            ),
      label: Text(label),
    );
  }
}

class _TipItem extends StatelessWidget {
  final String text;
  const _TipItem({required this.text});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "• ",
            style: TextStyle(
              color: palette.accent,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: palette.muted, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
