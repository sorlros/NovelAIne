import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:frontend/l10n/app_localizations.dart';
import '../../../../data/models/creation_config.dart';
import '../../../../data/services/api_service.dart';
import '../story_screen.dart';
import 'steps/world_step.dart';
import 'steps/character_step.dart';
import 'steps/review_step.dart';

class WizardScreen extends StatefulWidget {
  final bool isQuickStart;

  const WizardScreen({super.key, required this.isQuickStart});

  @override
  State<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends State<WizardScreen> {
  late CreationConfig _config;
  int _currentStep = 0;
  final PageController _pageController = PageController();

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

  Future<void> _finishCreation() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
      ),
    );

    try {
      final apiService = ApiService();
      final createdStory = await apiService.createStory(_config);

      if (!mounted) return;
      Navigator.pop(context);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => StoryScreen(initialStory: createdStory),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("생성 실패: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.isQuickStart 
        ? const Color(0xFFFFD700) 
        : const Color(0xFF00E5FF);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isQuickStart
              ? AppLocalizations.of(context)!.quickStart
              : AppLocalizations.of(context)!.detailedSettings,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background ambient glow
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withOpacity(0.08),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.1),
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
                _StepIndicator(
                  currentStep: _currentStep, 
                  totalSteps: 3, 
                  accentColor: accentColor,
                ),
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
  final Color accentColor;

  const _StepIndicator({
    required this.currentStep, 
    required this.totalSteps,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
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
                        color: isCompleted || isCurrent
                            ? accentColor
                            : Colors.white10,
                        shape: BoxShape.circle,
                        boxShadow: isCurrent ? [
                          BoxShadow(
                            color: accentColor.withOpacity(0.4),
                            blurRadius: 10,
                            spreadRadius: 2,
                          )
                        ] : null,
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check, size: 16, color: Colors.black)
                            : Text(
                                "${index + 1}",
                                style: TextStyle(
                                  color: isCurrent ? Colors.black : Colors.white54,
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
                            color: isCompleted
                                ? accentColor
                                : Colors.white10,
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
                  color: accentColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ).animate().fadeIn().slideX(begin: -0.1, end: 0),
              Text(
                "${currentStep + 1} / $totalSteps",
                style: const TextStyle(
                  color: Colors.white30,
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
      case 0: return "세계관 설정";
      case 1: return "주인공 설정";
      case 2: return "최종 확인";
      default: return "";
    }
  }
}
