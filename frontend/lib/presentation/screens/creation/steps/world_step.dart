import 'package:flutter/material.dart';
import '../../../../data/models/creation_config.dart';
import '../../../../data/constants/creation_prompts.dart';

class WorldStep extends StatefulWidget {
  final CreationConfig config;
  final bool isQuickStart; // Added
  final VoidCallback onNext;

  const WorldStep({
    super.key,
    required this.config,
    required this.onNext,
    required this.isQuickStart,
  });

  @override
  State<WorldStep> createState() => _WorldStepState();
}

class _WorldStepState extends State<WorldStep> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("세계관 및 컨셉", style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            "당신의 이야기가 펼쳐질 배경을 설정하세요.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),

          // Genre Selection
          Text("장르 (Genre)", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: CreationPrompts.genres.entries.map((entry) {
              final isSelected = widget.config.genreLabel == entry.key;
              return ChoiceChip(
                label: Text(entry.key),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    widget.config.genreLabel = entry.key;
                    widget.config.genrePrompt = entry.value;
                  });
                },
                selectedColor: Theme.of(context).primaryColor,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.black : Colors.white70,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Tone Selection
          Text("분위기 (Tone)", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: widget.config.toneLabel,
            decoration: const InputDecoration(
              labelText: "분위기 선택",
              border: OutlineInputBorder(),
            ),
            dropdownColor: Theme.of(context).cardColor,
            items: CreationPrompts.tones.entries.map((entry) {
              return DropdownMenuItem(value: entry.key, child: Text(entry.key));
            }).toList(),
            onChanged: (value) {
              setState(() {
                widget.config.toneLabel = value;
                widget.config.tonePrompt = CreationPrompts.tones[value];
              });
            },
          ),

          const Spacer(),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  (widget.config.genreLabel != null &&
                      widget.config.toneLabel != null)
                  ? widget.onNext
                  : null,
              style: widget.isQuickStart
                  ? ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.black,
                    )
                  : null,
              child: Text(
                widget.isQuickStart ? "모험 시작 (AI 자동 생성)" : "다음: 주인공 설정",
              ),
            ),
          ),
        ],
      ),
    );
  }
}
