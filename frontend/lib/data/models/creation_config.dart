import 'package:flutter/foundation.dart';

class CreationConfig {
  // Mode
  final bool isQuickStart;
  String narrativeType = 'hero'; // 'hero' or 'ensemble'

  // Step 1: World
  String? genreLabel;
  String? genrePrompt;
  String? toneLabel;
  String? tonePrompt;
  String? worldSetting; // Custom or Preset

  // Step 2: Character
  String? userName;
  String? userGender;
  String? userAge;
  List<String> personalityTraits = [];
  
  // Platform agnostic image data
  Uint8List? userImageBytes; 
  String? characterImagePath; // Local path (App) or Blob URL (Web)
  
  String? imageStyle; // e.g., "Anime", "Realistic"
  String? appearanceDescription; // Visual consistency tags
  String? llmModel; // Added

  // Step 3: Hook
  String? openingScenario;

  CreationConfig({this.isQuickStart = false});

  @override
  String toString() {
    return 'CreationConfig(genre: $genreLabel, name: $userName, traits: $personalityTraits)';
  }

  // Convert key selections to a final system prompt for the LLM
  String toSystemPrompt() {
    return """
    Genre: $genrePrompt
    Tone: $tonePrompt
    Setting: $worldSetting
    Protagonist: $userName ($userAge, $userGender)
    Traits: ${personalityTraits.join(", ")}
    Opening: $openingScenario
    """;
  }
}
