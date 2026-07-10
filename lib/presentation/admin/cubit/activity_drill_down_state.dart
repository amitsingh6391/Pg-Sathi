part of 'activity_drill_down_cubit.dart';

/// Status of activity drill-down data fetching.
enum ActivityDrillDownStatus {
  initial,
  loading,
  loaded,
  error,
}

/// State for activity drill-down views.
class ActivityDrillDownState extends Equatable {
  const ActivityDrillDownState({
    this.status = ActivityDrillDownStatus.initial,
    this.activeUsers = const [],
    this.userTimeline = const [],
    this.selectedDate,
    this.selectedHour,
    this.selectedUserId,
    this.errorMessage,
  });

  /// Current loading status.
  final ActivityDrillDownStatus status;

  /// List of users active in selected hour.
  final List<UserActivityDetail> activeUsers;

  /// Activity timeline for selected user.
  final List<UserActivityTimeline> userTimeline;

  /// Selected date for hourly drill-down.
  final DateTime? selectedDate;

  /// Selected hour (0-23) for hourly drill-down.
  final int? selectedHour;

  /// Selected user ID for timeline drill-down.
  final String? selectedUserId;

  /// Error message if status is error.
  final String? errorMessage;

  /// Convenience getters
  bool get isLoading => status == ActivityDrillDownStatus.loading;
  bool get isLoaded => status == ActivityDrillDownStatus.loaded;
  bool get hasError => status == ActivityDrillDownStatus.error;
  bool get isEmpty =>
      isLoaded && activeUsers.isEmpty && userTimeline.isEmpty;

  @override
  List<Object?> get props => [
        status,
        activeUsers,
        userTimeline,
        selectedDate,
        selectedHour,
        selectedUserId,
        errorMessage,
      ];

  ActivityDrillDownState copyWith({
    ActivityDrillDownStatus? status,
    List<UserActivityDetail>? activeUsers,
    List<UserActivityTimeline>? userTimeline,
    DateTime? selectedDate,
    int? selectedHour,
    String? selectedUserId,
    String? errorMessage,
  }) {
    return ActivityDrillDownState(
      status: status ?? this.status,
      activeUsers: activeUsers ?? this.activeUsers,
      userTimeline: userTimeline ?? this.userTimeline,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedHour: selectedHour ?? this.selectedHour,
      selectedUserId: selectedUserId ?? this.selectedUserId,
      errorMessage: errorMessage,
    );
  }
}
