import 'user_model.dart';

class AuthSessionModel {
  final UserModel user;
  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;

  const AuthSessionModel({
    required this.user,
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  bool get isExpired {
    final expiry = expiresAt;
    if (expiry == null) {
      return false;
    }
    return DateTime.now().toUtc().isAfter(expiry);
  }

  bool get shouldRefreshSoon {
    final expiry = expiresAt;
    if (expiry == null) {
      return false;
    }
    return DateTime.now().toUtc().isAfter(
      expiry.subtract(const Duration(minutes: 2)),
    );
  }

  factory AuthSessionModel.fromAuthResponse(Map<String, dynamic> data) {
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    final session = data['session'] as Map<String, dynamic>?;
    final accessToken = session?['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('인증 세션 토큰을 찾을 수 없습니다.');
    }

    DateTime? expiresAt;
    final expiresAtRaw = session?['expires_at'];
    if (expiresAtRaw is int) {
      expiresAt = DateTime.fromMillisecondsSinceEpoch(
        expiresAtRaw * 1000,
        isUtc: true,
      );
    } else if (expiresAtRaw is num) {
      expiresAt = DateTime.fromMillisecondsSinceEpoch(
        expiresAtRaw.toInt() * 1000,
        isUtc: true,
      );
    } else if (expiresAtRaw is String) {
      expiresAt = DateTime.tryParse(expiresAtRaw)?.toUtc();
    }

    final expiresInRaw = session?['expires_in'];
    if (expiresAt == null && expiresInRaw is int) {
      expiresAt = DateTime.now().toUtc().add(Duration(seconds: expiresInRaw));
    } else if (expiresAt == null && expiresInRaw is num) {
      expiresAt = DateTime.now().toUtc().add(
        Duration(seconds: expiresInRaw.toInt()),
      );
    }

    return AuthSessionModel(
      user: user,
      accessToken: accessToken,
      refreshToken: session?['refresh_token'] as String?,
      expiresAt: expiresAt,
    );
  }

  factory AuthSessionModel.fromJson(Map<String, dynamic> json) {
    final expiresAtRaw = json['expires_at'] as String?;
    return AuthSessionModel(
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String?,
      expiresAt: expiresAtRaw == null
          ? null
          : DateTime.parse(expiresAtRaw).toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'access_token': accessToken,
      if (refreshToken != null) 'refresh_token': refreshToken,
      if (expiresAt != null) 'expires_at': expiresAt!.toUtc().toIso8601String(),
    };
  }
}
