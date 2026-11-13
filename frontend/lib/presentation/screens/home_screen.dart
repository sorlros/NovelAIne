import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants.dart'; // Added missing import
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_style.dart';
import 'story_generation_screen.dart';
import 'story_screen.dart';

import 'creation/mode_selection_screen.dart' as creation_screen;
import 'profile/settings_screen.dart'; // Added
import '../widgets/responsive_layout.dart';
import '../providers/content_provider.dart';
import '../providers/plan_provider.dart';
import '../widgets/scene_progress.dart';
import '../widgets/custom_toast.dart';
import '../../../data/models/story_model.dart';
import '../../../data/repositories/story_repository.dart';

// Isolate에서 실행될 데이터 가공 함수 (파일 최상단 유지)
List<Map<String, dynamic>> _preWarmScenesIsolate(List<dynamic> scenes) {
  return scenes
      .map(
        (scene) => {
          'id':
              scene['id']?.toString() ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          'role': scene['role'] ?? 'ai',
          'content': scene['content'] ?? "",
          'imageUrl': scene['imageUrl'] ?? scene['image_url'],
          'sceneType': scene['sceneType'] ?? scene['scene_type'] ?? 'narrative',
        },
      )
      .toList();
}

/// The genre as the reader sees it: Korean for the known ones, the raw value otherwise.
String genreLabel(String genre) {
  switch (genre.toLowerCase()) {
    case 'fantasy':
      return '판타지';
    case 'scifi':
      return 'SF';
    case 'mystery':
      return '미스터리';
    case 'romance':
      return '로맨스';
    case 'wuxia':
      return '무협';
    case 'apocalypse':
      return '아포칼립스';
    case 'horror':
      return '호러';
    default:
      return genre;
  }
}

/// Title face of the theme: serif at night, heavier serif on paper, heavy sans on the route.
TextStyle appTitleStyle(
  AppStyle style,
  AppPalette palette,
  double size, {
  Color? color,
  double? height,
}) {
  final c = color ?? palette.text;
  if (style.isRoute) {
    return style.title(
      TextStyle(
        color: c,
        fontSize: size,
        fontWeight: FontWeight.w900,
        height: height,
      ),
    );
  }
  return GoogleFonts.notoSerif(
    color: c,
    fontSize: size,
    fontWeight: style.isPaper ? FontWeight.w900 : FontWeight.bold,
    height: height,
  );
}

