class CharacterModel {
  final String id;
  final String name;
  final String description;
  final Map<String, dynamic> personalityTraits;
  final String? backgroundStory;

  CharacterModel({
    required this.id,
    required this.name,
    required this.description,
    required this.personalityTraits,
    this.backgroundStory,
  });

  factory CharacterModel.fromJson(Map<String, dynamic> json) {
    return CharacterModel(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      personalityTraits: json['personality_traits'] ?? {},
      backgroundStory: json['background_story'],
    );
  }
}
