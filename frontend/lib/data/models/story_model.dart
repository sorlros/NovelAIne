class StoryModel {
  final String id;
  final String title;
  final String genre;
  final String description;
  final String status;
  final String narrativeType;
  final int totalScenes;
  final String? coverImageUrl;
  final String visibility;
  final DateTime? publishedAt;
  final String? authorUsername;
  final DateTime createdAt;

  StoryModel({
    required this.id,
    required this.title,
    required this.genre,
    required this.description,
    required this.status,
    required this.narrativeType,
    required this.totalScenes,
    this.coverImageUrl,
    this.visibility = 'private',
    this.publishedAt,
    this.authorUsername,
    required this.createdAt,
  });

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    return StoryModel(
      id: json['id'],
      title: json['title'],
      genre: json['genre'],
      description: json['description'] ?? '',
      status: json['status'],
      narrativeType: json['narrative_type'] ?? 'hero',
      totalScenes: json['total_scenes'] ?? 0,
      coverImageUrl: json['cover_image_url'],
      visibility: json['visibility'] ?? 'private',
      publishedAt: json['published_at'] == null
          ? null
          : DateTime.parse(json['published_at']),
      authorUsername: json['author']?['username'] ?? json['users']?['username'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  bool get isPublic => visibility == 'public';
}
