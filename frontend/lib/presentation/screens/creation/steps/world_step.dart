import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:frontend/l10n/app_localizations.dart';
import '../../../../data/models/creation_config.dart';
import '../../../../data/constants/creation_prompts.dart';

class WorldStep extends StatefulWidget {
  final CreationConfig config;
  final bool isQuickStart;
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
    final accentColor = widget.isQuickStart 
        ? const Color(0xFFFFD700) 
        : const Color(0xFF00E5FF);

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
                  AppLocalizations.of(context)!.worldTheme,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.worldThemeDesc,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                const SizedBox(height: 40),

                // Genre Selection
                _SectionTitle(title: AppLocalizations.of(context)!.genreLabel),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: CreationPrompts.genres.entries.map((entry) {
                    final isSelected = widget.config.genreLabel == entry.key;
                    return _CustomChoiceChip(
                      label: entry.key,
                      isSelected: isSelected,
                      accentColor: accentColor,
                      onSelected: (selected) {
                        setState(() {
                          widget.config.genreLabel = entry.key;
                          widget.config.genrePrompt = entry.value;
                        });
                      },
                    );
                  }).toList(),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05, end: 0),

                const SizedBox(height: 40),

                // Tone Selection
                _SectionTitle(title: AppLocalizations.of(context)!.toneLabel),
                const SizedBox(height: 16),
                _CustomDropdown(
                  value: widget.config.toneLabel,
                  hint: AppLocalizations.of(context)!.toneSelect,
                  items: CreationPrompts.tones.keys.toList(),
                  accentColor: accentColor,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        widget.config.toneLabel = value;
                        widget.config.tonePrompt = CreationPrompts.tones[value];
                      });
                    }
                  },
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05, end: 0),
                
                const SizedBox(height: 32),
              ],
            ),
          ),
          
          // Bottom Button Area
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (widget.config.genreLabel != null &&
                        widget.config.toneLabel != null)
                    ? widget.onNext
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white.withOpacity(0.05),
                  disabledForegroundColor: Colors.white24,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  widget.isQuickStart
                      ? AppLocalizations.of(context)!.startAdventureAuto
                      : AppLocalizations.of(context)!.nextProtagonistSetup,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(delay: 400.ms),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _CustomChoiceChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color accentColor;
  final Function(bool) onSelected;

  const _CustomChoiceChip({
    required this.label,
    required this.isSelected,
    required this.accentColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onSelected(true),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withOpacity(0.15) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accentColor : Colors.white10,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? accentColor : Colors.white70,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _CustomDropdown extends StatelessWidget {
  final String? value;
  final String hint;
  final List<String> items;
  final Color accentColor;
  final ValueChanged<String?> onChanged;

  const _CustomDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(color: Colors.white30, fontSize: 14)),
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: accentColor),
          dropdownColor: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
