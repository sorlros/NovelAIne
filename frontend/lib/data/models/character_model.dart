class CharacterModel {
  final String id;
  final String name;
  final String description;
  final List<String> personalityTraits;
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
      description:
          (json['description'] as String?)?.replaceAll('\\n', '\n') ?? '',
      // Ensure we parse correctly from the backend's text array (List<dynamic>)
      personalityTraits: json['personality_traits'] != null
          ? List<String>.from(json['personality_traits'])
          : [],
      backgroundStory: json['background_story'],
      imageUrl: json['image_url'],
    );
  }
}
