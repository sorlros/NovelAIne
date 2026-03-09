class UserModel {
  final String id;
  final String email;
  final String username;
  final String avatarUrl;

  UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.avatarUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final meta = json['user_metadata'] ?? {};
    return UserModel(
      id: json['id'],
      email: json['email'],
      username: meta['username'] ?? 'Traveler',
      avatarUrl:
          meta['avatar_url'] ?? 'https://i.pravatar.cc/150?u=${json['id']}',
    );
  }
}
