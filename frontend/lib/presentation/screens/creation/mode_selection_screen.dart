import 'package:material_ui/material_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_style.dart';
import 'wizard_screen.dart';
import '../../widgets/responsive_layout.dart';
import '../../providers/content_provider.dart';
import '../../providers/plan_provider.dart';
import '../../widgets/custom_toast.dart';

class CreationModeSelectionScreen extends ConsumerWidget {
  const CreationModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final style = context.appStyle;
    final selectedModel = ref.watch(selectedModelProvider);
    return ResponsiveLayout(
      currentIndex: 2,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(""),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: palette.muted),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background Subtle Effects
          if (style.isNight) const _SubtleBackgroundGlow(),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 24.0,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 850,
                  ), // Slightly adjusted
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Icon(
                        Icons.edit_note,
                        color: palette.accent,
                        size: 48,
                      ).animate().fadeIn().slideY(begin: -0.2, end: 0),
                      const SizedBox(height: 16),

                      Text(
                            "어떻게 시작할까요?",
                            style: style.title(
                              TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                color: palette.text,
                                letterSpacing: -1.0,
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 600.ms)
                          .slideX(begin: -0.05, end: 0),

                      const SizedBox(height: 12),

                      Text(
                        "상상 속의 세계를 펼칠 준비가 되었습니다.\n원하는 창작 방식을 선택해 주세요.",
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 16,
                          height: 1.6,
                        ),
                      ).animate().fadeIn(delay: 200.ms, duration: 600.ms),

                      const SizedBox(height: 40),

                      // Model Selection
                      _buildModelSelector(context, ref, selectedModel),

                      const SizedBox(height: 40),

                      // LayoutBuilder to handle side-by-side on desktop vs column on mobile
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth > 600) {
                            return Row(
                              children: [
                                Expanded(
                                  child: _ModernModeCard(
                                    title: "빠른 시작",
                                    description:
                                        "장르와 몇 가지 키워드만 고르면 AI가 즉시 흥미로운 서막을 만들어냅니다.",
                                    iconData: Icons.bolt,
                                    delay: 400,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const WizardScreen(
                                                isQuickStart: true,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: _ModernModeCard(
                                    title: "상세 설정",
                                    description:
                                        "세계의 법칙, 다면적인 캐릭터, 복잡한 설정들을 직접 설계하고 지휘합니다.",
                                    iconData: Icons.architecture,
                                    delay: 600,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const WizardScreen(
                                                isQuickStart: false,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          } else {
                            return Column(
                              children: [
                                _ModernModeCard(
                                  title: "빠른 시작",
                                  description:
                                      "장르와 몇 가지 키워드만 고르면 AI가 즉시 흥미로운 서막을 만들어냅니다.",
                                  iconData: Icons.bolt,
                                  delay: 400,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const WizardScreen(
                                              isQuickStart: true,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 24),
                                _ModernModeCard(
                                  title: "상세 설정",
                                  description:
                                      "세계의 법칙, 다면적인 캐릭터, 복잡한 설정들을 직접 설계하고 지휘합니다.",
                                  iconData: Icons.architecture,
                                  delay: 600,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const WizardScreen(
                                              isQuickStart: false,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelSelector(
    BuildContext context,
    WidgetRef ref,
    String selectedModel,
  ) {
    final palette = context.palette;
    final style = context.appStyle;
    final plan = ref.watch(currentPlanProvider);
    final proLocked = plan.locks(AppConstants.proLlmModel);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.psychology, color: palette.accent, size: 20),
            const SizedBox(width: 10),
            Text(
              "글 쓰는 엔진",
              style: style.title(
                TextStyle(
                  color: palette.text,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ModelOptionTile(
                title: "기본 엔진",
                subtitle: "빠르고 가벼운 전개",
                isSelected: selectedModel == AppConstants.defaultLlmModel,
                onTap: () => ref.read(selectedModelProvider.notifier).state =
                    AppConstants.defaultLlmModel,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ModelOptionTile(
                title: "고급 엔진",
                subtitle: "치밀하고 풍부한 서사",
                isSelected: selectedModel == AppConstants.proLlmModel,
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
                  ref.read(selectedModelProvider.notifier).state =
                      AppConstants.proLlmModel;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          plan.premium
              ? "2~3분 걸려요"
              : "무료로 이번 주 ${plan.remaining('story')}편 남음 · 2~3분 걸려요",
          style: TextStyle(color: palette.muted, fontSize: 13),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }
}

class _ModelOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final bool locked;
  final VoidCallback onTap;

  const _ModelOptionTile({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    this.locked = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    final onControl = style.onControl(palette, selected: isSelected);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: style.control(palette, selected: isSelected),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (locked) ...[
                  Icon(
                    Icons.lock,
                    color: isSelected ? onControl : palette.muted,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? onControl : palette.muted,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              locked ? '유료' : subtitle,
              style: TextStyle(
                color: isSelected ? onControl : palette.faint,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernModeCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData iconData;
  final int delay;
  final VoidCallback onTap;

  const _ModernModeCard({
    required this.title,
    required this.description,
    required this.iconData,
    required this.delay,
    required this.onTap,
  });

  @override
  State<_ModernModeCard> createState() => _ModernModeCardState();
}

class _ModernModeCardState extends State<_ModernModeCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(32),
          decoration: style
              .card(palette)
              .copyWith(
                border: Border.all(
                  color: _isHovered && !style.isRoute
                      ? palette.accent.withValues(alpha: 0.5)
                      : style.edge(palette),
                  width: style.borderWidth,
                ),
                boxShadow: style.isNight
                    ? [
                        if (_isHovered)
                          BoxShadow(
                            color: palette.accent.withValues(alpha: 0.15),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                      ]
                    : style.shadow(palette),
              ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: style.isRoute
                      ? palette.highlight
                      : palette.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(style.radiusSmall),
                  border: style.isRoute
                      ? Border.all(color: palette.text, width: 2)
                      : null,
                ),
                child: Icon(
                  widget.iconData,
                  color: style.isRoute ? palette.onHighlight : palette.accent,
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.title,
                style: style.title(
                  TextStyle(
                    color: palette.text,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.description,
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    "시작하기",
                    style: TextStyle(
                      color: palette.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward, color: palette.accent, size: 16),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(delay: widget.delay.ms).slideY(begin: 0.1, end: 0),
      ),
    );
  }
}

class _SubtleBackgroundGlow extends StatelessWidget {
  const _SubtleBackgroundGlow();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.accent.withValues(alpha: 0.05),
              boxShadow: [
                BoxShadow(
                  color: palette.accent.withValues(alpha: 0.05),
                  blurRadius: 100,
                  spreadRadius: 50,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: -150,
          left: -50,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.accent.withValues(alpha: 0.03),
              boxShadow: [
                BoxShadow(
                  color: palette.accent.withValues(alpha: 0.03),
                  blurRadius: 100,
                  spreadRadius: 50,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
