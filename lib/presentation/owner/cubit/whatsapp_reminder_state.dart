import 'package:equatable/equatable.dart';

import '../../../domain/entities/whatsapp_reminder.dart';

/// State for WhatsApp reminder cubit.
class WhatsAppReminderState extends Equatable {
  const WhatsAppReminderState({
    this.status = WhatsAppReminderStatus.initial,
    this.reminders = const [],
    this.pendingQueue = const [],
    this.isSendingAll = false,
    this.errorMessage,
  });

  final WhatsAppReminderStatus status;
  final List<WhatsAppReminder> reminders;
  final List<WhatsAppReminder> pendingQueue;
  final bool isSendingAll;
  final String? errorMessage;

  bool get isLoading => status == WhatsAppReminderStatus.loading;
  bool get isSuccess => status == WhatsAppReminderStatus.success;
  bool get isError => status == WhatsAppReminderStatus.error;
  bool get isEmpty => reminders.isEmpty;

  int get pendingCount => reminders.where((r) => r.canSendMoreToday).length;

  WhatsAppReminderState copyWith({
    WhatsAppReminderStatus? status,
    List<WhatsAppReminder>? reminders,
    List<WhatsAppReminder>? pendingQueue,
    bool? isSendingAll,
    String? errorMessage,
    bool clearError = false,
  }) {
    return WhatsAppReminderState(
      status: status ?? this.status,
      reminders: reminders ?? this.reminders,
      pendingQueue: pendingQueue ?? this.pendingQueue,
      isSendingAll: isSendingAll ?? this.isSendingAll,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    status,
    reminders,
    pendingQueue,
    isSendingAll,
    errorMessage,
  ];
}

/// Status for WhatsApp reminder operations.
enum WhatsAppReminderStatus { initial, loading, success, error }
