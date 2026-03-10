import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _config = CreationConfig(isQuickStart: widget.isQuickStart);
  }

  void _nextStep() {
    if (widget.isQuickStart && _currentStep == 0) {
      // Quick Start: Finish immediately after Step 1
      _finishCreation();
    } else if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
    } else {
      // Architect Mode: Finish after Step 3
      _finishCreation();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  Future<void> _finishCreation() async {
    // Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final apiService = ApiService();
      final createdStory = await apiService.createStory(_config);

      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading

      // Navigate to Story Screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => StoryScreen(initialStory: createdStory),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("생성 실패: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // Crucial for character/world input steps
      appBar: AppBar(
        title: Text(
          widget.isQuickStart
              ? AppLocalizations.of(context)!.quickStart
              : AppLocalizations.of(context)!.detailedSettings,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Custom Stepper Header
            _StepIndicator(currentStep: _currentStep, totalSteps: 3),

            Expanded(
              child: PageView(
                physics: const NeverScrollableScrollPhysics(),
                controller: PageController(
                  initialPage: _currentStep,
                ), // Just to sync state, logic uses rebuilt widgets usually
                children: [
                  if (_currentStep == 0)
                    WorldStep(
                      config: _config,
                      onNext: _nextStep,
                      isQuickStart: widget.isQuickStart,
                    ),
                  if (_currentStep == 1)
                    CharacterStep(
                      config: _config,
                      onNext: _nextStep,
                      onPrev: _prevStep,
                    ),
                  if (_currentStep == 2)
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
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _StepIndicator({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(totalSteps, (index) {
          final isActive = index <= currentStep;
          final isLast = index == totalSteps - 1;

          return Expanded(
            child: Row(
              children: [
                // Circle
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Theme.of(context).primaryColor
                        : Colors.white10,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      "${index + 1}",
                      style: TextStyle(
                        color: isActive ? Colors.black : Colors.white54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Line
                if (!isLast)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: index < currentStep
                          ? Theme.of(context).primaryColor
                          : Colors.white10,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
