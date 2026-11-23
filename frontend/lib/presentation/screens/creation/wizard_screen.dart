import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_style.dart';
import '../../../../data/models/creation_config.dart';
import 'start_story.dart';
import 'steps/world_step.dart';
import 'steps/character_step.dart';
import 'steps/review_step.dart';

class WizardScreen extends ConsumerStatefulWidget {
  // Changed to ConsumerStatefulWidget
  final bool isQuickStart;

  const WizardScreen({super.key, required this.isQuickStart});

  @override
  ConsumerState<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends ConsumerState<WizardScreen> {
  late CreationConfig _config;
  int _currentStep = 0;
  final PageController _pageController = PageController();

  /// One id per wizard: tapping create again after a lost response returns the same story.
  final String _requestId = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    _config = CreationConfig(isQuickStart: widget.isQuickStart);
  }

  void _nextStep() {
    if (widget.isQuickStart && _currentStep == 0) {
      _finishCreation();
    } else if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishCreation();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _finishCreation() =>
      startStory(context, ref, _config, _requestId);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;

    return Scaffold(
      backgroundColor: palette.ground,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: palette.muted),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isQuickStart
              ? AppLocalizations.of(context)!.quickStart
              : AppLocalizations.of(context)!.detailedSettings,
          style: style.title(
            TextStyle(
              color: palette.text,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background ambient glow
          if (style.isNight)
            Positioned(
              top: -50,
              left: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.accent.withValues(alpha: 0.08),
                  boxShadow: [
                    BoxShadow(
                      color: palette.accent.withValues(alpha: 0.1),
                      blurRadius: 100,
                      spreadRadius: 50,
                    ),
                  ],
                ),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                _StepIndicator(currentStep: _currentStep, totalSteps: 3),
                Expanded(
                  child: PageView(
                    physics: const NeverScrollableScrollPhysics(),
                    controller: _pageController,
                    children: [
                      WorldStep(
                        config: _config,
                        onNext: _nextStep,
                        isQuickStart: widget.isQuickStart,
                      ),
                      CharacterStep(
                        config: _config,
                        onNext: _nextStep,
                        onPrev: _prevStep,
                      ),
                      ReviewStep(
                        config: _config,
                        onSubmit: _finishCreation,
                        onPrev: _prevStep,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _StepIndicator({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          Row(
            children: List.generate(totalSteps, (index) {
              final isCompleted = index < currentStep;
              final isCurrent = index == currentStep;
              final isLast = index == totalSteps - 1;

              return Expanded(
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: isCurrent ? 32 : 24,
                      height: isCurrent ? 32 : 24,
                      decoration: BoxDecoration(
                        color: style.isRoute
                            ? (isCurrent
                                  ? palette.highlight
                                  : isCompleted
                                  ? palette.surface
                                  : palette.ground)
                            : isCompleted || isCurrent
                            ? palette.accent
                            : palette.raised,
                        borderRadius: BorderRadius.circular(
                          style.isNight ? style.radiusLarge : style.radiusSmall,
                        ),
                        border: style.isRoute
                            ? Border.all(color: palette.text, width: 2)
                            : null,
                        boxShadow: isCurrent && style.isNight
                            ? [
                                BoxShadow(
                                  color: palette.accent.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: isCompleted
                            ? Icon(
                                Icons.check,
                                size: 16,
                                color: style.isRoute
                                    ? palette.text
                                    : palette.onAccent,
                              )
                            : Text(
                                "${index + 1}",
                                style: TextStyle(
                                  color: isCurrent
                                      ? (style.isRoute
                                            ? palette.onHighlight
                                            : palette.onAccent)
                                      : palette.muted,
                                  fontSize: isCurrent ? 14 : 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(1),
                            color: isCompleted ? palette.accent : palette.line,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getStepTitle(context, currentStep),
                style: TextStyle(
                  color: palette.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ).animate().fadeIn().slideX(begin: -0.1, end: 0),
              Text(
                "${currentStep + 1} / $totalSteps",
                style: TextStyle(
                  color: palette.faint,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getStepTitle(BuildContext context, int step) {
    switch (step) {
      case 0:
        return "세계관 설정";
      case 1:
        return "주인공 설정";
      case 2:
        return "최종 확인";
      default:
        return "";
    }
  }
}
