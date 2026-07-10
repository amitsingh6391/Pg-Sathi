import 'dart:io';

import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/notice.dart';
import '../repositories/notice_repository.dart';

/// Use case for creating a new notice
class CreateNotice {
  const CreateNotice(this.repository);

  final NoticeRepository repository;

  Future<Either<Failure, Notice>> call({
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
  }) {
    return repository.createNotice(
      libraryId: libraryId,
      ownerId: ownerId,
      title: title,
      description: description,
      targetAudience: targetAudience,
      attachmentFiles: attachmentFiles,
      externalLinks: externalLinks,
      scheduledFor: scheduledFor,
      expiresAt: expiresAt,
      sendPushNotification: sendPushNotification,
      targetSlotIds: targetSlotIds,
      targetSeatIds: targetSeatIds,
    );
  }
}

/// Use case for updating a notice
class UpdateNotice {
  const UpdateNotice(this.repository);

  final NoticeRepository repository;

  Future<Either<Failure, Notice>> call({
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
  }) {
    return repository.updateNotice(
      noticeId: noticeId,
      title: title,
      description: description,
      targetAudience: targetAudience,
      newAttachmentFiles: newAttachmentFiles,
      existingAttachments: existingAttachments,
      externalLinks: externalLinks,
      scheduledFor: scheduledFor,
      expiresAt: expiresAt,
      sendPushNotification: sendPushNotification,
      targetSlotIds: targetSlotIds,
      targetSeatIds: targetSeatIds,
    );
  }
}

/// Use case for deleting a notice
class DeleteNotice {
  const DeleteNotice(this.repository);

  final NoticeRepository repository;

  Future<Either<Failure, void>> call(String noticeId) {
    return repository.deleteNotice(noticeId);
  }
}

/// Use case for publishing a notice
class PublishNotice {
  const PublishNotice(this.repository);

  final NoticeRepository repository;

  Future<Either<Failure, Notice>> call(String noticeId) {
    return repository.publishNotice(noticeId);
  }
}

/// Use case for getting all notices for a library (owner view)
class GetNoticesByLibrary {
  const GetNoticesByLibrary(this.repository);

  final NoticeRepository repository;

  Future<Either<Failure, List<Notice>>> call(String libraryId) {
    return repository.getNoticesByLibrary(libraryId);
  }
}

/// Use case for getting active notices for a student
class GetActiveNoticesForStudent {
  const GetActiveNoticesForStudent(this.repository);

  final NoticeRepository repository;

  Future<Either<Failure, List<Notice>>> call({
    required String libraryId,
    required String studentId,
  }) {
    return repository.getActiveNoticesForStudent(
      libraryId: libraryId,
      studentId: studentId,
    );
  }
}

/// Use case for marking a notice as read
class MarkNoticeAsRead {
  const MarkNoticeAsRead(this.repository);

  final NoticeRepository repository;

  Future<Either<Failure, void>> call({
    required String noticeId,
    required String studentId,
    required String libraryId,
  }) {
    return repository.markNoticeAsRead(
      noticeId: noticeId,
      studentId: studentId,
      libraryId: libraryId,
    );
  }
}

/// Use case for getting read status for a student
class GetReadStatusForStudent {
  const GetReadStatusForStudent(this.repository);

  final NoticeRepository repository;

  Future<Either<Failure, Map<String, NoticeReadStatus>>> call({
    required String studentId,
    required String libraryId,
  }) {
    return repository.getReadStatusForStudent(
      studentId: studentId,
      libraryId: libraryId,
    );
  }
}

/// Use case for getting a notice by ID
class GetNoticeById {
  const GetNoticeById(this.repository);

  final NoticeRepository repository;

  Future<Either<Failure, Notice>> call(String noticeId) {
    return repository.getNoticeById(noticeId);
  }
}

/// Use case for incrementing view count
class IncrementNoticeViewCount {
  const IncrementNoticeViewCount(this.repository);

  final NoticeRepository repository;

  Future<Either<Failure, void>> call({
    required String noticeId,
    required String userId,
  }) {
    return repository.incrementViewCount(
      noticeId: noticeId,
      userId: userId,
    );
  }
}

/// Use case for getting notice analytics
class GetNoticeAnalytics {
  const GetNoticeAnalytics(this.repository);

  final NoticeRepository repository;

  Future<Either<Failure, NoticeAnalytics>> call({
    required String libraryId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return repository.getNoticeAnalytics(
      libraryId: libraryId,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
