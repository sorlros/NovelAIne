import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math' as math;
import 'wizard_screen.dart';
import '../../widgets/responsive_layout.dart';

class CreationModeSelectionScreen extends StatelessWidget {
  const CreationModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      currentIndex: 1,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212), // Match unified dark theme
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text(""),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Stack(
          children: [
            // Background Subtle Effects
            const _SubtleBackgroundGlow(),
            
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 24.0,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        const Icon(Icons.edit_note, color: Color(0xFF6B4EFF), size: 48)
                            .animate()
                            .fadeIn()
                            .slideY(begin: -0.2, end: 0),
                        const SizedBox(height: 16),
                        
                        const Text(
                          "어떻게 시작할까요?",
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -1.0,
                          ),
                        ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.05, end: 0),
                        
                        const SizedBox(height: 12),
                        
                        Text(
                          "상상 속의 세계를 펼칠 준비가 되었습니다.\n원하는 창작 방식을 선택해 주세요.",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 16,
                            height: 1.6,
                          ),
                        ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
                        
                        const SizedBox(height: 48),

                        // LayoutBuilder to handle side-by-side on desktop vs column on mobile
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth > 600) {
                              return Row(
                                children: [
                                  Expanded(
                                    child: _ModernModeCard(
                                      title: "빠른 시작",
                                      subtitle: "Quick Start",
                                      description: "장르와 몇 가지 키워드만 고르면 AI가 즉시 흥미로운 서막을 만들어냅니다.",
                                      iconData: Icons.bolt,
                                      accentColor: const Color(0xFFFFBE0B),
                                      delay: 400,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const WizardScreen(isQuickStart: true)),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: _ModernModeCard(
                                      title: "상세 설정",
                                      subtitle: "World Builder",
                                      description: "세계의 법칙, 다면적인 캐릭터, 복잡한 설정들을 직접 설계하고 지휘합니다.",
                                      iconData: Icons.architecture,
                                      accentColor: const Color(0xFF6B4EFF),
                                      delay: 600,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const WizardScreen(isQuickStart: false)),
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
                                    subtitle: "Quick Start",
                                    description: "장르와 몇 가지 키워드만 고르면 AI가 즉시 흥미로운 서막을 만들어냅니다.",
                                    iconData: Icons.bolt,
                                    accentColor: const Color(0xFFFFBE0B),
                                    delay: 400,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const WizardScreen(isQuickStart: true)),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  _ModernModeCard(
                                    title: "상세 설정",
                                    subtitle: "World Builder",
                                    description: "세계의 법칙, 다면적인 캐릭터, 복잡한 설정들을 직접 설계하고 지휘합니다.",
                                    iconData: Icons.architecture,
                                    accentColor: const Color(0xFF6B4EFF),
                                    delay: 600,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const WizardScreen(isQuickStart: false)),
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
      ),
    );
  }
}

class _ModernModeCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String description;
  final IconData iconData;
  final Color accentColor;
  final int delay;
  final VoidCallback onTap;

  const _ModernModeCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.iconData,
    required this.accentColor,
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
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF151515),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isHovered ? widget.accentColor.withOpacity(0.5) : Colors.white10,
              width: 1.5,
            ),
            boxShadow: [
              if (_isHovered)
                BoxShadow(
                  color: widget.accentColor.withOpacity(0.15),
                  blurRadius: 20,
                  spreadRadius: 5,
                )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(widget.iconData, color: widget.accentColor, size: 32),
              ),
              const SizedBox(height: 24),
              Text(
                widget.subtitle.toUpperCase(),
                style: TextStyle(
                  color: widget.accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.description,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
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
                      color: widget.accentColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward, color: widget.accentColor, size: 16),
                ],
              )
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
              color: const Color(0xFF6B4EFF).withOpacity(0.05),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6B4EFF).withOpacity(0.05),
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
              color: const Color(0xFFFFBE0B).withOpacity(0.03),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFBE0B).withOpacity(0.03),
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
