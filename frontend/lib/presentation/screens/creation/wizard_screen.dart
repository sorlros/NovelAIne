import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Added for compute
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:frontend/l10n/app_localizations.dart';
import '../../../../data/models/creation_config.dart';
import '../../../../data/services/api_service.dart';
import '../../../../data/repositories/story_repository.dart';
import '../../providers/content_provider.dart'; // Added
import '../../widgets/custom_loading_indicator.dart';
import '../story_screen.dart';
import 'steps/world_step.dart';
import 'steps/character_step.dart';
import 'steps/review_step.dart';

class WizardScreen extends ConsumerStatefulWidget { // Changed to ConsumerStatefulWidget
  final bool isQuickStart;

  const WizardScreen({super.key, required this.isQuickStart});

  @override
  ConsumerState<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends ConsumerState<WizardScreen> {
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
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, anim1, anim2) => const Scaffold(
        backgroundColor: Colors.transparent,
        body: StoryCreationLoadingWidget(),
      ),
    );

    try {
      final apiService = ApiService();
      
      // 선택된 모델 설정
      _config.llmModel = ref.read(selectedModelProvider);
      
      // [수정] 현재 로그인된 사용자 ID 가져오기
      final authState = ref.read(authProvider);
      final userId = authState.value?.id;
      
      final createdStory = await apiService.createStory(_config, userId: userId);

      final repository = ref.read(storyRepositoryProvider);

      // 1. 생성된 스토리를 로컬 DB에 수동으로 즉시 저장
      await repository.cacheStory(createdStory);

      // 2. 생성된 스토리의 장면들을 서버에서 가져와 '사전 파싱' 진행 (Isolate 활용)
      List<Map<String, dynamic>> processedMessages = [];
      try {
        final scenes = await repository.getScenes(createdStory.id, forceRefresh: true);
        
        if (scenes.isNotEmpty) {
          // [성능 핵심] 무거운 맵 변환 작업을 Isolate에서 수행하여 애니메이션 멈춤 방지
          processedMessages = await compute((List<dynamic> rawScenes) {
            return rawScenes.map((scene) => {
              'id': scene['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
              'role': scene['role'] ?? 'ai',
              'content': scene['content'] ?? "",
              'imageUrl': scene['imageUrl'] ?? scene['image_url'],
              'sceneType': scene['sceneType'] ?? scene['scene_type'] ?? 'narrative',
            }).toList();
          }, scenes);

          // [성능 핵심] StoryScreen에 진입하기 전, 캐시 및 메시지 프로바이더 미리 채우기
          ref.read(preWarmedScenesProvider.notifier).update((state) {
            final newState = Map<String, List<Map<String, dynamic>>>.from(state);
            newState[createdStory.id] = processedMessages;
            return newState;
          });
          
          // 전역 메시지 상태 미리 설정 (StoryScreen 진입 시 즉시 렌더링용)
          ref.read(messageProvider.notifier).state = processedMessages;
        }
        
        ref.invalidate(storiesProvider);
      } catch (syncErr) {
        debugPrint("Initial scene sync/parsing failed: $syncErr");
      }

      // Handle character image upload (existing logic)
      if (_config.userImageBytes != null) {
        try {
          final storyData = await apiService.fetchStory(createdStory.id);
          final characters = storyData['characters'] as List?;
          if (characters != null && characters.isNotEmpty) {
            final protagonistId = characters.first['id'];
            await apiService.uploadCharacterImage(
              protagonistId,
              _config.userImageBytes!,
              fileName: 'protagonist_${protagonistId.substring(0, 8)}.jpg',
            );
          }
        } catch (imageErr) {
          debugPrint("Protagonist image upload failed: $imageErr");
        }
      }

      if (!mounted) return;
      
      // [성능 핵심] StoryScreen 상태 제어: 진입하자마자 UI가 보이고 초기화가 완료된 것으로 설정
      ref.read(isUIReadyProvider.notifier).state = true;
      ref.read(isInitialLoadDoneProvider.notifier).state = true;

      Navigator.pop(context); // Close loading dialog

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => StoryScreen(initialStory: createdStory),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
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
                color: accentColor.withValues(alpha: 0.08),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.1),
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
                            color: accentColor.withValues(alpha: 0.4),
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
