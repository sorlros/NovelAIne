import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/l10n/app_localizations.dart';
import '../../../../core/theme/app_palette.dart';
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
  Uint8List? _selectedImageBytes;
  final ImagePicker _imagePicker = ImagePicker();

  // 필터 상태 추가
  bool _showOnlyVaulted = false;

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

    _selectedImageBytes = widget.config.userImageBytes;
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
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          widget.config.userImageBytes = bytes;
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
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.characterSetup,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.whoIsTheProtagonist,
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                const SizedBox(height: 32),

                // ── My Characters Selection with Filter ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SectionHeader(title: "저장된 캐릭터 불러오기"),
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _showOnlyVaulted = !_showOnlyVaulted),
                      icon: Icon(
                        _showOnlyVaulted
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 18,
                        color: _showOnlyVaulted
                            ? palette.accent
                            : palette.faint,
                      ),
                      label: Text(
                        "보관함만",
                        style: TextStyle(
                          color: _showOnlyVaulted
                              ? palette.accent
                              : palette.faint,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 110,
                  child: ref
                      .watch(charactersProvider)
                      .when(
                        data: (characters) {
                          final filteredList = _showOnlyVaulted
                              ? characters.where((c) => c.isInVault).toList()
                              : characters;

                          if (filteredList.isEmpty) {
                            return _EmptyCharacterState(
                              message: _showOnlyVaulted
                                  ? "보관된 캐릭터가 없습니다."
                                  : "저장된 캐릭터가 없습니다.",
                            );
                          }
                          return ListView.builder(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: filteredList.length,
                            itemBuilder: (context, index) {
                              final char = filteredList[index];
                              return _CharacterListItem(
                                char: char,
                                isSelected: widget.config.userName == char.name,
                                onTap: () {
                                  setState(() {
                                    _nameController.text = char.name;
                                    widget.config.userName = char.name;
                                    String fullDesc = char.description
                                        .replaceAll('\\n', '\n');
                                    if (char.backgroundStory != null &&
                                        char.backgroundStory!.isNotEmpty) {
                                      fullDesc +=
                                          "\n[배경]: ${char.backgroundStory}";
                                    }
                                    _appearanceController.text = fullDesc;
                                    widget.config.appearanceDescription =
                                        fullDesc;
                                    widget.config.personalityTraits.clear();
                                    for (var t in char.personalityTraits.take(
                                      3,
                                    )) {
                                      widget.config.personalityTraits.add(t);
                                    }
                                  });
                                },
                              );
                            },
                          );
                        },
                        loading: () => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        error: (err, _) => Text(
                          "Error: $err",
                          style: TextStyle(color: palette.danger, fontSize: 12),
                        ),
                      ),
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 32),

                // ── Image Upload Section ──
                _SectionHeader(
                  title: AppLocalizations.of(context)!.characterImageUpload,
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _pickImage,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _selectedImageBytes != null
                            ? palette.accent.withValues(alpha: 0.5)
                            : palette.line,
                        width: 1.5,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _selectedImageBytes != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(
                                _selectedImageBytes!,
                                fit: BoxFit.cover,
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.7),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: palette.accent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.edit_rounded,
                                        size: 14,
                                        color: palette.onAccent,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "변경하기",
                                        style: TextStyle(
                                          color: palette.onAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
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
                              Icon(
                                Icons.add_a_photo_rounded,
                                size: 40,
                                color: palette.accent.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                AppLocalizations.of(
                                  context,
                                )!.tapToSelectFromGallery,
                                style: TextStyle(
                                  color: palette.faint,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                  ),
                ).animate().fadeIn(delay: 300.ms),

                const SizedBox(height: 32),

                // ── Inputs ──
                _CustomTextField(
                  controller: _nameController,
                  label: AppLocalizations.of(context)!.characterNameLabel,
                  hint: AppLocalizations.of(context)!.characterNameHint,
                ).animate().fadeIn(delay: 400.ms),
                const SizedBox(height: 24),
                _CustomTextField(
                  controller: _appearanceController,
                  label: AppLocalizations.of(context)!.appearanceLabel,
                  hint: AppLocalizations.of(context)!.appearanceHint,
                  maxLines: 3,
                ).animate().fadeIn(delay: 500.ms),

                const SizedBox(height: 32),

                // ── Personality Traits ──
                _SectionHeader(
                  title: AppLocalizations.of(context)!.personalityTraitsLabel,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: CreationPrompts.personalityTraits.entries.map((
                    entry,
                  ) {
                    final isSelected = widget.config.personalityTraits.contains(
                      entry.key,
                    );
                    return _TraitChip(
                      label: entry.key,
                      isSelected: isSelected,
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
                ).animate().fadeIn(delay: 600.ms),

                const SizedBox(height: 40),
              ],
            ),
          ),

          // Bottom Navigation Area
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Row(
              children: [
                _NavButton(
                  onPressed: widget.onPrev,
                  label: AppLocalizations.of(context)!.prevStep,
                  isPrimary: false,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _NavButton(
                    onPressed: _nameController.text.isNotEmpty
                        ? widget.onNext
                        : null,
                    label: AppLocalizations.of(context)!.reviewAndStart,
                    isPrimary: true,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 700.ms),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: palette.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            color: palette.muted,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CharacterListItem extends StatelessWidget {
  final dynamic char;
  final bool isSelected;
  final VoidCallback onTap;

  const _CharacterListItem({
    required this.char,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? palette.accent.withValues(alpha: 0.1)
              : palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? palette.accent : palette.line,
            width: 1.5,
          ),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (char.imageUrl != null && char.imageUrl!.isNotEmpty)
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: CachedNetworkImageProvider(char.imageUrl!),
                  )
                else
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: palette.accent.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.person_rounded,
                      size: 20,
                      color: palette.accent,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  char.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? palette.accent : palette.text,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            if (char.isInVault)
              Positioned(
                top: 0,
                right: 0,
                child: Icon(
                  Icons.star_rounded,
                  color: palette.accent,
                  size: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCharacterState extends StatelessWidget {
  final String message;
  const _EmptyCharacterState({this.message = "저장된 캐릭터가 없습니다."});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: palette.faint, fontSize: 12),
        ),
      ),
    );
  }
}

class _CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;

  const _CustomTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: palette.muted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(color: palette.text, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: palette.faint, fontSize: 14),
            filled: true,
            fillColor: palette.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: palette.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: palette.accent),
            ),
          ),
        ),
      ],
    );
  }
}

class _TraitChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Function(bool) onSelected;

  const _TraitChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      backgroundColor: palette.surface,
      selectedColor: palette.accent.withValues(alpha: 0.2),
      checkmarkColor: palette.accent,
      labelStyle: TextStyle(
        color: isSelected ? palette.accent : palette.muted,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isSelected ? palette.accent : palette.line),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final bool isPrimary;

  const _NavButton({
    required this.onPressed,
    required this.label,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return isPrimary
        ? ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.accent,
              foregroundColor: palette.onAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
            ),
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.muted,
              side: BorderSide(color: palette.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            ),
            child: Text(label),
          );
  }
}
