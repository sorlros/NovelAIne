import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MyLibraryTab extends StatelessWidget {
  const MyLibraryTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder data
    final List<Map<String, String>> readingStories = [
      {"title": "잃어버린 세계", "progress": "에피소드 3 / 10"},
      {"title": "오래된 저택의 비밀", "progress": "에피소드 1 / 5"},
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      children: [
        const Text(
          "읽고 있는 이야기",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ).animate().fadeIn().slideX(),
        const SizedBox(height: 16),
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: readingStories.length,
            itemBuilder: (context, index) {
              final story = readingStories[index];
              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E), // Dark placeholder
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.menu_book,
                            size: 40,
                            color: Colors.white24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      story["title"]!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      story["progress"]!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn().slideX(delay: (100 + index * 100).ms);
            },
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          "완독한 이야기",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ).animate().fadeIn().slideX(delay: 200.ms),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: const Center(
            child: Text(
              "아직 완독한 이야기가 없습니다.",
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ).animate().fadeIn().slideY(delay: 300.ms),
      ],
    );
  }
}
