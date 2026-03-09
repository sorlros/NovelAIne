class StoryModel {
  final String id;
  final String title;
  final String genre;
  final String description;
  final String status;
  final int totalScenes;
  final String? coverImageUrl;
  final DateTime createdAt;

  StoryModel({
    required this.id,
    required this.title,
    required this.genre,
    required this.description,
    required this.status,
    required this.totalScenes,
    this.coverImageUrl,
    required this.createdAt,
  });

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    return StoryModel(
      id: json['id'],
      title: json['title'],
      genre: json['genre'],
      description: json['description'] ?? '',
      status: json['status'],
      totalScenes: json['total_scenes'] ?? 0,
      coverImageUrl: json['cover_image_url'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
