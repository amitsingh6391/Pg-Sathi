import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/whatsapp_launcher.dart';
import '../../../domain/entities/whatsapp_reminder.dart';
import '../../../domain/repositories/whatsapp_reminder_repository.dart';
import 'whatsapp_reminder_state.dart';

/// Cubit for managing WhatsApp reminder operations.
class WhatsAppReminderCubit extends Cubit<WhatsAppReminderState> {
  WhatsAppReminderCubit({required this.repository})
    : super(const WhatsAppReminderState());

  final WhatsAppReminderRepository repository;

  static const int _daysThreshold = 7;

  /// Loads expiring memberships for WhatsApp reminders.
  Future<void> loadReminders({required String libraryId}) async {
    emit(
      state.copyWith(status: WhatsAppReminderStatus.loading, clearError: true),
    );

    final result = await repository.getExpiringReminders(
      libraryId: libraryId,
      daysThreshold: _daysThreshold,
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: WhatsAppReminderStatus.error,
          errorMessage: failure.message ?? 'Failed to load reminders',
        ),
      ),
      (reminders) => emit(
        state.copyWith(
          status: WhatsAppReminderStatus.success,
          reminders: reminders,
        ),
      ),
    );
  }

  /// Sends a single WhatsApp message.
  Future<bool> sendWhatsApp({
    required WhatsAppReminder reminder,
    String? customMessage,
  }) async {
    if (!reminder.canSendMoreToday) return false;

    try {
      final url = customMessage != null && customMessage.trim().isNotEmpty
          ? reminder.getWhatsappUrlWithCustomMessage(customMessage)
          : reminder.whatsappUrl;

      await WhatsAppLauncher.launchFromWaUrl(url);
      await _logReminder(reminder);
      return true;
    } catch (e) {
      debugPrint('Failed to send WhatsApp: $e');
      return false;
    }
  }

  /// Starts sending to all pending members.
  Future<void> sendAllWhatsApp({String? customMessage}) async {
    final pending = state.reminders.where((r) => r.canSendMoreToday).toList();
    if (pending.isEmpty) return;

    emit(state.copyWith(pendingQueue: pending, isSendingAll: true));

    await _sendNextInQueue(customMessage: customMessage);
  }

  /// Continues sending next in queue (called on app resume).
  Future<void> continueQueue({String? customMessage}) async {
    if (!state.isSendingAll || state.pendingQueue.isEmpty) return;
    await _sendNextInQueue(customMessage: customMessage);
  }

  Future<void> _sendNextInQueue({String? customMessage}) async {
    if (state.pendingQueue.isEmpty) {
      emit(state.copyWith(isSendingAll: false, pendingQueue: const []));
      return;
    }

    final currentQueue = List<WhatsAppReminder>.from(state.pendingQueue);
    final reminder = currentQueue.removeAt(0);
    emit(state.copyWith(pendingQueue: currentQueue));

    try {
      final url = customMessage != null && customMessage.trim().isNotEmpty
          ? reminder.getWhatsappUrlWithCustomMessage(customMessage)
          : reminder.whatsappUrl;

      await WhatsAppLauncher.launchFromWaUrl(url);
      await _logReminder(reminder);
    } catch (e) {
      debugPrint('Failed to send: $e');
    }
  }

  Future<void> _logReminder(WhatsAppReminder reminder) async {
    await repository.logReminderSent(membershipId: reminder.membershipId);

    final updatedReminders = state.reminders.map((r) {
      if (r.membershipId == reminder.membershipId) {
        return WhatsAppReminder(
          studentId: r.studentId,
          studentName: r.studentName,
          studentPhone: r.studentPhone,
          membershipId: r.membershipId,
          expiryDate: r.expiryDate,
          libraryName: r.libraryName,
          daysUntilExpiry: r.daysUntilExpiry,
          lastReminderSentAt: DateTime.now(),
          todayReminderCount: r.todayReminderCount + 1,
        );
      }
      return r;
    }).toList();

    emit(state.copyWith(reminders: updatedReminders));
  }

  /// Clears the sending queue.
  void cancelQueue() {
    emit(state.copyWith(isSendingAll: false, pendingQueue: const []));
  }
}