/// Genre filter chips of the explore and community screens.
class GenreFilterBar extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelect;

  const GenreFilterBar({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  static const List<Map<String, String?>> filters = [
    {'label': '전체', 'value': null},
    {'label': '판타지', 'value': 'fantasy'},
    {'label': 'SF', 'value': 'scifi'},
    {'label': '미스터리', 'value': 'mystery'},
    {'label': '로맨스', 'value': 'romance'},
    {'label': '무협', 'value': 'wuxia'},
    {'label': '아포칼립스', 'value': 'apocalypse'},
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    return SizedBox(
      height: 56,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final value = filter['value'];
          final isSelected = value == selected;
          final fg = style.onControl(palette, selected: isSelected);
          var decoration = style.control(palette, selected: isSelected);
          if (style.isNight) {
            decoration = decoration.copyWith(
              borderRadius: BorderRadius.circular(999),
            );
          }
          return Semantics(
            button: true,
            selected: isSelected,
            child: GestureDetector(
              onTap: () => onSelect(value),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: decoration,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected && !style.isNight) ...[
                      Icon(Icons.check, size: 14, color: fg),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      filter['label']!,
                      style: TextStyle(
                        color: isSelected ? fg : palette.muted,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemCount: filters.length,
      ),
    );
  }
}

/// A small tag on a story card (genre, narrative type, status).
class StoryTag extends StatelessWidget {
  final String label;

  const StoryTag({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    final BoxDecoration decoration = switch (style.kind) {
      StyleKind.night => BoxDecoration(
        color: palette.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      StyleKind.paper => BoxDecoration(
        borderRadius: BorderRadius.circular(style.radiusSmall),
        border: Border.all(color: palette.accent),
      ),
      StyleKind.route => BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(style.radiusSmall),
        border: Border.all(color: palette.text, width: 1.5),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: decoration,
      child: Text(
        label,
        style: TextStyle(
          color: style.isRoute ? palette.text : palette.accent,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

void _openCreation(BuildContext context) {
  HapticFeedback.mediumImpact();
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const creation_screen.CreationModeSelectionScreen(),
    ),
  );
}

void _openStory(BuildContext context, StoryModel story) {
  HapticFeedback.selectionClick();
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => story.isGenerating
          ? StoryGenerationScreen(story: story)
          : StoryScreen(initialStory: story),
    ),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      currentIndex: 0,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _HeaderSection(),
                  SizedBox(height: 24),
                  _Library(),
                  // 모바일 하단 바 높이만큼 추가 여백
                  SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderSection extends ConsumerWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final style = context.appStyle;
    final plan = ref.watch(currentPlanProvider);
    final bool isMobile =
        MediaQuery.of(context).size.width < AppConstants.desktopBreakpoint;
    final bool band = style.isRoute;
    final Color inkColor = band ? palette.onAccent : palette.text;
    final turns = plan.remaining('turn');
    final stories = plan.remaining('story');

    final settings = IconButton(
      onPressed: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsScreen()),
        );
      },
      icon: Icon(
        Icons.settings_outlined,
        color: band ? palette.onAccent : palette.muted,
        size: isMobile ? 24 : 28,
      ),
      tooltip: "설정",
    );

    Widget remaining() {
      if (plan.premium) return const SizedBox.shrink();
      if (band) {
        TextStyle small = TextStyle(
          color: palette.onAccent,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        );
        TextStyle big = TextStyle(
          color: palette.highlight,
          fontSize: 40,
          fontWeight: FontWeight.w900,
          height: 1,
        );
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('오늘 ', style: small),
                Text('$turns', style: big),
                Text('장면', style: small),
                const SizedBox(width: 20),
                Text('이번 주 ', style: small),
                Text('$stories', style: big),
                Text('편 남음', style: small),
              ],
            ),
          ),
        );
      }
      final base = TextStyle(color: palette.muted, fontSize: 14);
      final number = TextStyle(
        color: palette.accent,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      );
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text.rich(
          TextSpan(
            style: base,
            children: [
              const TextSpan(text: '오늘 '),
              TextSpan(text: '$turns', style: number),
              const TextSpan(text: '장면 · 이번 주 '),
              TextSpan(text: '$stories', style: number),
              const TextSpan(text: '편 남음'),
            ],
          ),
        ),
      );
    }

    final content = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "서재",
                style: appTitleStyle(
                  style,
                  palette,
                  isMobile ? 28 : 32,
                  color: inkColor,
                ),
              ),
              remaining(),
            ],
          ),
        ),
        settings,
      ],
    );

    if (band) {
      return Container(
        width: double.infinity,
        color: palette.accent,
        padding: const EdgeInsets.fromLTRB(24, 20, 12, 24),
        child: content,
      ).animate().fadeIn();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: content,
    ).animate().fadeIn();
  }
}

class _Library extends ConsumerStatefulWidget {
  const _Library();

  @override
  ConsumerState<_Library> createState() => _LibraryState();
}

class _LibraryState extends ConsumerState<_Library> {
  bool _hasPreWarmed = false;

  void _preWarmRecentStory(List<StoryModel> stories) async {
    if (_hasPreWarmed || stories.isEmpty) return;
    _hasPreWarmed = true;

    try {
      final recentStory = stories.first;
      final preWarmedCache = ref.read(preWarmedScenesProvider);
      if (preWarmedCache.containsKey(recentStory.id)) return;

      final repository = ref.read(storyRepositoryProvider);
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      final scenes = await repository.getScenes(recentStory.id);
      if (scenes.isEmpty) return;

      final processedMessages = await compute(_preWarmScenesIsolate, scenes);

      if (mounted) {
        ref.read(preWarmedScenesProvider.notifier).update((state) {
          final newState = Map<String, List<Map<String, dynamic>>>.from(state);
          newState[recentStory.id] = processedMessages;
          return newState;
        });
      }
    } catch (e) {
      debugPrint("⚠️ [Pre-Warm] Failed: $e");
    }
  }

