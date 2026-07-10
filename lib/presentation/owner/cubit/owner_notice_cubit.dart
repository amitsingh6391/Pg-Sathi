import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/notice.dart';
import '../../../domain/repositories/notice_repository.dart';
import '../../../domain/repositories/whatsapp_notification_repository.dart';
import '../../../domain/usecases/notice_usecases.dart';

/// Cubit for managing notices (Owner side)
class OwnerNoticeCubit extends Cubit<OwnerNoticeState> {
  OwnerNoticeCubit({
    required this.getNoticesByLibrary,
    required this.createNotice,
    required this.updateNotice,
    required this.deleteNotice,
    required this.publishNotice,
    required this.getNoticeAnalytics,
    required this.whatsAppNotificationRepository,
  }) : super(const OwnerNoticeState());

  final GetNoticesByLibrary getNoticesByLibrary;
  final CreateNotice createNotice;
  final UpdateNotice updateNotice;
  final DeleteNotice deleteNotice;
  final PublishNotice publishNotice;
  final GetNoticeAnalytics getNoticeAnalytics;
  final WhatsAppNotificationRepository whatsAppNotificationRepository;

  /// Loads how many free WhatsApp notice broadcasts remain this month.
  Future<void> loadWhatsAppQuota(String libraryId) async {
    final result =
        await whatsAppNotificationRepository.getRemainingNoticeQuota(libraryId);
    if (isClosed) return;
    result.fold(
      (_) {},
      (remaining) => emit(state.copyWith(whatsAppQuotaRemaining: remaining)),
    );
  }

  /// Load all notices for a library
  Future<void> loadNotices(String libraryId) async {
    if (isClosed) return;
    emit(state.copyWith(status: OwnerNoticeStatus.loading));

    final result = await getNoticesByLibrary(libraryId);

    if (isClosed) return;
    result.fold(
      (failure) {
        if (!isClosed) {
          emit(state.copyWith(
            status: OwnerNoticeStatus.error,
            errorMessage: failure.message,
          ));
        }
      },
      (notices) {
        if (isClosed) return;
        // Separate notices by status
        final active = notices.where((n) => n.isActive).toList();
        final scheduled = notices.where((n) => n.isScheduled).toList();
        final drafts = notices.where((n) => n.status == NoticeStatus.draft).toList();
        final expired = notices.where((n) => n.isExpired).toList();

        if (!isClosed) {
          emit(state.copyWith(
            status: OwnerNoticeStatus.loaded,
            allNotices: notices,
            activeNotices: active,
            scheduledNotices: scheduled,
            draftNotices: drafts,
            expiredNotices: expired,
          ));
        }
      },
    );
  }

