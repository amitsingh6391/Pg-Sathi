import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/attendance.dart';
import '../../../domain/entities/slot.dart';
import '../../../domain/usecases/check_in.dart';
import '../../../domain/usecases/check_out.dart';
import '../../../domain/usecases/get_today_attendance.dart';

part 'attendance_state.dart';

/// Cubit for managing student attendance.
///
/// V2 Update: Supports multiple check-in/check-out sessions per day.
///
/// Business Rules (V2):
/// - Student can CHECK-IN multiple times per day per slot
/// - Student can CHECK-OUT after each CHECK-IN
/// - Only ONE active session at a time
/// - Total time is sum of all completed sessions
class AttendanceCubit extends Cubit<AttendanceState> {
  AttendanceCubit({
    required this.checkInUseCase,
    required this.checkOutUseCase,
    required this.getTodayAttendanceUseCase,
  }) : super(const AttendanceState());

  final CheckIn checkInUseCase;
  final CheckOut checkOutUseCase;
  final GetTodayAttendance getTodayAttendanceUseCase;

  /// Flag to prevent concurrent operations.
  bool _isOperationInProgress = false;

  /// Load today's attendance status for a specific slot.
  Future<void> loadTodayAttendance({
    required String userId,
    required String libraryId,
    required Slot slot,
  }) async {
    if (_isOperationInProgress) return;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Skip if already loaded for this slot and not in initial state
    if (state.date == today && state.slot == slot && state.attendance != null) {
      return;
    }

    _isOperationInProgress = true;
    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final result = await getTodayAttendanceUseCase(
        GetTodayAttendanceParams(
          userId: userId,
          libraryId: libraryId,
          slot: slot,
          date: DateTime.now(),
        ),
      );

      result.fold(
        (failure) {
          // If failure, assume no attendance (can check in)
          emit(
            state.copyWith(
              isLoading: false,
              status: AttendanceStatus.none,
              attendance: null,
              date: today,
              slot: slot,
            ),
          );
        },
        (attendance) {
          if (attendance == null) {
            // No attendance record = can check in
            emit(
              state.copyWith(
                isLoading: false,
                status: AttendanceStatus.none,
                attendance: null,
                date: today,
                slot: slot,
              ),
            );
          } else {
            // V2: Determine status based on active session
            final effectiveStatus = _determineStatus(attendance);
            emit(
              state.copyWith(
                isLoading: false,
                status: effectiveStatus,
                attendance: attendance,
                date: today,
                slot: slot,
              ),
            );
          }
        },
      );
    } finally {
      _isOperationInProgress = false;
    }
  }

  /// Determines the effective status for V2 multi-session attendance.
  AttendanceStatus _determineStatus(Attendance attendance) {
    if (attendance.isMultiSession) {
      if (attendance.hasActiveSession) {
        return AttendanceStatus.checkedIn;
      } else if (attendance.completedSessionCount > 0) {
        return AttendanceStatus.checkedOut;
      }
      return AttendanceStatus.none;
    }
    // Legacy single-session
    return attendance.status;
  }

  /// Check in for the current slot.
  /// V2: Creates new session or adds session to existing attendance.
  Future<void> checkIn({
    required String userId,
    required String libraryId,
    required Slot slot,
  }) async {
    if (_isOperationInProgress) return;

    // V2: Guard - can check in if no attendance or no active session
    if (!state.canCheckIn) {
      emit(
        state.copyWith(
          errorMessage: state.isInActiveSession
              ? 'You are already checked in. Check out first to start a new session.'
              : 'Unable to check in at this time.',
        ),
      );
      return;
    }

    _isOperationInProgress = true;
    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final attendanceId = '${userId}_${today}_${slot.name}';

      final result = await checkInUseCase(
        CheckInParams(
          attendanceId: attendanceId,
          userId: userId,
          libraryId: libraryId,
          slot: slot,
          checkInTime: DateTime.now(),
        ),
      );

      result.fold(
        (failure) {
          emit(
            state.copyWith(
              isLoading: false,
              errorMessage: failure.message ?? 'Failed to check in',
            ),
          );
        },
        (attendance) {
          emit(
            state.copyWith(
              isLoading: false,
              status: AttendanceStatus.checkedIn,
              attendance: attendance,
            ),
          );
        },
      );
    } finally {
      _isOperationInProgress = false;
    }
  }

  /// Check out from the current slot.
  /// V2: Completes the active session, allows checking in again.
  Future<void> checkOut({
    required String userId,
    required String libraryId,
    required Slot slot,
  }) async {
    if (_isOperationInProgress) return;

    // V2: Guard - can only check out if there's an active session
    if (!state.canCheckOut) {
      emit(
        state.copyWith(
          errorMessage: state.attendance == null
              ? 'You need to check in first'
              : 'No active session to check out from.',
        ),
      );
      return;
    }

    _isOperationInProgress = true;
    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final result = await checkOutUseCase(
        CheckOutParams(
          userId: userId,
          libraryId: libraryId,
          slot: slot,
          checkOutTime: DateTime.now(),
        ),
      );

      result.fold(
        (failure) {
          emit(
            state.copyWith(
              isLoading: false,
              errorMessage: failure.message ?? 'Failed to check out',
            ),
          );
        },
        (attendance) {
          // V2: After checkout, status is checkedOut but canCheckIn is true
          emit(
            state.copyWith(
              isLoading: false,
              status: AttendanceStatus.checkedOut,
              attendance: attendance,
            ),
          );
        },
      );
    } finally {
      _isOperationInProgress = false;
    }
  }

  /// Force reload attendance (useful after errors).
  Future<void> forceReload({
    required String userId,
    required String libraryId,
    required Slot slot,
  }) async {
    if (_isOperationInProgress) return;

    // Reset state to allow reload
    emit(const AttendanceState());

    await loadTodayAttendance(userId: userId, libraryId: libraryId, slot: slot);
  }

  /// Clear any error state.
  void clearError() {
    emit(state.copyWith(clearError: true));
  }
}