  /// Scenes (from 1, AI scenes in order) that carry a picture, from the pre-warmed cache.
  Set<int> _pictured(String storyId) {
    final scenes = ref.watch(preWarmedScenesProvider)[storyId];
    if (scenes == null) return const {};
    final result = <int>{};
    var number = 0;
    for (final scene in scenes) {
      if (scene['role'] != 'ai') continue;
      number++;
      final url = scene['imageUrl'];
      if (url is String && url.isNotEmpty) result.add(number);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    final storiesState = ref.watch(storiesProvider);
    final bool isMobile =
        MediaQuery.of(context).size.width < AppConstants.desktopBreakpoint;

    return storiesState.when(
      data: (stories) {
        if (stories.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "아직 작성 중인 이야기가 없습니다.",
                  style: TextStyle(color: palette.muted),
                ),
                const SizedBox(height: 16),
                const _NewStoryRow(),
              ],
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _preWarmRecentStory(stories);
        });

        StoryModel? resume;
        for (final story in stories) {
          if (!story.isGenerating) {
            resume = story;
            break;
          }
        }
        final others = [
          for (final story in stories)
            if (story.id != resume?.id) story,
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (resume != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _ContinueCard(
                  story: resume,
                  pictured: _pictured(resume.id),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              child: Text(
                "내 이야기",
                style: appTitleStyle(style, palette, isMobile ? 18 : 20),
              ),
            ),
            if (style.isNight)
              SizedBox(
                height: isMobile ? 280 : 320, // 모바일에서 높이 축소
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: others.length + 1,
                  itemBuilder: (context, index) {
                    if (index == others.length) return const _NewStoryCard();
                    return _StoryCard(story: others[index], index: index);
                  },
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    for (final story in others) _StoryRow(story: story),
                    const _NewStoryRow(),
                  ],
                ),
              ),
          ],
        );
      },
      loading: () => _buildShimmer(isMobile, palette, style),
      error: (error, _) => Center(
        child: Text('Error: $error', style: TextStyle(color: palette.danger)),
      ),
    );
  }

  Widget _buildShimmer(bool isMobile, AppPalette palette, AppStyle style) {
    return SizedBox(
      height: isMobile ? 280 : 320,
      child: Shimmer.fromColors(
        baseColor: palette.raised,
        highlightColor: palette.line,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 3,
          itemBuilder: (context, index) => Container(
            width: isMobile ? 170 : 200,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(style.radiusLarge),
            ),
          ),
        ),
      ),
    );
  }
}

/// The story to pick up reading: label, title, genre and scene, progress, and the resume button.
class _ContinueCard extends StatelessWidget {
  final StoryModel story;
  final Set<int> pictured;

  const _ContinueCard({required this.story, required this.pictured});

  int get _scene => story.totalScenes < 1 ? 1 : story.totalScenes;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    final meta = '${genreLabel(story.genre)} · 장면 $_scene';
    final label = Text(
      '이어 읽기',
      style: TextStyle(
        color: palette.accent,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
      ),
    );
    final metaText = Text(
      meta,
      style: TextStyle(color: palette.muted, fontSize: 13),
    );
    final button = SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: () {
          HapticFeedback.selectionClick();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StoryScreen(initialStory: story),
            ),
          );
        },
        child: Text('장면 $_scene 이어 읽기'),
      ),
    );
    final progress = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: SceneProgress(current: _scene, pictured: pictured),
    );

    switch (style.kind) {
      case StyleKind.night:
        final cover = story.coverImageUrl;
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: style.card(palette),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cover != null)
                SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: CachedNetworkImage(
                    imageUrl: cover,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    label,
                    const SizedBox(height: 8),
                    Text(
                      story.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: appTitleStyle(style, palette, 20),
                    ),
                    const SizedBox(height: 4),
                    metaText,
                    const SizedBox(height: 14),
                    progress,
                    const SizedBox(height: 16),
                    button,
                  ],
                ),
              ),
            ],
          ),
        );
      case StyleKind.paper:
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: palette.text, width: 2),
              bottom: BorderSide(color: palette.line),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    label,
                    const SizedBox(height: 10),
                    _ManuscriptTitle(title: story.title),
                    const SizedBox(height: 8),
                    metaText,
                    const SizedBox(height: 16),
                    button,
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '장면',
                    style: TextStyle(color: palette.muted, fontSize: 12),
                  ),
                  Text(
                    '$_scene',
                    style: GoogleFonts.notoSerif(
                      color: palette.text,
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      case StyleKind.route:
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: style.card(palette),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label,
              const SizedBox(height: 8),
              Text(
                story.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: appTitleStyle(style, palette, 22),
              ),
              const SizedBox(height: 4),
              metaText,
              const SizedBox(height: 14),
              progress,
              const SizedBox(height: 16),
              button,
            ],
          ),
        );
    }
  }
}

