import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'wizard_screen.dart';

class CreationModeSelectionScreen extends StatelessWidget {
  const CreationModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("새로운 모험"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "어떻게 시작할까요?",
              style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
            ).animate().fadeIn().slideY(),
            const SizedBox(height: 8),
            Text(
              "선호하는 스토리 생성 방식을 선택해주세요.",
              style: Theme.of(context).textTheme.bodyMedium,
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 48),

            // Quick Start Card
            _ModeCard(
              title: "빠른 시작 (Quick Start)",
              description: "장르만 고르면 AI가 나머지를 생성합니다.",
              icon: Icons.flash_on_rounded,
              color: const Color(0xFFFFD700), // Gold
              delay: 200,
              onTap: () {
                // Navigate to Wizard with QuickStart config
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WizardScreen(isQuickStart: true),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Architect Mode Card
            _ModeCard(
              title: "상세 설정 (Architect Mode)",
              description: "세계관, 캐릭터, 설정을 직접 커스터마이징합니다.",
              icon: Icons.architecture_rounded,
              color: Theme.of(context).primaryColor,
              delay: 300,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WizardScreen(isQuickStart: false),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int delay;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.delay,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
          ],
        ),
      ),
    ).animate().fadeIn().slideX(delay: delay.ms);
  }
}
