class CharacterModel {
  final String id;
  final String name;
  final String description;
  final Map<String, dynamic> personalityTraits;
  final String? backgroundStory;
  final String? imageUrl;

  CharacterModel({
    required this.id,
    required this.name,
    required this.description,
    required this.personalityTraits,
    this.backgroundStory,
    this.imageUrl,
  });

  factory CharacterModel.fromJson(Map<String, dynamic> json) {
    return CharacterModel(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      // Ensure we parse correctly whether it's a Map or a List from the backend
      personalityTraits: json['personality_traits'] is Map
          ? Map<String, dynamic>.from(json['personality_traits'])
          : json['personality_traits'] is List
          ? {'traits': List<String>.from(json['personality_traits'])}
          : {},
      backgroundStory: json['background_story'],
      imageUrl: json['image_url'],
    );
  }
}