/// A title written one character per square, six squares a row and two rows at most; the rest goes
/// below as plain text.
class _ManuscriptTitle extends StatelessWidget {
  final String title;

  const _ManuscriptTitle({required this.title});

  static const int _perRow = 6;
  static const int _boxes = 12;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    final runes = title.runes.toList();
    final boxed = runes.take(_boxes).map(String.fromCharCode).toList();
    final rest = String.fromCharCodes(runes.skip(_boxes));
    final rows = [
      for (var i = 0; i < boxed.length; i += _perRow)
        boxed.sublist(i, (i + _perRow).clamp(0, boxed.length)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // Squares as large as the row allows, up to the paper's 44.
            final side = (constraints.maxWidth / _perRow).clamp(24.0, 44.0);
            final grid = BorderSide(
              color: palette.accent.withValues(alpha: 0.35),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < row.length; i++)
                          Container(
                            width: side,
                            height: side,
                            alignment: Alignment.center,
                            // Neighbours share one line, as on manuscript paper.
                            decoration: BoxDecoration(
                              border: Border(
                                top: grid,
                                bottom: grid,
                                right: grid,
                                left: i == 0 ? grid : BorderSide.none,
                              ),
                            ),
                            child: Text(
                              row[i],
                              style: GoogleFonts.notoSerif(
                                color: palette.text,
                                fontSize: side * 0.55,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            rest,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: appTitleStyle(style, palette, 16),
          ),
        ],
      ],
    );
  }
}

