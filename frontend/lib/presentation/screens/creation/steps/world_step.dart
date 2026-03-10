import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
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
      child: ListView(
        children: [
          Text(
            AppLocalizations.of(context)!.worldTheme,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.worldThemeDesc,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),

          // Genre Selection
          Text(
            AppLocalizations.of(context)!.genreLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
          Text(
            AppLocalizations.of(context)!.toneLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: widget.config.toneLabel,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.toneSelect,
              border: const OutlineInputBorder(),
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

          const SizedBox(height: 32),

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
                widget.isQuickStart
                    ? AppLocalizations.of(context)!.startAdventureAuto
                    : AppLocalizations.of(context)!.nextProtagonistSetup,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
