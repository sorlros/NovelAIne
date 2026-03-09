import 'package:flutter/material.dart';
import '../../../../data/models/creation_config.dart';

class ReviewStep extends StatelessWidget {
  final CreationConfig config;
  final VoidCallback onSubmit;
  final VoidCallback onPrev;

  const ReviewStep({super.key, required this.config, required this.onSubmit, required this.onPrev});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("모험을 시작할까요?", style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 32),

          _SummaryCard(config: config),
          
          const Spacer(),
          
          Row(
            children: [
              TextButton(onPressed: onPrev, child: const Text("이전")),
              const Spacer(),
              ElevatedButton(
                onPressed: onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary, // Accent color
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text("모험 시작"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final CreationConfig config;

  const _SummaryCard({required this.config});

  @override
  Widget build(BuildContext context) {
     return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Row("장르", config.genreLabel ?? "선택 안됨"),
            const SizedBox(height: 12),
            _Row("분위기", config.toneLabel ?? "선택 안됨"),
            const SizedBox(height: 12),
            const Divider(color: Colors.white24),
            const SizedBox(height: 12),
            _Row("주인공", config.userName ?? "미정"),
            const SizedBox(height: 12),
            _Row("성격", config.personalityTraits.isEmpty ? "없음" : config.personalityTraits.join(", ")),
          ],
        ),
     );
  }

  Widget _Row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }
}
