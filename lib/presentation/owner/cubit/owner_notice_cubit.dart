import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/notice.dart';
import '../../../domain/entities/notice_whatsapp_result.dart';
import '../../../domain/repositories/notice_repository.dart';
import '../../../domain/usecases/notice_usecases.dart';
import '../../../domain/usecases/send_notice_whatsapp.dart';
import '../../../domain/usecases/whatsapp_credits_usecases.dart';

/// Cubit for managing notices (Owner side)
class OwnerNoticeCubit extends Cubit<OwnerNoticeState> {
  OwnerNoticeCubit({
    required this.getNoticesByLibrary,
    required this.createNotice,
    required this.updateNotice,
    required this.deleteNotice,
    required this.publishNotice,
    required this.getNoticeAnalytics,
    required this.sendNoticeWhatsApp,
    required this.getWhatsAppCredits,
  }) : super(const OwnerNoticeState());

  final GetNoticesByLibrary getNoticesByLibrary;
  final CreateNotice createNotice;
  final UpdateNotice updateNotice;
  final DeleteNotice deleteNotice;
  final PublishNotice publishNotice;
  final GetNoticeAnalytics getNoticeAnalytics;
  final SendNoticeWhatsApp sendNoticeWhatsApp;
  final GetWhatsAppCredits getWhatsAppCredits;

  /// Loads the owner's available WhatsApp credits into
  /// [OwnerNoticeState.whatsappCredits].
  Future<void> loadWhatsAppCredits(String ownerId) async {
    final result = await getWhatsAppCredits(ownerId);
    if (isClosed) return;
    result.fold(
      (_) {},
      (credits) =>
          emit(state.copyWith(whatsappCredits: credits.availableCredits)),
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
          emit(
            state.copyWith(
              status: OwnerNoticeStatus.error,
              errorMessage: failure.message,
            ),
          );
        }
      },
      (notices) {
        if (isClosed) return;
        // Separate notices by status
        final active = notices.where((n) => n.isActive).toList();
        final scheduled = notices.where((n) => n.isScheduled).toList();
        final drafts = notices
            .where((n) => n.status == NoticeStatus.draft)
            .toList();
        final expired = notices.where((n) => n.isExpired).toList();

        if (!isClosed) {
          emit(
            state.copyWith(
              status: OwnerNoticeStatus.loaded,
              allNotices: notices,
              activeNotices: active,
              scheduledNotices: scheduled,
              draftNotices: drafts,
              expiredNotices: expired,
            ),
          );
        }
      },
    );
  }

  /// Create a new notice
  Future<void> createNewNotice({
    required String libraryId,
    required String ownerId,
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
      description: description,
      targetAudience: targetAudience,
      attachmentFiles: attachmentFiles,
      externalLinks: externalLinks,
      scheduledFor: scheduledFor,
      expiresAt: expiresAt,
      sendPushNotification: sendPushNotification,
      sendWhatsApp: sendWhatsApp,
      targetSlotIds: targetSlotIds,
      targetSeatIds: targetSeatIds,
    );

    if (isClosed) return;
    await result.fold<Future<void>>(
      (failure) async {
        if (!isClosed) {
          emit(
            state.copyWith(
              status: OwnerNoticeStatus.error,
              errorMessage: failure.message,
            ),
          );
        }
      },
      (notice) async {
        String? whatsappMessage;
        if (sendWhatsApp && notice.status == NoticeStatus.published) {
          final wa = await sendNoticeWhatsApp(notice.id);
          whatsappMessage = wa.fold(
            (failure) =>
                'Notice posted, but WhatsApp failed: ${failure.message}',
            _whatsappSummary,
          );
        }
        if (isClosed) return;
        emit(
          state.copyWith(
            status: OwnerNoticeStatus.created,
            whatsappMessage: whatsappMessage,
          ),
        );
        loadNotices(libraryId);
      },
    );
  }

  String _whatsappSummary(NoticeWhatsAppResult r) {
    if (r.total == 0) return 'No residents with a phone number to send to';
    final parts = ['Sent on WhatsApp to ${r.sent} of ${r.total}'];
    if (r.noCredit > 0) parts.add('${r.noCredit} skipped — no credits left');
    if (r.failed > 0) parts.add('${r.failed} failed (credits refunded)');
    return parts.join(' • ');
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
          emit(
            state.copyWith(
              status: OwnerNoticeStatus.error,
              errorMessage: failure.message,
            ),
          );
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

  /// Load analytics for notices
  Future<void> loadAnalytics(String libraryId) async {
    if (isClosed) return;
    emit(state.copyWith(analyticsStatus: AnalyticsStatus.loading));

    final result = await getNoticeAnalytics(libraryId: libraryId);

    if (isClosed) return;
    result.fold(
      (failure) {
        if (!isClosed) {
          emit(
            state.copyWith(
              analyticsStatus: AnalyticsStatus.error,
              analyticsError: failure.message,
            ),
          );
        }
      },
      (analytics) {
        if (!isClosed) {
          emit(
            state.copyWith(
              analyticsStatus: AnalyticsStatus.loaded,
              analytics: analytics,
            ),
          );
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
    this.whatsappCredits,
    this.whatsappMessage,
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
  final int? whatsappCredits;
  final String? whatsappMessage;

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
    int? whatsappCredits,
    String? whatsappMessage,
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
      whatsappCredits: whatsappCredits ?? this.whatsappCredits,
      whatsappMessage: whatsappMessage,
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
    whatsappCredits,
    whatsappMessage,
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

enum AnalyticsStatus { initial, loading, loaded, error }
