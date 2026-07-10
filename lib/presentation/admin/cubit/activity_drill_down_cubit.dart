import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/user_activity_detail.dart';
import '../../../domain/usecases/get_hourly_active_users.dart';
import '../../../domain/usecases/get_user_activity_details.dart';

part 'activity_drill_down_state.dart';

/// Cubit for managing activity drill-down views.
/// Handles hourly activity and user activity detail fetching.
class ActivityDrillDownCubit extends Cubit<ActivityDrillDownState> {
  ActivityDrillDownCubit({
    required this.getHourlyActiveUsers,
    required this.getUserActivityDetails,
  }) : super(const ActivityDrillDownState());

  final GetHourlyActiveUsers getHourlyActiveUsers;
  final GetUserActivityDetails getUserActivityDetails;

  /// Loads users active in a specific hour.
  Future<void> loadHourlyActiveUsers({
    required DateTime date,
    required int hour,
  }) async {
    emit(state.copyWith(status: ActivityDrillDownStatus.loading));

    final result = await getHourlyActiveUsers(date: date, hour: hour);

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ActivityDrillDownStatus.error,
          errorMessage: failure.message ?? 'Failed to load active users',
        ),
      ),
      (users) => emit(
        state.copyWith(
          status: ActivityDrillDownStatus.loaded,
          activeUsers: users,
          selectedDate: date,
          selectedHour: hour,
          errorMessage: null,
        ),
      ),
    );
  }

  /// Loads activity timeline for a specific user.
  Future<void> loadUserActivityTimeline({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    emit(state.copyWith(status: ActivityDrillDownStatus.loading));

    final result = await getUserActivityDetails(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ActivityDrillDownStatus.error,
          errorMessage: failure.message ?? 'Failed to load user activity',
        ),
      ),
      (timeline) => emit(
        state.copyWith(
          status: ActivityDrillDownStatus.loaded,
          userTimeline: timeline,
          selectedUserId: userId,
          errorMessage: null,
        ),
      ),
    );
  }

  /// Resets state to initial.
  void reset() {
    emit(const ActivityDrillDownState());
  }
}
