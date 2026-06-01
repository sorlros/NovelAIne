import 'story_model.dart';

class CommunityStoryModel {
  final StoryModel story;
  final int likeCount;
  final int commentCount;
  final bool isLiked;

  const CommunityStoryModel({
    required this.story,
    required this.likeCount,
    required this.commentCount,
    required this.isLiked,
  });

  factory CommunityStoryModel.fromJson(Map<String, dynamic> json) {
    return CommunityStoryModel(
      story: StoryModel.fromJson(json),
      likeCount: json['like_count'] ?? 0,
      commentCount: json['comment_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
    );
  }
}

class StoryCommentModel {
  final String id;
  final String storyId;
  final String userId;
  final String content;
  final String authorUsername;
  final String? authorAvatarUrl;
  final int reportCount;
  final String moderationStatus;
  final DateTime createdAt;

  const StoryCommentModel({
    required this.id,
    required this.storyId,
    required this.userId,
    required this.content,
    required this.authorUsername,
    this.authorAvatarUrl,
    this.reportCount = 0,
    this.moderationStatus = 'visible',
    required this.createdAt,
  });

  factory StoryCommentModel.fromJson(Map<String, dynamic> json) {
    return StoryCommentModel(
      id: json['id'],
      storyId: json['story_id'],
      userId: json['user_id'],
      content: json['content'] ?? '',
      authorUsername: json['author']?['username'] ?? 'Traveler',
      authorAvatarUrl: json['author']?['avatar_url'],
      reportCount: json['report_count'] ?? 0,
      moderationStatus: json['moderation_status'] ?? 'visible',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
