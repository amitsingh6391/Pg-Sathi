import 'dart:io';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../failures/data_failures.dart';
import '../services/storage_service.dart' as data_storage;
import '../../domain/core/failure.dart';
import '../../domain/entities/notice.dart';
import '../../domain/repositories/notice_repository.dart';
import '../../domain/repositories/notification_repository.dart';
import '../models/notice_model.dart';

/// Firestore implementation of NoticeRepository.
class NoticeRepositoryImpl implements NoticeRepository {
  const NoticeRepositoryImpl({
    required this.firestore,
    required this.storageService,
    this.notificationRepository,
  });

  final FirebaseFirestore firestore;
  final data_storage.StorageService storageService;
  final NotificationRepository? notificationRepository;

  @override
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
  }) async {
    try {
      final noticeId = const Uuid().v4();
      final now = DateTime.now();

      // Upload attachments to Firebase Storage
      final attachments = <NoticeAttachment>[];
      for (final file in attachmentFiles) {
        final attachment = await _uploadAttachment(
          file: file,
          noticeId: noticeId,
          libraryId: libraryId,
        );
        attachments.add(attachment);
      }

      // Determine initial status
      NoticeStatus status;
      DateTime? publishedAt;

      if (scheduledFor != null && scheduledFor.isAfter(now)) {
        status = NoticeStatus.scheduled;
      } else {
        status = NoticeStatus.published;
        publishedAt = now;
      }

      final noticeModel = NoticeModel(
        id: noticeId,
        libraryId: libraryId,
        ownerId: ownerId,
        title: title,
        description: description,
        targetAudience: targetAudience.name,
        status: status.name,
        attachments: attachments.map((e) => e.toMap()).toList(),
        externalLinks: externalLinks.map((e) => e.toMap()).toList(),
        scheduledFor: scheduledFor,
        expiresAt: expiresAt,
        publishedAt: publishedAt,
        createdAt: now,
        sendPushNotification: sendPushNotification,
        targetSlotIds: targetSlotIds,
        targetSeatIds: targetSeatIds,
      );

      await firestore
          .collection('notices')
          .doc(noticeId)
          .set(noticeModel.toFirestore());

      // Send push notifications if notice is published immediately (not scheduled)
      if (status == NoticeStatus.published &&
          sendPushNotification &&
          notificationRepository != null) {
        await _sendNoticePublishedNotification(noticeModel.toEntity());
      }

      return Right(noticeModel.toEntity());
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to create notice: $e'));
    }
  }

  @override
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
  }) async {
    try {
      final docRef = firestore.collection('notices').doc(noticeId);
      final doc = await docRef.get();

      if (!doc.exists) {
        return Left(DocumentNotFoundFailure(message: 'Notice not found'));
      }

      final currentNotice = NoticeModel.fromFirestore(doc).toEntity();

      // Handle new attachments
      List<NoticeAttachment> updatedAttachments =
          existingAttachments ?? currentNotice.attachments;

      if (newAttachmentFiles != null && newAttachmentFiles.isNotEmpty) {
        for (final file in newAttachmentFiles) {
          final attachment = await _uploadAttachment(
            file: file,
            noticeId: noticeId,
            libraryId: currentNotice.libraryId,
          );
          updatedAttachments = [...updatedAttachments, attachment];
        }
      }

      // Prepare update data
      final updateData = <String, dynamic>{
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      if (title != null) updateData['title'] = title;
      if (description != null) updateData['description'] = description;
      if (targetAudience != null) {
        updateData['targetAudience'] = targetAudience.name;
      }
      if (externalLinks != null) {
        updateData['externalLinks'] = externalLinks
            .map((e) => e.toMap())
            .toList();
      }
      if (scheduledFor != null) {
        updateData['scheduledFor'] = Timestamp.fromDate(scheduledFor);
      }
      if (expiresAt != null) {
        updateData['expiresAt'] = Timestamp.fromDate(expiresAt);
      }
      if (sendPushNotification != null) {
        updateData['sendPushNotification'] = sendPushNotification;
      }
      if (targetSlotIds != null) updateData['targetSlotIds'] = targetSlotIds;
      if (targetSeatIds != null) updateData['targetSeatIds'] = targetSeatIds;

      // Update attachments if changed
      if (existingAttachments != null || newAttachmentFiles != null) {
        updateData['attachments'] = updatedAttachments
            .map((e) => e.toMap())
            .toList();
      }

      await docRef.update(updateData);

      // Build updated entity from in-memory data instead of re-reading.
      final updatedNotice = currentNotice.copyWith(
        title: title ?? currentNotice.title,
        description: description ?? currentNotice.description,
        targetAudience: targetAudience ?? currentNotice.targetAudience,
        externalLinks: externalLinks ?? currentNotice.externalLinks,
        scheduledFor: scheduledFor ?? currentNotice.scheduledFor,
        expiresAt: expiresAt ?? currentNotice.expiresAt,
        sendPushNotification:
            sendPushNotification ?? currentNotice.sendPushNotification,
        targetSlotIds: targetSlotIds ?? currentNotice.targetSlotIds,
        targetSeatIds: targetSeatIds ?? currentNotice.targetSeatIds,
        attachments: updatedAttachments,
        updatedAt: DateTime.now(),
      );
      return Right(updatedNotice);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to update notice: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteNotice(String noticeId) async {
    try {
      await firestore.collection('notices').doc(noticeId).delete();

      // Also delete all read statuses for this notice
      final readStatusDocs = await firestore
          .collection('notice_read_status')
          .where('noticeId', isEqualTo: noticeId)
          .get();

      final batch = firestore.batch();
      for (final doc in readStatusDocs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to delete notice: $e'));
    }
  }

  @override
  Future<Either<Failure, Notice>> publishNotice(String noticeId) async {
    try {
      final docRef = firestore.collection('notices').doc(noticeId);
      final doc = await docRef.get();

      if (!doc.exists) {
        return Left(DocumentNotFoundFailure(message: 'Notice not found'));
      }

      final noticeModel = NoticeModel.fromFirestore(doc);
      final now = DateTime.now();

      await docRef.update({
        'status': NoticeStatus.published.name,
        'publishedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      // Send push notifications if enabled
      if (noticeModel.sendPushNotification && notificationRepository != null) {
        await _sendNoticePublishedNotification(noticeModel.toEntity());
      }

      final updatedDoc = await docRef.get();
      return Right(NoticeModel.fromFirestore(updatedDoc).toEntity());
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to publish notice: $e'));
    }
  }

  /// Sends push notification to targeted students when notice is published.
  Future<void> _sendNoticePublishedNotification(Notice notice) async {
    try {
      // Get target user IDs based on audience
      final targetUserIds = await _getTargetUserIds(notice);

      if (targetUserIds.isEmpty) {
        return;
      }

      // Prepare notification payload
      final title = 'New Announcement';
      final body = notice.title;
      final data = {
        'type': 'notice',
        'notice_id': notice.id,
        'library_id': notice.libraryId,
        'title': notice.title,
      };

      // Send notification
      await notificationRepository!.sendNotificationsToUsers(
        userIds: targetUserIds,
        title: title,
        body: body,
        data: data,
      );
    } catch (e) {
      // Log error but don't fail the publish operation
    }
  }

  /// Gets target user IDs based on notice audience settings.
  Future<List<String>> _getTargetUserIds(Notice notice) async {
    try {
      // For All Students audience - get all users with active memberships in this library
      if (notice.targetAudience == NoticeTargetAudience.all) {
        final membershipsSnapshot = await firestore
            .collection('memberships')
            .where('libraryId', isEqualTo: notice.libraryId)
            .where('status', isEqualTo: 'active')
            .get();

        final userIds = membershipsSnapshot.docs
            .map((doc) => doc.data()['userId'] as String?)
            .where((id) => id != null)
            .cast<String>()
            .toSet()
            .toList();

        return userIds;
      }

      // For Active Students audience (students with active memberships)
      if (notice.targetAudience == NoticeTargetAudience.activeStudents) {
        final membershipsSnapshot = await firestore
            .collection('memberships')
            .where('libraryId', isEqualTo: notice.libraryId)
            .where('status', isEqualTo: 'active')
            .get();

        final activeStudentIds = membershipsSnapshot.docs
            .map((doc) => doc.data()['userId'] as String?)
            .where((id) => id != null)
            .cast<String>()
            .toSet()
            .toList();

        return activeStudentIds;
      }

      // Slot-wise and seat-wise targeting not implemented yet
      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  Future<Either<Failure, List<Notice>>> getNoticesByLibrary(
    String libraryId,
  ) async {
    try {
      final snapshot = await firestore
          .collection('notices')
          .where('libraryId', isEqualTo: libraryId)
          .orderBy('createdAt', descending: true)
          .get();

      final notices = snapshot.docs
          .map((doc) => NoticeModel.fromFirestore(doc).toEntity())
          .toList();

      return Right(notices);
    } catch (e, stackTrace) {
      _logNoticeQueryError(
        operation: 'getNoticesByLibrary',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(ServerFailure(message: 'Failed to fetch notices: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Notice>>> getActiveNoticesForStudent({
    required String libraryId,
    required String studentId,
  }) async {
    try {
      final now = DateTime.now();

      // Get all published notices for the library
      final snapshot = await firestore
          .collection('notices')
          .where('libraryId', isEqualTo: libraryId)
          .where('status', isEqualTo: NoticeStatus.published.name)
          .orderBy('publishedAt', descending: true)
          .get();

      // Pre-check if student has any active membership for this library.
      // Avoids N per-notice membership queries inside _isStudentTargeted.
      final hasActiveMembership = await _hasActiveMembershipForLibrary(
        studentId: studentId,
        libraryId: libraryId,
      );

      // Filter active notices (not expired and targeting the student)
      final notices = <Notice>[];
      for (final doc in snapshot.docs) {
        final notice = NoticeModel.fromFirestore(doc).toEntity();

        // Check if expired
        if (notice.expiresAt != null && now.isAfter(notice.expiresAt!)) {
          continue;
        }

        // Check target audience using cached membership status
        final isTargeted = _isStudentTargetedSync(
          notice,
          hasActiveMembership: hasActiveMembership,
        );
        if (isTargeted) {
          notices.add(notice);
        }
      }

      return Right(notices);
    } catch (e, stackTrace) {
      _logNoticeQueryError(
        operation: 'getActiveNoticesForStudent',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(ServerFailure(message: 'Failed to fetch active notices: $e'));
    }
  }

  void _logNoticeQueryError({
    required String operation,
    required Object error,
    required StackTrace stackTrace,
  }) {
    final message = error.toString();
    final indexUrl = RegExp(
      r'https://console\.firebase\.google\.com/\S+',
    ).firstMatch(message)?.group(0);

    developer.log(
      'NoticeRepositoryImpl.$operation failed: $message',
      name: 'NoticeRepositoryImpl',
      error: error,
      stackTrace: stackTrace,
    );

    if (indexUrl != null) {
      developer.log(
        'Create missing Firestore index here: $indexUrl',
        name: 'NoticeRepositoryImpl',
      );
    }
  }

  @override
  Future<Either<Failure, void>> markNoticeAsRead({
    required String noticeId,
    required String studentId,
    required String libraryId,
  }) async {
    try {
      final statusId = '${noticeId}_$studentId';
      final statusModel = NoticeReadStatusModel(
        noticeId: noticeId,
        studentId: studentId,
        libraryId: libraryId,
        isRead: true,
        readAt: DateTime.now(),
      );

      await firestore
          .collection('notice_read_status')
          .doc(statusId)
          .set(statusModel.toFirestore());

      // Increment read count in notice
      final noticeRef = firestore.collection('notices').doc(noticeId);
      await noticeRef.update({'readCount': FieldValue.increment(1)});

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to mark notice as read: $e'));
    }
  }

  @override
  Future<Either<Failure, Map<String, NoticeReadStatus>>>
  getReadStatusForStudent({
    required String studentId,
    required String libraryId,
  }) async {
    try {
      final snapshot = await firestore
          .collection('notice_read_status')
          .where('studentId', isEqualTo: studentId)
          .where('libraryId', isEqualTo: libraryId)
          .get();

      final statusMap = <String, NoticeReadStatus>{};
      for (final doc in snapshot.docs) {
        final status = NoticeReadStatusModel.fromFirestore(doc).toEntity();
        statusMap[status.noticeId] = status;
      }

      return Right(statusMap);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to fetch read status: $e'));
    }
  }

  @override
  Future<Either<Failure, Notice>> getNoticeById(String noticeId) async {
    try {
      final doc = await firestore.collection('notices').doc(noticeId).get();

      if (!doc.exists) {
        return Left(DocumentNotFoundFailure(message: 'Notice not found'));
      }

      return Right(NoticeModel.fromFirestore(doc).toEntity());
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to fetch notice: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> incrementViewCount({
    required String noticeId,
    required String userId,
  }) async {
    try {
      // Check if user has already viewed this notice
      final viewStatusId = '${noticeId}_$userId';
      final viewStatusDoc = await firestore
          .collection('notice_view_status')
          .doc(viewStatusId)
          .get();

      // Only increment if user hasn't viewed before
      if (!viewStatusDoc.exists) {
        // Mark as viewed
        await firestore.collection('notice_view_status').doc(viewStatusId).set({
          'noticeId': noticeId,
          'userId': userId,
          'viewedAt': FieldValue.serverTimestamp(),
        });

        // Increment view count
        await firestore.collection('notices').doc(noticeId).update({
          'viewCount': FieldValue.increment(1),
        });
      }

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to increment view count: $e'));
    }
  }

  @override
  Future<Either<Failure, NoticeAnalytics>> getNoticeAnalytics({
    required String libraryId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = firestore
          .collection('notices')
          .where('libraryId', isEqualTo: libraryId);

      if (startDate != null) {
        query = query.where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      final snapshot = await query.get();
      final notices = snapshot.docs
          .map((doc) => NoticeModel.fromFirestore(doc).toEntity())
          .toList();

      final totalNotices = notices.length;
      final publishedNotices = notices
          .where((n) => n.status == NoticeStatus.published)
          .length;
      final activeNotices = notices.where((n) => n.isActive).length;
      final expiredNotices = notices.where((n) => n.isExpired).length;

      // Calculate read rates
      final noticeReadRates = <String, double>{};
      double totalReadRate = 0.0;
      int noticesWithReads = 0;

      for (final notice in notices) {
        if (notice.viewCount > 0) {
          final readRate = notice.readCount / notice.viewCount;
          noticeReadRates[notice.id] = readRate;
          totalReadRate += readRate;
          noticesWithReads++;
        }
      }

      final averageReadRate = noticesWithReads > 0
          ? totalReadRate / noticesWithReads
          : 0.0;

      return Right(
        NoticeAnalytics(
          totalNotices: totalNotices,
          publishedNotices: publishedNotices,
          activeNotices: activeNotices,
          expiredNotices: expiredNotices,
          averageReadRate: averageReadRate,
          noticeReadRates: noticeReadRates,
        ),
      );
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to fetch analytics: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateExpiredNotices() async {
    try {
      final now = DateTime.now();
      final snapshot = await firestore
          .collection('notices')
          .where('status', isEqualTo: NoticeStatus.published.name)
          .where('expiresAt', isLessThan: Timestamp.fromDate(now))
          .get();

      final batch = firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'status': NoticeStatus.expired.name,
          'updatedAt': Timestamp.fromDate(now),
        });
      }

      await batch.commit();
      return const Right(null);
    } catch (e) {
      return Left(
        ServerFailure(message: 'Failed to update expired notices: $e'),
      );
    }
  }

  // Private helper methods

  Future<NoticeAttachment> _uploadAttachment({
    required File file,
    required String noticeId,
    required String libraryId,
  }) async {
    final fileName = file.path.split('/').last;
    final fileExtension = fileName.split('.').last.toLowerCase();

    // Determine file type
    AttachmentType fileType;
    String contentType;

    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(fileExtension)) {
      fileType = AttachmentType.image;
      contentType = 'image/$fileExtension';
    } else if (fileExtension == 'pdf') {
      fileType = AttachmentType.pdf;
      contentType = 'application/pdf';
    } else {
      throw Exception('Unsupported file type: $fileExtension');
    }

    // Validate file size (max 10MB)
    final fileSize = await file.length();
    if (fileSize > 10 * 1024 * 1024) {
      throw Exception('File size exceeds 10MB limit');
    }

    // Upload to Firebase Storage
    final path = 'notices/$libraryId/$noticeId/';
    final attachmentId = const Uuid().v4();
    final uploadFileName = '${attachmentId}_$fileName';

    final downloadUrl = await storageService.uploadFile(
      file: file,
      path: path,
      fileName: uploadFileName,
      contentType: contentType,
    );

    return NoticeAttachment(
      id: attachmentId,
      url: downloadUrl,
      fileName: fileName,
      fileType: fileType,
      fileSize: fileSize,
    );
  }

  /// Synchronous audience check using a pre-fetched membership flag.
  /// Replaces the old async [_isStudentTargeted] that ran a Firestore query
  /// per notice — saving N-1 reads when N notices target activeStudents.
  bool _isStudentTargetedSync(
    Notice notice, {
    required bool hasActiveMembership,
  }) {
    switch (notice.targetAudience) {
      case NoticeTargetAudience.all:
        return true;
      case NoticeTargetAudience.activeStudents:
        return hasActiveMembership;
      case NoticeTargetAudience.slot:
        return false;
      case NoticeTargetAudience.seat:
        return false;
    }
  }

  /// Single membership existence check for a student+library pair.
  Future<bool> _hasActiveMembershipForLibrary({
    required String studentId,
    required String libraryId,
  }) async {
    final snapshot = await firestore
        .collection('memberships')
        .where('userId', isEqualTo: studentId)
        .where('libraryId', isEqualTo: libraryId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }
}
