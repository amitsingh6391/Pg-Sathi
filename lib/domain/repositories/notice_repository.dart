import 'dart:io';

import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/notice.dart';

/// Repository interface for managing notices/announcements.
abstract class NoticeRepository {
  /// Create a new notice (owner only)
  Future<Either<Failure, Notice>> createNotice({
    required String libraryId,
    required String ownerId,
    required String title,
    required String description,
    required NoticeTargetAudience targetAudience,
    List<File> attachmentFiles = const [],
    List<NoticeLink> externalLinks = const [],
    DateTime? scheduledFor,
    DateTime? expiresAt,
    bool sendPushNotification = true,
    List<String> targetSlotIds = const [],
    List<String> targetSeatIds = const [],
  });

  /// Update an existing notice
  Future<Either<Failure, Notice>> updateNotice({
    required String noticeId,
    String? title,
    String? description,
    NoticeTargetAudience? targetAudience,
    List<File>? newAttachmentFiles,
    List<NoticeAttachment>? existingAttachments,
    List<NoticeLink>? externalLinks,
    DateTime? scheduledFor,
    DateTime? expiresAt,
    bool? sendPushNotification,
    List<String>? targetSlotIds,
    List<String>? targetSeatIds,
  });

  /// Delete a notice
  Future<Either<Failure, void>> deleteNotice(String noticeId);

  /// Publish a draft or scheduled notice
  Future<Either<Failure, Notice>> publishNotice(String noticeId);

  /// Get all notices for a library (owner view)
  Future<Either<Failure, List<Notice>>> getNoticesByLibrary(String libraryId);

  /// Get active notices for students
  Future<Either<Failure, List<Notice>>> getActiveNoticesForStudent({
    required String libraryId,
    required String studentId,
  });

  /// Mark notice as read by student
  Future<Either<Failure, void>> markNoticeAsRead({
    required String noticeId,
    required String studentId,
    required String libraryId,
  });

  /// Get read status for a student's notices
  Future<Either<Failure, Map<String, NoticeReadStatus>>> getReadStatusForStudent({
    required String studentId,
    required String libraryId,
  });

  /// Get notice by ID
  Future<Either<Failure, Notice>> getNoticeById(String noticeId);

  /// Increment view count for a notice (only once per user)
  Future<Either<Failure, void>> incrementViewCount({
    required String noticeId,
    required String userId,
  });

  /// Get notice analytics (read rate, view count, etc.)
  Future<Either<Failure, NoticeAnalytics>> getNoticeAnalytics({
    required String libraryId,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Schedule expired notices check (background job)
  Future<Either<Failure, void>> updateExpiredNotices();
}

/// Notice analytics data
class NoticeAnalytics {
  const NoticeAnalytics({
    required this.totalNotices,
    required this.publishedNotices,
    required this.activeNotices,
    required this.expiredNotices,
    required this.averageReadRate,
    required this.noticeReadRates,
  });

  final int totalNotices;
  final int publishedNotices;
  final int activeNotices;
  final int expiredNotices;
  final double averageReadRate; // 0.0 to 1.0
  final Map<String, double> noticeReadRates; // noticeId -> read rate

  Map<String, dynamic> toMap() {
    return {
      'totalNotices': totalNotices,
      'publishedNotices': publishedNotices,
      'activeNotices': activeNotices,
      'expiredNotices': expiredNotices,
      'averageReadRate': averageReadRate,
      'noticeReadRates': noticeReadRates,
    };
  }
}
