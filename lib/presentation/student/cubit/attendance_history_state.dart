part of 'attendance_history_cubit.dart';

/// State for AttendanceHistoryCubit.
class AttendanceHistoryState extends Equatable {
  const AttendanceHistoryState({
    this.status = AttendanceHistoryStatus.initial,
    this.history = const [],
    this.stats,
    this.selectedPeriod = AttendancePeriod.week,
    this.errorMessage,
  });

  final AttendanceHistoryStatus status;
  final List<Attendance> history;
  final AttendanceStats? stats;
  final AttendancePeriod selectedPeriod;
  final String? errorMessage;

  /// Whether loading.
  bool get isLoading => status == AttendanceHistoryStatus.loading;

  /// Whether loaded.
  bool get isLoaded => status == AttendanceHistoryStatus.loaded;

  /// Whether error.
  bool get hasError => status == AttendanceHistoryStatus.error;

  /// Whether has history data.
  bool get hasHistory => history.isNotEmpty;

  /// Whether has stats.
  bool get hasStats => stats != null;

  /// Get today's attendance from history.
  Attendance? get todayAttendance {
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return history.cast<Attendance?>().firstWhere(
      (a) => a?.date == todayStr,
      orElse: () => null,
    );
  }

  /// Filter history by selected period.
  List<Attendance> get filteredHistory {
    if (history.isEmpty) return [];

    final now = DateTime.now();
    switch (selectedPeriod) {
      case AttendancePeriod.week:
        final weekAgo = now.subtract(const Duration(days: 7));
        return history.where((a) {
          final date = DateTime.tryParse(a.date);
          return date != null && date.isAfter(weekAgo);
        }).toList();
      case AttendancePeriod.month:
        final monthAgo = now.subtract(const Duration(days: 30));
        return history.where((a) {
          final date = DateTime.tryParse(a.date);
          return date != null && date.isAfter(monthAgo);
        }).toList();
      case AttendancePeriod.all:
        return history;
    }
  }

  /// Get total duration for filtered period.
  int get filteredTotalMinutes {
    return filteredHistory.fold<int>(
      0,
      (sum, a) => sum + (a.sessionDurationMinutes ?? 0),
    );
  }

  /// Get formatted total duration for filtered period.
  String get filteredFormattedDuration {
    final minutes = filteredTotalMinutes;
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  AttendanceHistoryState copyWith({
    AttendanceHistoryStatus? status,
    List<Attendance>? history,
    AttendanceStats? stats,
    AttendancePeriod? selectedPeriod,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AttendanceHistoryState(
      status: status ?? this.status,
      history: history ?? this.history,
      stats: stats ?? this.stats,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    status,
    history,
    stats,
    selectedPeriod,
    errorMessage,
  ];
}

/// Status enum for AttendanceHistoryCubit.
enum AttendanceHistoryStatus { initial, loading, loaded, error }
