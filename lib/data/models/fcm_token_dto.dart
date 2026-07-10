import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/fcm_token.dart';

/// Data Transfer Object for FCM Token.
class FcmTokenDto {
  const FcmTokenDto({
    required this.userId,
    required this.token,
    this.platform,
    this.updatedAt,
  });

  final String userId;
  final String token;
  final String? platform;
  final Timestamp? updatedAt;

  factory FcmTokenDto.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return FcmTokenDto(
      userId: doc.id,
      token: data['token'] as String,
      platform: data['platform'] as String?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'token': token,
      if (platform != null) 'platform': platform,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static const String collectionName = 'fcm_tokens';
}

/// Mapper for FCM Token entity <-> DTO conversion.
class FcmTokenMapper {
  const FcmTokenMapper._();

  static FcmToken toEntity(FcmTokenDto dto) {
    return FcmToken(
      userId: dto.userId,
      token: dto.token,
      platform: dto.platform,
      updatedAt: dto.updatedAt?.toDate(),
    );
  }

  static FcmTokenDto toDto(FcmToken entity) {
    return FcmTokenDto(
      userId: entity.userId,
      token: entity.token,
      platform: entity.platform,
      updatedAt: entity.updatedAt != null
          ? Timestamp.fromDate(entity.updatedAt!)
          : null,
    );
  }
}
