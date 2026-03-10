import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend/l10n/app_localizations.dart';
import '../../../../data/models/creation_config.dart';
import '../../../../data/constants/creation_prompts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/content_provider.dart';

class CharacterStep extends ConsumerStatefulWidget {
  final CreationConfig config;
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const CharacterStep({
    super.key,
    required this.config,
    required this.onNext,
    required this.onPrev,
  });

  @override
  ConsumerState<CharacterStep> createState() => _CharacterStepState();
}

class _CharacterStepState extends ConsumerState<CharacterStep> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _appearanceController = TextEditingController();
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.config.userName ?? '';
    _nameController.addListener(() {
      widget.config.userName = _nameController.text;
    });

    _appearanceController.text = widget.config.appearanceDescription ?? '';
    _appearanceController.addListener(() {
      widget.config.appearanceDescription = _appearanceController.text;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _appearanceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _selectedImage = File(picked.path);
          widget.config.characterImagePath = picked.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('이미지 선택 중 오류가 발생했습니다: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: ListView(
        children: [
          Text(
            AppLocalizations.of(context)!.characterSetup,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.whoIsTheProtagonist,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          // ── My Characters Selection ──
          const Text(
            "내 캐릭터에서 불러오기",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ref
                .watch(charactersProvider)
                .when(
                  data: (characters) {
                    if (characters.isEmpty) {
                      return const Center(
                        child: Text(
                          "저장된 캐릭터가 없습니다.",
                          style: TextStyle(color: Colors.white30, fontSize: 12),
                        ),
                      );
                    }
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: characters.length,
                      itemBuilder: (context, index) {
                        final char = characters[index];
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _nameController.text = char.name;
                              widget.config.userName = char.name;

                              // Prepend background story to appearance desc for LLM context
                              String fullDesc = char.description;
                              if (char.backgroundStory != null &&
                                  char.backgroundStory!.isNotEmpty) {
                                fullDesc += "\n[배경]: ${char.backgroundStory}";
                              }
                              _appearanceController.text = fullDesc;
                              widget.config.appearanceDescription = fullDesc;

                              // Populate Traits
                              widget.config.personalityTraits.clear();
                              // Handle parsed traits format
                              if (char.personalityTraits.containsKey(
                                    'traits',
                                  ) &&
                                  char.personalityTraits['traits'] is List) {
                                final traitsList = List<String>.from(
                                  char.personalityTraits['traits'],
                                );
                                for (var t in traitsList.take(3)) {
                                  widget.config.personalityTraits.add(t);
                                }
                              }
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("${char.name} 설정이 불러와졌습니다."),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          child: Container(
                            width: 120,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  char.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  char.description,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Text(
                      "에러: $err",
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
          ),
          const SizedBox(height: 32),

          // ── Image Upload Section ──
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              clipBehavior: Clip.antiAlias,
              child: _selectedImage != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(_selectedImage!, fit: BoxFit.cover),
                        // Overlay change button
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.edit,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  AppLocalizations.of(context)!.change,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_a_photo_outlined,
                          size: 44,
                          color: Colors.white54,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          AppLocalizations.of(context)!.characterImageUpload,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppLocalizations.of(context)!.tapToSelectFromGallery,
                          style: const TextStyle(
                            color: Colors.white30,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Name Input ──
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.characterNameLabel,
              hintText: AppLocalizations.of(context)!.characterNameHint,
            ),
          ),
          const SizedBox(height: 24),

          // ── Appearance Input ──
          TextField(
            controller: _appearanceController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.appearanceLabel,
              hintText: AppLocalizations.of(context)!.appearanceHint,
            ),
          ),
          const SizedBox(height: 24),

          // ── Personality Traits ──
          Text(
            AppLocalizations.of(context)!.personalityTraitsLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: CreationPrompts.personalityTraits.entries.map((entry) {
              final isSelected = widget.config.personalityTraits.contains(
                entry.key,
              );
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

          const SizedBox(height: 48),

          Row(
            children: [
              TextButton(
                onPressed: widget.onPrev,
                child: Text(AppLocalizations.of(context)!.prevStep),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _nameController.text.isNotEmpty
                    ? widget.onNext
                    : null,
                child: Text(AppLocalizations.of(context)!.reviewAndStart),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
