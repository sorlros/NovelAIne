import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_style.dart';
import '../../../data/constants/creation_prompts.dart';
import '../../../data/models/creation_config.dart';
import '../../providers/content_provider.dart';
import '../../providers/plan_provider.dart';
import '../../widgets/custom_toast.dart';
import '../../widgets/responsive_layout.dart';
import 'start_story.dart';
import 'wizard_screen.dart';

/// The "new story" screen: genre, tone, an optional name and the engine on one page.
class CreationModeSelectionScreen extends ConsumerStatefulWidget {
  const CreationModeSelectionScreen({super.key});

  @override
  ConsumerState<CreationModeSelectionScreen> createState() =>
      _CreationModeSelectionScreenState();
}

class _CreationModeSelectionScreenState
    extends ConsumerState<CreationModeSelectionScreen> {
  String? _genre;
  String? _tone;
  final _nameController = TextEditingController();

  /// One id per screen: tapping create again after a lost response returns the same story.
  final String _requestId = const Uuid().v4();

  bool get _ready => _genre != null && _tone != null;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _create() {
    final genre = _genre;
    final tone = _tone;
    if (genre == null || tone == null) return;
    final name = _nameController.text.trim();
    final config = CreationConfig(isQuickStart: true)
      ..genreLabel = genre
      ..genrePrompt = CreationPrompts.genres[genre]
      ..toneLabel = tone
      ..tonePrompt = CreationPrompts.tones[tone]
      ..userName = name.isEmpty ? null : name;
    startStory(context, ref, config, _requestId);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    final plan = ref.watch(currentPlanProvider);
    final selectedModel = ref.watch(selectedModelProvider);
    final proLocked = plan.locks(AppConstants.proLlmModel);

    return ResponsiveLayout(
      currentIndex: 2,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Header(
                          onBack: Navigator.canPop(context)
                              ? () => Navigator.pop(context)
                              : null,
                        ),
                        const SizedBox(height: 28),
                        _SectionTitle(number: 1, title: '장르'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final key in CreationPrompts.genres.keys)
                              _ChoiceChip(
                                label: CreationPrompts.displayName(key),
                                selected: _genre == key,
                                onTap: () => setState(() => _genre = key),
                              ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        _SectionTitle(number: 2, title: '분위기'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final key in CreationPrompts.tones.keys)
                              _ChoiceChip(
                                label: CreationPrompts.displayName(key),
                                selected: _tone == key,
                                onTap: () => setState(() => _tone = key),
                              ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        _SectionTitle(number: 3, title: '주인공 이름 (선택)'),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _nameController,
                          style: TextStyle(color: palette.text),
                          cursorColor: palette.accent,
                          decoration: InputDecoration(
                            hintText: '비워 두면 이야기가 정합니다',
                            hintStyle: TextStyle(color: palette.faint),
                            filled: true,
                            fillColor: palette.surface,
                            border: _inputBorder(style, palette.line),
                            enabledBorder: _inputBorder(
                              style,
                              style.edge(palette),
                            ),
                            focusedBorder: _inputBorder(style, palette.accent),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          '글 쓰는 엔진',
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _EngineOption(
                                label: '기본',
                                selected:
                                    selectedModel ==
                                    AppConstants.defaultLlmModel,
                                onTap: () =>
                                    ref
                                        .read(selectedModelProvider.notifier)
                                        .state = AppConstants
                                        .defaultLlmModel,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _EngineOption(
                                label: '고급',
                                selected:
                                    selectedModel == AppConstants.proLlmModel,
                                locked: proLocked,
                                onTap: () {
                                  if (proLocked) {
                                    CustomToast.show(
                                      context,
                                      AppConstants.premiumOnlyMessage,
                                      type: ToastType.error,
                                    );
                                    return;
                                  }
                                  ref
                                          .read(selectedModelProvider.notifier)
                                          .state =
                                      AppConstants.proLlmModel;
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: palette.ground,
                border: Border(
                  top: BorderSide(
                    color: style.edge(palette),
                    width: style.borderWidth,
                  ),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _ready ? _create : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: style.primary(palette),
                            foregroundColor: style.onPrimary(palette),
                            disabledBackgroundColor: palette.raised,
                            disabledForegroundColor: palette.faint,
                            elevation: 0,
                            side: style.primaryEdge(palette),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(style.radius),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                style.isRoute ? '출발' : '이야기 만들기',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (style.isRoute) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward, size: 18),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              plan.premium
                                  ? '2~3분 걸려요'
                                  : '무료로 이번 주 ${plan.remaining('story')}편 남음 · 2~3분 걸려요',
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const WizardScreen(isQuickStart: false),
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: palette.accent,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text(
                              '직접 정하기',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  OutlineInputBorder _inputBorder(AppStyle style, Color color) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(style.radiusSmall),
        borderSide: BorderSide(color: color, width: style.borderWidth),
      );
}

/// Title block: an accent band on the route style, a plain serif title elsewhere.
class _Header extends StatelessWidget {
  final VoidCallback? onBack;
  const _Header({this.onBack});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    if (style.isRoute) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.accent,
          borderRadius: BorderRadius.circular(style.radius),
          border: Border.all(color: palette.text, width: 2),
          boxShadow: style.shadow(palette),
        ),
        child: Text(
          '출발 전에 세 가지만',
          style: style.title(
            TextStyle(color: palette.onAccent, fontSize: 24, height: 1.3),
          ),
        ),
      );
    }
    return Row(
      children: [
        if (onBack != null)
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: palette.muted),
            onPressed: onBack,
          ),
        Expanded(
          child: Text(
            '어떤 이야기를 읽고 싶나요?',
            style: style.title(
              TextStyle(
                color: palette.text,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final int number;
  final String title;
  const _SectionTitle({required this.number, required this.title});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    return Row(
      children: [
        if (style.isRoute) ...[
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.highlight,
              borderRadius: BorderRadius.circular(style.radiusSmall),
              border: Border.all(color: palette.text, width: 2),
            ),
            child: Text(
              '$number',
              style: TextStyle(
                color: palette.onHighlight,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Text(
          title,
          style: style.title(
            TextStyle(
              color: palette.text,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    final color = style.onControl(palette, selected: selected);
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: style
              .control(palette, selected: selected)
              .copyWith(
                borderRadius: BorderRadius.circular(
                  style.isNight ? style.radiusLarge : style.radiusSmall,
                ),
              ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected && !style.isNight) ...[
                Icon(Icons.check, size: 14, color: color),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EngineOption extends StatelessWidget {
  final String label;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;
  const _EngineOption({
    required this.label,
    required this.selected,
    this.locked = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    final color = selected
        ? style.onControl(palette, selected: true)
        : palette.muted;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: style.control(palette, selected: selected),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (locked) ...[
                Icon(Icons.lock, size: 14, color: color),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (locked) ...[
                const SizedBox(width: 6),
                Text(
                  '유료',
                  style: TextStyle(color: palette.faint, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
