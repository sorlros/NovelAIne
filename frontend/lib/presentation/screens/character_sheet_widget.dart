import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CharacterSheetWidget extends StatelessWidget {
  const CharacterSheetWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withOpacity(0.8),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Profile
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).primaryColor,
                                width: 2,
                              ),
                              color: Theme.of(context).cardColor,
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.4),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person,
                              size: 50,
                              color: Colors.white24,
                            ), // Fallback
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Elaria Shadow-Weaver",
                            style: Theme.of(context).textTheme.displayMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.5),
                              ),
                            ),
                            child: Text(
                              "레벨 5 마법사",
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn().moveY(begin: 20, end: 0),

                    const SizedBox(height: 32),

                    // Stats
                    Text("능력치", style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatCircle("힘", "12"),
                        _StatCircle("지능", "18"),
                        _StatCircle("민첩", "14"),
                        _StatCircle("매력", "16"),
                      ],
                    ).animate().fadeIn().scale(delay: 200.ms),

                    const SizedBox(height: 32),

                    // Bio
                    Text(
                      "배경 이야기",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "북쪽의 그림자 계곡에서 태어난 엘라리아는 어린 시절 그림자 마법에 대한 재능을 발견했습니다. 부족에서 추방당한 그녀는 이제 자신의 힘을 설명할 수 있는 고대 문서를 찾아 세상을 떠돌고 있습니다.",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ).animate().fadeIn(delay: 400.ms),

                    const SizedBox(height: 32),

                    // Memory / Relationships
                    Text(
                      "당신과의 관계",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.favorite, color: Colors.pinkAccent),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "선술집 사건 이후 당신을 신뢰하고 있습니다.",
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 600.ms),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCircle extends StatelessWidget {
  final String label;
  final String value;

  const _StatCircle(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white10),
          ),
          child: Center(
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
