import 'package:equatable/equatable.dart';

/// Represents an FCM token for a user.
class FcmToken extends Equatable {
  const FcmToken({
    required this.userId,
    required this.token,
    this.platform,
    this.updatedAt,
  });

  final String userId;
  final String token;
  final String? platform; // 'android', 'ios', 'web'
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [userId, token, platform, updatedAt];

  FcmToken copyWith({
    String? userId,
    String? token,
    String? platform,
    DateTime? updatedAt,
  }) {
    return FcmToken(
      userId: userId ?? this.userId,
      token: token ?? this.token,
      platform: platform ?? this.platform,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
