import 'package:material_ui/material_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:frontend/l10n/app_localizations.dart';
import '../../../../core/theme/app_palette.dart';
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
                  AppLocalizations.of(context)!.worldTheme,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.worldThemeDesc,
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                const SizedBox(height: 40),

                // Narrative Type Selection
                _SectionTitle(title: "서사 유형"),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _CustomChoiceChip(
                        label: "1인 주인공",
                        isSelected: widget.config.narrativeType == 'hero',
                        onSelected: (_) => setState(
                          () => widget.config.narrativeType = 'hero',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CustomChoiceChip(
                        label: "군상극",
                        isSelected: widget.config.narrativeType == 'ensemble',
                        onSelected: (_) => setState(
                          () => widget.config.narrativeType = 'ensemble',
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.05, end: 0),

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
                onPressed:
                    (widget.config.genreLabel != null &&
                        widget.config.toneLabel != null)
                    ? widget.onNext
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.accent,
                  foregroundColor: palette.onAccent,
                  disabledBackgroundColor: palette.surface,
                  disabledForegroundColor: palette.faint,
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
    final palette = context.palette;
    return Text(
      title,
      style: TextStyle(
        color: palette.muted,
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
  final Function(bool) onSelected;

  const _CustomChoiceChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: () => onSelected(true),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? palette.accent.withValues(alpha: 0.15)
              : palette.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? palette.accent : palette.line,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? palette.accent : palette.muted,
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
  final ValueChanged<String?> onChanged;

  const _CustomDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            hint,
            style: TextStyle(color: palette.faint, fontSize: 14),
          ),
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: palette.accent),
          dropdownColor: palette.surface,
          borderRadius: BorderRadius.circular(16),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: TextStyle(color: palette.text, fontSize: 15),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