  /// Create a new notice
  Future<void> createNewNotice({
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
    bool sendWhatsApp = false,
    List<String> targetSlotIds = const [],
    List<String> targetSeatIds = const [],
  }) async {
    if (isClosed) return;
    emit(state.copyWith(status: OwnerNoticeStatus.creating));

    final result = await createNotice(
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

    if (isClosed) return;
    await result.fold(
      (failure) async {
        if (!isClosed) {
          emit(state.copyWith(
            status: OwnerNoticeStatus.error,
            errorMessage: failure.message,
          ));
        }
      },
      (notice) async {
        // Broadcast on WhatsApp only for notices published immediately.
        String? whatsAppMessage;
        if (sendWhatsApp && notice.status == NoticeStatus.published) {
          whatsAppMessage = await _broadcastNoticeWhatsApp(notice);
        }
        if (!isClosed) {
          emit(state.copyWith(
            status: OwnerNoticeStatus.created,
            whatsAppMessage: whatsAppMessage,
          ));
          // Reload notices to reflect changes
          loadNotices(libraryId);
        }
      },
    );
  }

  /// Sends the notice to active tenants over WhatsApp. Returns a short
  /// user-facing status message (or null when nothing notable happened).
  Future<String?> _broadcastNoticeWhatsApp(Notice notice) async {
    final result = await whatsAppNotificationRepository.sendNoticeWhatsApp(
      libraryId: notice.libraryId,
      noticeId: notice.id,
      libraryName: '',
      title: notice.title,
      description: notice.description,
    );
    return result.fold(
      (failure) => 'WhatsApp broadcast failed: ${failure.message}',
      (r) {
        if (r.wasSkipped) {
          if (r.skippedReason == 'monthly_limit') {
            return 'Monthly WhatsApp limit reached — notice posted without WhatsApp.';
          }
          if (r.skippedReason == 'no_recipients') {
            return 'No active tenants with a phone number to WhatsApp.';
          }
          return 'WhatsApp broadcast skipped.';
        }
        return 'Sent on WhatsApp to ${r.sent} tenant(s) • ${r.remaining} left this month';
      },
    );
  }

  /// Update an existing notice
  Future<void> updateExistingNotice({
    required String noticeId,
    required String libraryId,
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
    if (isClosed) return;
    emit(state.copyWith(status: OwnerNoticeStatus.updating));

    final result = await updateNotice(
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

    if (isClosed) return;
    result.fold(
      (failure) {
        if (!isClosed) {
          emit(state.copyWith(
            status: OwnerNoticeStatus.error,
            errorMessage: failure.message,
          ));
        }
      },
      (notice) {
        if (!isClosed) {
          emit(state.copyWith(status: OwnerNoticeStatus.updated));
          // Reload notices to reflect changes
          loadNotices(libraryId);
        }
      },
    );
  }

  /// Delete a notice
  Future<void> deleteExistingNotice(String noticeId, String libraryId) async {
    if (isClosed) return;
    emit(state.copyWith(status: OwnerNoticeStatus.deleting));

    final result = await deleteNotice(noticeId);

    if (isClosed) return;
    result.fold(
      (failure) {
        if (!isClosed) {
          emit(state.copyWith(
            status: OwnerNoticeStatus.error,
            errorMessage: failure.message,
          ));
        }
      },
      (_) {
        if (!isClosed) {
          emit(state.copyWith(status: OwnerNoticeStatus.deleted));
          // Reload notices to reflect changes
          loadNotices(libraryId);
        }
      },
    );
  }

  /// Publish a draft or scheduled notice
  Future<void> publishExistingNotice(String noticeId, String libraryId) async {
    if (isClosed) return;
    emit(state.copyWith(status: OwnerNoticeStatus.publishing));

    final result = await publishNotice(noticeId);

    if (isClosed) return;
    result.fold(
      (failure) {
        if (!isClosed) {
          emit(state.copyWith(
            status: OwnerNoticeStatus.error,
            errorMessage: failure.message,
          ));
        }
      },
      (notice) {
        if (!isClosed) {
          emit(state.copyWith(status: OwnerNoticeStatus.published));
          // Reload notices to reflect changes
          loadNotices(libraryId);
        }
      },
    );
  }

  /// Load analytics for notices
  Future<void> loadAnalytics(String libraryId) async {
    if (isClosed) return;
    emit(state.copyWith(analyticsStatus: AnalyticsStatus.loading));

    final result = await getNoticeAnalytics(libraryId: libraryId);

    if (isClosed) return;
    result.fold(
      (failure) {
        if (!isClosed) {
          emit(state.copyWith(
            analyticsStatus: AnalyticsStatus.error,
            analyticsError: failure.message,
          ));
        }
      },
      (analytics) {
        if (!isClosed) {
          emit(state.copyWith(
            analyticsStatus: AnalyticsStatus.loaded,
            analytics: analytics,
          ));
        }
      },
    );
  }
}

/// State for Owner Notice management
class OwnerNoticeState extends Equatable {
  const OwnerNoticeState({
    this.status = OwnerNoticeStatus.initial,
    this.allNotices = const [],
    this.activeNotices = const [],
    this.scheduledNotices = const [],
    this.draftNotices = const [],
    this.expiredNotices = const [],
    this.errorMessage,
    this.analyticsStatus = AnalyticsStatus.initial,
    this.analytics,
    this.analyticsError,
    this.whatsAppQuotaRemaining,
    this.whatsAppMessage,
  });

  final OwnerNoticeStatus status;
  final List<Notice> allNotices;
  final List<Notice> activeNotices;
  final List<Notice> scheduledNotices;
  final List<Notice> draftNotices;
  final List<Notice> expiredNotices;
  final String? errorMessage;
  final AnalyticsStatus analyticsStatus;
  final NoticeAnalytics? analytics;
  final String? analyticsError;

  /// Remaining free WhatsApp notice broadcasts this month (null = unknown).
  final int? whatsAppQuotaRemaining;

  /// User-facing result of the last WhatsApp broadcast (null = none).
  final String? whatsAppMessage;

  OwnerNoticeState copyWith({
    OwnerNoticeStatus? status,
    List<Notice>? allNotices,
    List<Notice>? activeNotices,
    List<Notice>? scheduledNotices,
    List<Notice>? draftNotices,
    List<Notice>? expiredNotices,
    String? errorMessage,
    AnalyticsStatus? analyticsStatus,
    NoticeAnalytics? analytics,
    String? analyticsError,
    int? whatsAppQuotaRemaining,
    String? whatsAppMessage,
  }) {
    return OwnerNoticeState(
      status: status ?? this.status,
      allNotices: allNotices ?? this.allNotices,
      activeNotices: activeNotices ?? this.activeNotices,
      scheduledNotices: scheduledNotices ?? this.scheduledNotices,
      draftNotices: draftNotices ?? this.draftNotices,
      expiredNotices: expiredNotices ?? this.expiredNotices,
      errorMessage: errorMessage ?? this.errorMessage,
      analyticsStatus: analyticsStatus ?? this.analyticsStatus,
      analytics: analytics ?? this.analytics,
      analyticsError: analyticsError ?? this.analyticsError,
      whatsAppQuotaRemaining:
          whatsAppQuotaRemaining ?? this.whatsAppQuotaRemaining,
      whatsAppMessage: whatsAppMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        allNotices,
        activeNotices,
        scheduledNotices,
        draftNotices,
        expiredNotices,
        errorMessage,
        analyticsStatus,
        analytics,
        analyticsError,
        whatsAppQuotaRemaining,
        whatsAppMessage,
      ];
}

enum OwnerNoticeStatus {
  initial,
  loading,
  loaded,
  creating,
  created,
  updating,
  updated,
  deleting,
  deleted,
  publishing,
  published,
  error,
}

enum AnalyticsStatus {
  initial,
  loading,
  loaded,
  error,
}
