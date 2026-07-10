import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/attendance.dart';
import '../../../domain/entities/attendance_stats.dart';
import '../../../domain/usecases/get_attendance_history.dart';
import '../../../domain/usecases/get_attendance_stats.dart';

part 'attendance_history_state.dart';

/// Cubit for managing attendance history and statistics.
class AttendanceHistoryCubit extends Cubit<AttendanceHistoryState> {
  AttendanceHistoryCubit({
    required this.getAttendanceHistoryUseCase,
    required this.getAttendanceStatsUseCase,
  }) : super(const AttendanceHistoryState());

  final GetAttendanceHistory getAttendanceHistoryUseCase;
  final GetAttendanceStats getAttendanceStatsUseCase;

  /// Load attendance history and stats for a user in a library.
  Future<void> loadAttendanceData({
    required String userId,
    required String libraryId,
  }) async {
    emit(state.copyWith(status: AttendanceHistoryStatus.loading));

    // Load history (last 30 days)
    final historyResult = await getAttendanceHistoryUseCase(
      GetAttendanceHistoryParams.lastDays(
        userId: userId,
        libraryId: libraryId,
        days: 30,
      ),
    );

    // Load stats
    final statsResult = await getAttendanceStatsUseCase(
      GetAttendanceStatsParams(userId: userId, libraryId: libraryId),
    );

    // Process results
    historyResult.fold(
      (failure) => emit(
        state.copyWith(
          status: AttendanceHistoryStatus.error,
          errorMessage: failure.message ?? 'Failed to load attendance history',
        ),
      ),
      (history) {
        statsResult.fold(
          (failure) => emit(
            state.copyWith(
              status: AttendanceHistoryStatus.loaded,
              history: history,
              errorMessage: 'Stats unavailable',
            ),
          ),
          (stats) => emit(
            state.copyWith(
              status: AttendanceHistoryStatus.loaded,
              history: history,
              stats: stats,
            ),
          ),
        );
      },
    );
  }

  /// Refresh data.
  Future<void> refresh({
    required String userId,
    required String libraryId,
  }) async {
    await loadAttendanceData(userId: userId, libraryId: libraryId);
  }

  /// Set the selected tab/period.
  void setSelectedPeriod(AttendancePeriod period) {
    emit(state.copyWith(selectedPeriod: period));
  }
}

/// Available periods for viewing attendance.
enum AttendancePeriod {
  week,
  month,
  all;

  String get displayName {
    switch (this) {
      case AttendancePeriod.week:
        return 'This Week';
      case AttendancePeriod.month:
        return 'This Month';
      case AttendancePeriod.all:
        return 'All Time';
    }
  }
}
