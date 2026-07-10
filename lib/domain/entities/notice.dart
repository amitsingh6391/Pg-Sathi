import 'package:equatable/equatable.dart';

/// Represents a notice/announcement posted by a library owner.
class Notice extends Equatable {
  const Notice({
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

  /// Target audience: 'all', 'active_students', 'slot', 'seat'
  final NoticeTargetAudience targetAudience;
  
  /// Status: 'draft', 'scheduled', 'published', 'expired'
  final NoticeStatus status;

  /// Attachments (images/PDFs) stored in Firebase Storage
  final List<NoticeAttachment> attachments;

  /// External links (websites, forms, etc.)
  final List<NoticeLink> externalLinks;

  /// When to publish (null = publish immediately)
  final DateTime? scheduledFor;

  /// When to expire (null = never expires)
  final DateTime? expiresAt;

  /// When actually published
  final DateTime? publishedAt;

  /// When last updated
  final DateTime? updatedAt;

  /// Created timestamp
  final DateTime createdAt;

  /// Whether to send push notification on publish
  final bool sendPushNotification;

  /// Analytics: how many times viewed
  final int viewCount;

  /// Analytics: how many unique students marked as read
  final int readCount;

  /// Analytics: cached comment count (updated when comments are added)
  final int commentCount;

  /// Last time a comment was added (for cache invalidation)
  final DateTime? lastCommentAt;

  /// For slot-specific targeting (future-safe)
  final List<String> targetSlotIds;

  /// For seat-specific targeting (future-safe)
  final List<String> targetSeatIds;

  /// Check if notice is currently active (published and not expired)
  bool get isActive {
    if (status != NoticeStatus.published) return false;
    final now = DateTime.now();
    if (expiresAt != null && now.isAfter(expiresAt!)) return false;
    return true;
  }

  /// Check if notice is scheduled for future
  bool get isScheduled {
    if (status != NoticeStatus.scheduled) return false;
    if (scheduledFor == null) return false;
    return DateTime.now().isBefore(scheduledFor!);
  }

  /// Check if notice has expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Get human-readable target audience description
  String get targetAudienceDescription {
    switch (targetAudience) {
      case NoticeTargetAudience.all:
        return 'All Students';
      case NoticeTargetAudience.activeStudents:
        return 'Active Students Only';
      case NoticeTargetAudience.slot:
        return 'Specific Slots (${targetSlotIds.length})';
      case NoticeTargetAudience.seat:
        return 'Specific Seats (${targetSeatIds.length})';
    }
  }

  /// Create a copy with updated fields
  Notice copyWith({
    String? id,
    String? libraryId,
    String? ownerId,
    String? title,
    String? description,
    NoticeTargetAudience? targetAudience,
    NoticeStatus? status,
    List<NoticeAttachment>? attachments,
    List<NoticeLink>? externalLinks,
    DateTime? scheduledFor,
    DateTime? expiresAt,
    DateTime? publishedAt,
    DateTime? updatedAt,
    DateTime? createdAt,
    bool? sendPushNotification,
    int? viewCount,
    int? readCount,
    int? commentCount,
    DateTime? lastCommentAt,
    List<String>? targetSlotIds,
    List<String>? targetSeatIds,
  }) {
    return Notice(
      id: id ?? this.id,
      libraryId: libraryId ?? this.libraryId,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      description: description ?? this.description,
      targetAudience: targetAudience ?? this.targetAudience,
      status: status ?? this.status,
      attachments: attachments ?? this.attachments,
      externalLinks: externalLinks ?? this.externalLinks,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      expiresAt: expiresAt ?? this.expiresAt,
      publishedAt: publishedAt ?? this.publishedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      sendPushNotification: sendPushNotification ?? this.sendPushNotification,
      viewCount: viewCount ?? this.viewCount,
      readCount: readCount ?? this.readCount,
      commentCount: commentCount ?? this.commentCount,
      lastCommentAt: lastCommentAt ?? this.lastCommentAt,
      targetSlotIds: targetSlotIds ?? this.targetSlotIds,
      targetSeatIds: targetSeatIds ?? this.targetSeatIds,
    );
  }

  @override
  List<Object?> get props => [
        id,
        libraryId,
        ownerId,
        title,
        description,
        targetAudience,
        status,
        attachments,
        externalLinks,
        scheduledFor,
        expiresAt,
        publishedAt,
        updatedAt,
        createdAt,
        sendPushNotification,
        viewCount,
        readCount,
        commentCount,
        lastCommentAt,
        targetSlotIds,
        targetSeatIds,
      ];
}

/// Notice attachment (image or PDF)
class NoticeAttachment extends Equatable {
  const NoticeAttachment({
    required this.id,
    required this.url,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
  });

  final String id;
  final String url; // Firebase Storage URL
  final String fileName;
  final AttachmentType fileType;
  final int fileSize; // in bytes

  /// Get file size in human-readable format
  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'fileName': fileName,
      'fileType': fileType.name,
      'fileSize': fileSize,
    };
  }

  factory NoticeAttachment.fromMap(Map<String, dynamic> map) {
    return NoticeAttachment(
      id: map['id'] as String,
      url: map['url'] as String,
      fileName: map['fileName'] as String,
      fileType: AttachmentType.values.firstWhere(
        (e) => e.name == map['fileType'],
        orElse: () => AttachmentType.image,
      ),
      fileSize: map['fileSize'] as int,
    );
  }

  @override
  List<Object?> get props => [id, url, fileName, fileType, fileSize];
}

/// Notice external link
class NoticeLink extends Equatable {
  const NoticeLink({
    required this.id,
    required this.url,
    required this.title,
  });

  final String id;
  final String url;
  final String title;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'title': title,
    };
  }

  factory NoticeLink.fromMap(Map<String, dynamic> map) {
    return NoticeLink(
      id: map['id'] as String,
      url: map['url'] as String,
      title: map['title'] as String,
    );
  }

  @override
  List<Object?> get props => [id, url, title];
}

/// Attachment file types
enum AttachmentType {
  image,
  pdf,
}

/// Notice target audience options
enum NoticeTargetAudience {
  all,
  activeStudents,
  slot, // Future: specific time slots
  seat, // Future: specific seats
}

/// Notice status
enum NoticeStatus {
  draft,
  scheduled,
  published,
  expired,
}

/// Notice read status for a specific student
class NoticeReadStatus extends Equatable {
  const NoticeReadStatus({
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

  @override
  List<Object?> get props => [noticeId, studentId, libraryId, isRead, readAt];
}
