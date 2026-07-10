import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/notice.dart';

/// Firestore model for Notice entity
class NoticeModel {
  const NoticeModel({
    required this.id,
    required this.libraryId,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.targetAudience,
    required this.status,
    required this.createdAt,
    this.attachments = const [],
    this.externalLinks = const [],
    this.scheduledFor,
    this.expiresAt,
    this.publishedAt,
    this.updatedAt,
    this.sendPushNotification = true,
    this.viewCount = 0,
    this.readCount = 0,
    this.commentCount = 0,
    this.lastCommentAt,
    this.targetSlotIds = const [],
    this.targetSeatIds = const [],
  });

  final String id;
  final String libraryId;
  final String ownerId;
  final String title;
  final String description;
  final String targetAudience;
  final String status;
  final List<Map<String, dynamic>> attachments;
  final List<Map<String, dynamic>> externalLinks;
  final DateTime? scheduledFor;
  final DateTime? expiresAt;
  final DateTime? publishedAt;
  final DateTime? updatedAt;
  final DateTime createdAt;
  final bool sendPushNotification;
  final int viewCount;
  final int readCount;
  final int commentCount;
  final DateTime? lastCommentAt;
  final List<String> targetSlotIds;
  final List<String> targetSeatIds;

  /// Convert Firestore document to NoticeModel
  factory NoticeModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return NoticeModel(
      id: doc.id,
      libraryId: data['libraryId'] as String,
      ownerId: data['ownerId'] as String,
      title: data['title'] as String,
      description: data['description'] as String,
      targetAudience: data['targetAudience'] as String,
      status: data['status'] as String,
      attachments:
          (data['attachments'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
      externalLinks:
          (data['externalLinks'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
      scheduledFor: (data['scheduledFor'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      publishedAt: (data['publishedAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      sendPushNotification: data['sendPushNotification'] as bool? ?? true,
      viewCount: data['viewCount'] as int? ?? 0,
      readCount: data['readCount'] as int? ?? 0,
      commentCount: data['commentCount'] as int? ?? 0,
      lastCommentAt: (data['lastCommentAt'] as Timestamp?)?.toDate(),
      targetSlotIds:
          (data['targetSlotIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      targetSeatIds:
          (data['targetSeatIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  /// Convert NoticeModel to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'libraryId': libraryId,
      'ownerId': ownerId,
      'title': title,
      'description': description,
      'targetAudience': targetAudience,
      'status': status,
      'attachments': attachments,
      'externalLinks': externalLinks,
      'scheduledFor': scheduledFor != null
          ? Timestamp.fromDate(scheduledFor!)
          : null,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'publishedAt': publishedAt != null
          ? Timestamp.fromDate(publishedAt!)
          : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'sendPushNotification': sendPushNotification,
      'viewCount': viewCount,
      'readCount': readCount,
      'commentCount': commentCount,
      'lastCommentAt': lastCommentAt != null
          ? Timestamp.fromDate(lastCommentAt!)
          : null,
      'targetSlotIds': targetSlotIds,
      'targetSeatIds': targetSeatIds,
    };
  }

  /// Convert NoticeModel to Notice entity
  Notice toEntity() {
    return Notice(
      id: id,
      libraryId: libraryId,
      ownerId: ownerId,
      title: title,
      description: description,
      targetAudience: NoticeTargetAudience.values.firstWhere(
        (e) => e.name == targetAudience,
        orElse: () => NoticeTargetAudience.all,
      ),
      status: NoticeStatus.values.firstWhere(
        (e) => e.name == status,
        orElse: () => NoticeStatus.draft,
      ),
      attachments: attachments.map((e) => NoticeAttachment.fromMap(e)).toList(),
      externalLinks: externalLinks.map((e) => NoticeLink.fromMap(e)).toList(),
      scheduledFor: scheduledFor,
      expiresAt: expiresAt,
      publishedAt: publishedAt,
      updatedAt: updatedAt,
      createdAt: createdAt,
      sendPushNotification: sendPushNotification,
      viewCount: viewCount,
      readCount: readCount,
      commentCount: commentCount,
      lastCommentAt: lastCommentAt,
      targetSlotIds: targetSlotIds,
      targetSeatIds: targetSeatIds,
    );
  }

  /// Create NoticeModel from Notice entity
  factory NoticeModel.fromEntity(Notice notice) {
    return NoticeModel(
      id: notice.id,
      libraryId: notice.libraryId,
      ownerId: notice.ownerId,
      title: notice.title,
      description: notice.description,
      targetAudience: notice.targetAudience.name,
      status: notice.status.name,
      attachments: notice.attachments.map((e) => e.toMap()).toList(),
      externalLinks: notice.externalLinks.map((e) => e.toMap()).toList(),
      scheduledFor: notice.scheduledFor,
      expiresAt: notice.expiresAt,
      publishedAt: notice.publishedAt,
      updatedAt: notice.updatedAt,
      createdAt: notice.createdAt,
      sendPushNotification: notice.sendPushNotification,
      viewCount: notice.viewCount,
      readCount: notice.readCount,
      commentCount: notice.commentCount,
      lastCommentAt: notice.lastCommentAt,
      targetSlotIds: notice.targetSlotIds,
      targetSeatIds: notice.targetSeatIds,
    );
  }
}

/// Firestore model for NoticeReadStatus
class NoticeReadStatusModel {
  const NoticeReadStatusModel({
    required this.noticeId,
    required this.studentId,
    required this.libraryId,
    required this.isRead,
    this.readAt,
  });

  final String noticeId;
  final String studentId;
  final String libraryId;
  final bool isRead;
  final DateTime? readAt;

  /// Convert Firestore document to NoticeReadStatusModel
  factory NoticeReadStatusModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return NoticeReadStatusModel(
      noticeId: data['noticeId'] as String,
      studentId: data['studentId'] as String,
      libraryId: data['libraryId'] as String,
      isRead: data['isRead'] as bool,
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert NoticeReadStatusModel to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'noticeId': noticeId,
      'studentId': studentId,
      'libraryId': libraryId,
      'isRead': isRead,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
    };
  }

  /// Convert NoticeReadStatusModel to NoticeReadStatus entity
  NoticeReadStatus toEntity() {
    return NoticeReadStatus(
      noticeId: noticeId,
      studentId: studentId,
      libraryId: libraryId,
      isRead: isRead,
      readAt: readAt,
    );
  }

  /// Create NoticeReadStatusModel from NoticeReadStatus entity
  factory NoticeReadStatusModel.fromEntity(NoticeReadStatus status) {
    return NoticeReadStatusModel(
      noticeId: status.noticeId,
      studentId: status.studentId,
      libraryId: status.libraryId,
      isRead: status.isRead,
      readAt: status.readAt,
    );
  }
}