/// The last entry of the list in the paper and route styles.
class _NewStoryRow extends StatelessWidget {
  const _NewStoryRow();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    final selected = style.isRoute;
    final fg = style.isPaper
        ? palette.accent
        : style.onControl(palette, selected: selected);
    final BoxDecoration decoration = style.isPaper
        ? BoxDecoration(
            border: Border(bottom: BorderSide(color: palette.line)),
          )
        : style.control(palette, selected: selected);
    return Padding(
      padding: EdgeInsets.only(top: style.isPaper ? 0 : 12),
      child: GestureDetector(
        onTap: () => _openCreation(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: decoration,
          child: Row(
            mainAxisAlignment: style.isPaper
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 20, color: fg),
              const SizedBox(width: 8),
              Text(
                "새 이야기",
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The last card of the night style's horizontal list.
class _NewStoryCard extends StatelessWidget {
  const _NewStoryCard();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    final bool isMobile =
        MediaQuery.of(context).size.width < AppConstants.desktopBreakpoint;
    return GestureDetector(
      onTap: () => _openCreation(context),
      child: Container(
        width: isMobile ? 170 : 200,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: style.card(palette),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: palette.accent, size: 36),
            const SizedBox(height: 8),
            Text(
              "새 이야기",
              style: TextStyle(
                color: palette.text,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A story of the paper and route lists: a vertical row.
class _StoryRow extends StatelessWidget {
  final StoryModel story;
  const _StoryRow({required this.story});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    final meta = '${genreLabel(story.genre)} · 장면 ${story.totalScenes}';
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          story.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: appTitleStyle(style, palette, 17),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Flexible(
              child: Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.muted, fontSize: 12),
              ),
            ),
            if (story.isGenerating) ...[
              const SizedBox(width: 8),
              _GenerationBadge(failed: story.status == 'failed'),
            ],
          ],
        ),
      ],
    );
    final delete = _DeleteStoryButton(storyId: story.id, overlay: false);

    if (style.isPaper) {
      return InkWell(
        onTap: () => _openStory(context, story),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: palette.line)),
          ),
          child: Row(
            children: [
              Expanded(child: info),
              delete,
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openStory(context, story),
        borderRadius: BorderRadius.circular(style.radius),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          decoration: style.card(palette),
          child: Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${story.totalScenes}',
                    style: appTitleStyle(style, palette, 22, height: 1),
                  ),
                  Text(
                    '장면',
                    style: TextStyle(color: palette.muted, fontSize: 11),
                  ),
                ],
              ),
              delete,
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  final StoryModel story;
  final int index;
  const _StoryCard({required this.story, required this.index});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    final bool isMobile =
        MediaQuery.of(context).size.width < AppConstants.desktopBreakpoint;
    // The title sits on the cover under a dark gradient; a card without a cover shows it in the theme's own colours.
    final bool hasCover = story.coverImageUrl != null;

    return GestureDetector(
      onTap: () => _openStory(context, story),
      child: Container(
        width: isMobile ? 170 : 200, // 모바일에서 가로폭 축소
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(style.radiusLarge),
          color: palette.surface,
          image: story.coverImageUrl != null
              ? DecorationImage(
                  image: CachedNetworkImageProvider(story.coverImageUrl!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.3),
                    BlendMode.darken,
                  ),
                )
              : null,
        ),
        child: Stack(
          children: [
            if (story.coverImageUrl == null)
              Center(
                child: Icon(
                  Icons.book,
                  color: palette.line,
                  size: isMobile ? 48 : 64,
                ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(style.radiusLarge),
                  ),
                  gradient: hasCover
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.8),
                          ],
                        )
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      story.title,
                      style: GoogleFonts.notoSerif(
                        color: hasCover ? Colors.white : palette.text,
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 14 : 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${genreLabel(story.genre)} · 장면 ${story.totalScenes}',
                      style: TextStyle(
                        color: hasCover ? Colors.white70 : palette.muted,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (story.isGenerating)
              Positioned(
                top: 12,
                left: 12,
                child: _GenerationBadge(failed: story.status == 'failed'),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: _DeleteStoryButton(storyId: story.id),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.2, end: 0);
  }
}

class _GenerationBadge extends StatelessWidget {
  final bool failed;
  const _GenerationBadge({required this.failed});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    final label = failed ? '생성 실패' : '생성 중';
    final Color tone = failed ? palette.danger : palette.accent;
    final BoxDecoration decoration = switch (style.kind) {
      StyleKind.night => BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(999),
      ),
      StyleKind.paper => BoxDecoration(
        borderRadius: BorderRadius.circular(style.radiusSmall),
        border: Border.all(color: tone),
      ),
      StyleKind.route => BoxDecoration(
        color: failed ? palette.danger : palette.highlight,
        borderRadius: BorderRadius.circular(style.radiusSmall),
        border: Border.all(color: palette.text, width: 2),
      ),
    };
    final Color fg = switch (style.kind) {
      StyleKind.night => failed ? palette.ground : palette.onAccent,
      StyleKind.paper => tone,
      StyleKind.route => failed ? palette.ground : palette.onHighlight,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: decoration,
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _DeleteStoryButton extends ConsumerStatefulWidget {
  final String storyId;

  /// On a cover card the button floats in a dark circle; in a list row it is a plain icon button.
  final bool overlay;
  const _DeleteStoryButton({required this.storyId, this.overlay = true});

  @override
  ConsumerState<_DeleteStoryButton> createState() => _DeleteStoryButtonState();
}

class _DeleteStoryButtonState extends ConsumerState<_DeleteStoryButton> {
  bool _isLoading = false;

  Future<void> _handleDelete() async {
    final palette = context.palette;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('스토리 삭제'),
        content: const Text('이 이야기를 정말 삭제하시겠습니까? 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소', style: TextStyle(color: palette.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('삭제', style: TextStyle(color: palette.danger)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    HapticFeedback.vibrate();
    setState(() => _isLoading = true);

    try {
      await ref.read(storyRepositoryProvider).deleteStory(widget.storyId);
      if (mounted) {
        ref.invalidate(storiesProvider);
        CustomToast.show(context, '스토리가 삭제되었습니다.');
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '삭제 실패: $e', type: ToastType.error);
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
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: palette.danger),
      );
    }
    if (!widget.overlay) {
      return IconButton(
        onPressed: _handleDelete,
        tooltip: '삭제',
        icon: Icon(Icons.delete_outline, color: palette.muted, size: 20),
      );
    }
    return GestureDetector(
      onTap: _handleDelete,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white70,
          size: 18,
        ),
      ),
    );
  }
}
