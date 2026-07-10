import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repositories/membership_repository.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../../domain/usecases/send_membership_expiry_reminder.dart';
import 'expiry_reminder_state.dart';

/// Cubit for managing membership expiry reminders.
class ExpiryReminderCubit extends Cubit<ExpiryReminderState> {
  ExpiryReminderCubit({
    required this.sendReminder,
    required this.membershipRepository,
    required this.userRepository,
  }) : super(const ExpiryReminderState());

  final SendMembershipExpiryReminder sendReminder;
  final MembershipRepository membershipRepository;
  final UserRepository userRepository;

  /// Loads expiring memberships for a library.
  Future<void> loadExpiringMemberships({
    required String libraryId,
    int? daysThreshold,
  }) async {
    emit(
      state.copyWith(
        status: ExpiryReminderStatus.loading,
        daysThreshold: daysThreshold ?? state.daysThreshold,
        clearError: true,
      ),
    );

    final now = DateTime.now();
    final threshold = daysThreshold ?? state.daysThreshold;

    // Get expiring memberships
    final membershipsResult = await membershipRepository.getExpiringMemberships(
      libraryId: libraryId,
      currentDate: now,
      daysThreshold: threshold,
    );

    membershipsResult.fold(
      (failure) => emit(
        state.copyWith(
          status: ExpiryReminderStatus.error,
          errorMessage:
              failure.message ?? 'Failed to load expiring memberships',
        ),
      ),
      (memberships) async {
        if (memberships.isEmpty) {
          emit(
            state.copyWith(
              status: ExpiryReminderStatus.success,
              expiringMemberships: [],
            ),
          );
          return;
        }

        // Get user details for each membership (filter out unregistered memberships)
        final userIds = memberships
            .where((m) => m.userId != null)
            .map((m) => m.userId!)
            .toSet()
            .toList();
        final usersResult = await userRepository.getUsersByIds(userIds);

        usersResult.fold(
          (failure) => emit(
            state.copyWith(
              status: ExpiryReminderStatus.error,
              errorMessage: failure.message ?? 'Failed to load user details',
            ),
          ),
          (usersMap) {
            // Include ALL expiring memberships (both registered and unregistered)
            final expiringInfo = memberships.map((m) {
              final user = m.userId != null ? usersMap[m.userId!] : null;

              return ExpiringMembershipInfo(
                membership: m,
                user: user,
                daysRemaining: m.daysRemaining(now),
              );
            }).toList();

            // Sort by days remaining (ascending)
            expiringInfo.sort(
              (a, b) => a.daysRemaining.compareTo(b.daysRemaining),
            );

            emit(
              state.copyWith(
                status: ExpiryReminderStatus.success,
                expiringMemberships: expiringInfo,
              ),
            );
          },
        );
      },
    );
  }

  /// Toggles selection for a student.
  void toggleSelection(String userId) {
    final newSelection = Set<String>.from(state.selectedStudentIds);
    if (newSelection.contains(userId)) {
      newSelection.remove(userId);
    } else {
      newSelection.add(userId);
    }
    emit(state.copyWith(selectedStudentIds: newSelection));
  }

  /// Toggles select all.
  void toggleSelectAll() {
    if (state.isAllSelected) {
      emit(state.copyWith(clearSelection: true));
    } else {
      final allIds = state.expiringMemberships
          .where((info) => info.isRegistered)
          .map((info) => info.membership.userId!)
          .toSet();
      emit(state.copyWith(selectedStudentIds: allIds));
    }
  }

  /// Sends reminders to selected students.
  Future<void> sendReminders({
    required String libraryId,
    String? customTitle,
    String? customBody,
  }) async {
    if (state.selectedStudentIds.isEmpty) {
      emit(
        state.copyWith(
          status: ExpiryReminderStatus.error,
          errorMessage: 'Please select at least one student',
        ),
      );
      return;
    }

    emit(
      state.copyWith(status: ExpiryReminderStatus.loading, clearError: true),
    );

    final result = await sendReminder(
      SendMembershipExpiryReminderParams(
        libraryId: libraryId,
        studentIds: state.selectedStudentIds.toList(),
        daysThreshold: state.daysThreshold,
        title: customTitle,
        body: customBody,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ExpiryReminderStatus.error,
          errorMessage: failure.message ?? 'Failed to send reminders',
        ),
      ),
      (_) {
        // Update last sent timestamps
        final now = DateTime.now();
        final updatedLastSent = Map<String, DateTime>.from(
          state.lastSentReminder,
        );
        for (final userId in state.selectedStudentIds) {
          updatedLastSent[userId] = now;
        }

        emit(
          state.copyWith(
            status: ExpiryReminderStatus.success,
            lastSentReminder: updatedLastSent,
            clearSelection: true,
          ),
        );
      },
    );
  }

  /// Sends reminder to a single student.
  Future<void> sendReminderToStudent({
    required String libraryId,
    required String userId,
    String? customTitle,
    String? customBody,
  }) async {
    // Check cooldown
    if (!state.canSendReminder(userId)) {
      emit(
        state.copyWith(
          status: ExpiryReminderStatus.error,
          errorMessage: 'Reminder already sent. Please wait 24 hours.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(status: ExpiryReminderStatus.loading, clearError: true),
    );

    final result = await sendReminder(
      SendMembershipExpiryReminderParams(
        libraryId: libraryId,
        studentIds: [userId],
        daysThreshold: state.daysThreshold,
        title: customTitle,
        body: customBody,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ExpiryReminderStatus.error,
          errorMessage: failure.message ?? 'Failed to send reminder',
        ),
      ),
      (_) {
        // Update last sent timestamp
        final now = DateTime.now();
        final updatedLastSent = Map<String, DateTime>.from(
          state.lastSentReminder,
        );
        updatedLastSent[userId] = now;

        emit(
          state.copyWith(
            status: ExpiryReminderStatus.success,
            lastSentReminder: updatedLastSent,
          ),
        );
      },
    );
  }

  /// Refreshes the expiring memberships list.
  Future<void> refresh({required String libraryId}) {
    return loadExpiringMemberships(
      libraryId: libraryId,
      daysThreshold: state.daysThreshold,
    );
  }
}
