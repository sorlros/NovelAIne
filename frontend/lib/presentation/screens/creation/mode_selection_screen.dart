import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'wizard_screen.dart';

class CreationModeSelectionScreen extends StatelessWidget {
  const CreationModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F), // Deep premium dark background
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
          // Background ambient glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7C3AED).withOpacity(0.15),
                // Glowing effect
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withOpacity(0.2),
                    blurRadius: 100,
                    spreadRadius: 80,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                        "어떻게 시작할까요?",
                        style: Theme.of(context).textTheme.displayLarge
                            ?.copyWith(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              foreground: Paint()
                                ..shader =
                                    const LinearGradient(
                                      colors: [Colors.white, Colors.white70],
                                    ).createShader(
                                      const Rect.fromLTWH(
                                        0.0,
                                        0.0,
                                        200.0,
                                        70.0,
                                      ),
                                    ),
                            ),
                      )
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 12),
                  Text(
                    "상상 속의 세계를 펼칠 준비가 되었습니다.\\n원하는 창작 방식을 선택해 주세요.",
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white54,
                      height: 1.5,
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
                  const SizedBox(height: 48),

                  // Quick Start Card
                  _PremiumModeCard(
                    title: "빠른 시작",
                    subtitle: "신속한 스토리 생성",
                    description:
                        "장르와 몇 가지 키워드만 고르면 AI가 즉시 흥미로운 서막을 만들어냅니다. 영감이 필요할 때 완벽합니다.",
                    icon: Icons.auto_awesome,
                    accentColor: const Color(0xFFFFD700), // Gold
                    gradientColors: [
                      const Color(0xFF2A2A1A),
                      const Color(0xFF151515),
                    ],
                    delay: 400,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const WizardScreen(isQuickStart: true),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Architect Mode Card
                  _PremiumModeCard(
                    title: "상세 설정",
                    subtitle: "나만의 세계관 구축",
                    description:
                        "세계의 법칙, 다면적인 캐릭터, 복잡한 설정들을 하나하나 직접 설계하고 지휘합니다.",
                    icon: Icons.architecture_rounded,
                    accentColor: const Color(0xFF00E5FF), // Cyan
                    gradientColors: [
                      const Color(0xFF102A30),
                      const Color(0xFF151515),
                    ],
                    delay: 600,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const WizardScreen(isQuickStart: false),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 48), // Bottom padding
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumModeCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color accentColor;
  final List<Color> gradientColors;
  final int delay;
  final VoidCallback onTap;

  const _PremiumModeCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.gradientColors,
    required this.delay,
    required this.onTap,
  });

  @override
  State<_PremiumModeCard> createState() => _PremiumModeCardState();
}

class _PremiumModeCardState extends State<_PremiumModeCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()
            ..scale(_isHovered ? 1.02 : 1.0)
            ..translate(0.0, _isHovered ? -5.0 : 0.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.gradientColors,
            ),
            border: Border.all(
              color: _isHovered
                  ? widget.accentColor.withOpacity(0.8)
                  : widget.accentColor.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withOpacity(_isHovered ? 0.25 : 0.1),
                blurRadius: _isHovered ? 30 : 15,
                spreadRadius: _isHovered ? 5 : 0,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              children: [
                // Inner subtle glow at top left
                Positioned(
                  top: -50,
                  left: -50,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.accentColor.withOpacity(0.15),
                      boxShadow: [
                        BoxShadow(
                          color: widget.accentColor.withOpacity(0.2),
                          blurRadius: 50,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: widget.accentColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: widget.accentColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              widget.icon,
                              color: widget.accentColor,
                              size: 36,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.subtitle,
                                  style: TextStyle(
                                    color: widget.accentColor.withOpacity(0.8),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.description,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(
                              horizontal: _isHovered ? 24 : 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: widget.accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: widget.accentColor.withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "선택하기",
                                  style: TextStyle(
                                    color: widget.accentColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: widget.accentColor,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.1, end: 0, delay: widget.delay.ms);
  }
}
