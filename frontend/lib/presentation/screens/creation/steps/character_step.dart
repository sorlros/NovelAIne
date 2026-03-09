import 'package:flutter/material.dart';
import '../../../../data/models/creation_config.dart';
import '../../../../data/constants/creation_prompts.dart';

class CharacterStep extends StatefulWidget {
  final CreationConfig config;
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const CharacterStep({super.key, required this.config, required this.onNext, required this.onPrev});

  @override
  State<CharacterStep> createState() => _CharacterStepState();
}

class _CharacterStepState extends State<CharacterStep> {
  final TextEditingController _nameController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _nameController.text = widget.config.userName ?? '';
    _nameController.addListener(() {
      widget.config.userName = _nameController.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: ListView( // Changed to ListView for scrolling
        children: [
          Text("주인공 설정", style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text("이야기를 이끌어갈 주인공은 누구인가요?", style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 32),

          // Image Upload Placeholder
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24, style: BorderStyle.solid),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.add_a_photo, size: 40, color: Colors.white54),
                SizedBox(height: 12),
                Text("캐릭터 이미지 업로드", style: TextStyle(color: Colors.white54)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Name Input
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: "이름",
              hintText: "캐릭터의 이름을 입력하세요",
            ),
          ),
          const SizedBox(height: 24),

          // Traits
          Text("성격 (최대 3개)", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: CreationPrompts.personalityTraits.entries.map((entry) {
              final isSelected = widget.config.personalityTraits.contains(entry.key);
              return FilterChip(
                label: Text(entry.key),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      if (widget.config.personalityTraits.length < 3) {
                         widget.config.personalityTraits.add(entry.key);
                      }
                    } else {
                      widget.config.personalityTraits.remove(entry.key);
                    }
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 48), // Bottom padding
          
          Row(
            children: [
              TextButton(onPressed: widget.onPrev, child: const Text("이전")),
              const Spacer(),
              ElevatedButton(
                onPressed: _nameController.text.isNotEmpty ? widget.onNext : null,
                child: const Text("검토 및 시작"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
