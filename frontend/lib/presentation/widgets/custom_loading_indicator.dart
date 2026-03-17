import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StoryCreationLoadingWidget extends StatefulWidget {
  const StoryCreationLoadingWidget({super.key});

  @override
  State<StoryCreationLoadingWidget> createState() => _StoryCreationLoadingWidgetState();
}

class _StoryCreationLoadingWidgetState extends State<StoryCreationLoadingWidget> {
  int _messageIndex = 0;
  final List<String> _loadingMessages = [
    "이야기의 씨앗을 뿌리고 있습니다...",
    "등장인물들에게 영혼을 불어넣는 중입니다...",
    "첫 장면의 무대를 꾸미고 있습니다...",
    "운명의 실타래를 엮는 중입니다...",
    "세계관의 역사와 신화를 기록하고 있습니다...",
    "마지막 마법의 가루를 뿌리고 있습니다..."
  ];

  @override
  void initState() {
    super.initState();
    _startMessageCycle();
  }

  void _startMessageCycle() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _messageIndex = (_messageIndex + 1) % _loadingMessages.length;
        });
        _startMessageCycle();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF7C3AED);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // 외곽 광채
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.15),
                ),
              ).animate(onPlay: (controller) => controller.repeat(reverse: true))
               .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 2.seconds),

              // 입자 효과
              ...List.generate(8, (index) {
                final random = math.Random(index);
                return _Particle(
                  startX: random.nextDouble() * 100 - 50,
                  endX: random.nextDouble() * 100 - 50,
                  color: accentColor.withValues(alpha: 0.6),
                  startDelay: Duration(milliseconds: random.nextInt(2000)),
                );
              }),

              // 중앙 아이콘
              const Icon(
                Icons.auto_stories,
                size: 64,
                color: Colors.white,
              ).animate(onPlay: (controller) => controller.repeat(reverse: true))
               .moveY(begin: -5, end: 5, duration: 1.5.seconds)
               .tint(color: accentColor.withValues(alpha: 0.5)),
            ],
          ),
          const SizedBox(height: 48),
          AnimatedSwitcher(
            duration: 800.ms,
            child: Text(
              _loadingMessages[_messageIndex],
              key: ValueKey(_messageIndex),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Particle extends StatelessWidget {
  final double startX;
  final double endX;
  final Color color;
  final Duration startDelay;

  const _Particle({
    required this.startX,
    required this.endX,
    required this.color,
    required this.startDelay,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 60,
      left: 60 + startX,
      child: Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ).animate(onPlay: (controller) => controller.repeat())
       .custom(
         duration: 2.seconds,
         delay: startDelay,
         builder: (context, value, child) {
           return Opacity(
             opacity: (1.0 - value).clamp(0.0, 1.0),
             child: Transform.translate(
               offset: Offset((endX - startX) * value, -100 * value),
               child: child,
             ),
           );
         },
       ),
    );
  }
}
