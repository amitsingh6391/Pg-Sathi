import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/core/usecase.dart';
import '../../../domain/entities/admin_dashboard_stats.dart';
import '../../../domain/entities/library_summary.dart';
import '../../../domain/entities/user_activity_stats.dart';
import '../../../domain/usecases/get_admin_dashboard_data.dart';
import '../../../domain/usecases/get_admin_user_activity.dart';
import '../../../domain/usecases/send_admin_broadcast_notification.dart';

part 'admin_analytics_state.dart';

/// Cubit for managing admin analytics dashboard state.
/// Handles platform-wide statistics and analytics.
class AdminAnalyticsCubit extends Cubit<AdminAnalyticsState> {
  AdminAnalyticsCubit({
    required this.getAdminDashboardData,
    required this.getAdminUserActivity,
    required this.sendAdminBroadcastNotification,
  }) : super(const AdminAnalyticsState());

  final GetAdminDashboardData getAdminDashboardData;
  final GetAdminUserActivity getAdminUserActivity;
  final SendAdminBroadcastNotification sendAdminBroadcastNotification;

  /// Loads all analytics data in parallel.
  /// Dashboard stats + library summaries share a single optimized read,
  /// while user activity runs concurrently.
  Future<void> loadAnalytics() async {
    emit(state.copyWith(status: AdminAnalyticsStatus.loading));

    final results = await Future.wait([
      getAdminDashboardData(const NoParams()),
      getAdminUserActivity(const NoParams()),
    ]);

    final dashboardResult = results[0] as dynamic;
    final activityResult = results[1] as dynamic;

    String? errorMessage;

    dashboardResult.fold(
      (failure) =>
          errorMessage = failure.message ?? 'Failed to load dashboard data',
      (data) {
        emit(
          state.copyWith(
            dashboardStats: data.stats,
            librarySummaries: data.librarySummaries,
          ),
        );
      },
    );

    UserActivityStats? userActivity;
    activityResult.fold(
      (failure) =>
          errorMessage ??= failure.message ?? 'Failed to load user activity',
      (data) => userActivity = data as UserActivityStats,
    );

    if (errorMessage != null && state.dashboardStats == const AdminDashboardStats.empty()) {
      emit(
        state.copyWith(
          status: AdminAnalyticsStatus.error,
          errorMessage: errorMessage,
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: AdminAnalyticsStatus.loaded,
          userActivityStats: userActivity ?? const UserActivityStats.empty(),
          errorMessage: null,
        ),
      );
    }
  }

  /// Sends broadcast notification.
  Future<void> sendBroadcast({
    required String title,
    required String body,
    required BroadcastAudience audience,
    List<String>? libraryIds,
  }) async {
    emit(state.copyWith(isSendingNotification: true));

    final result = await sendAdminBroadcastNotification(
      SendAdminBroadcastParams(
        title: title,
        body: body,
        audience: audience,
        libraryIds: libraryIds,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          isSendingNotification: false,
          notificationError: failure.message ?? 'Failed to send notification',
        ),
      ),
      (count) => emit(
        state.copyWith(
          isSendingNotification: false,
          lastNotificationCount: count,
          notificationError: null,
        ),
      ),
    );
  }

  /// Clears notification status.
  void clearNotificationStatus() {
    emit(state.copyWith(lastNotificationCount: null, notificationError: null));
  }

  /// Filters library summaries by search query.
  void filterLibraries(String query) {
    emit(state.copyWith(librarySearchQuery: query));
  }

  /// Clears library filter.
  void clearLibraryFilter() {
    emit(state.copyWith(librarySearchQuery: '', expirationDaysFilter: null));
  }

  /// Filters libraries by expiration days.
  /// Set to null to clear the filter.
  void filterByExpirationDays(int? days) {
    if (days == null) {
      emit(state.copyWith(clearExpirationFilter: true));
    } else {
      emit(state.copyWith(expirationDaysFilter: days));
    }
  }
}
