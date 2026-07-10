import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/analytics_summary.dart';
import '../../../domain/repositories/analytics_dashboard_repository.dart';

part 'feature_analytics_state.dart';

/// Cubit for managing feature analytics dashboard state.
class FeatureAnalyticsCubit extends Cubit<FeatureAnalyticsState> {
  final AnalyticsDashboardRepository _repository;
  StreamSubscription<List<AnalyticsSummary>>? _recentEventsSubscription;

  FeatureAnalyticsCubit(this._repository)
      : super(const FeatureAnalyticsState());

  Future<void> loadAnalytics({
    String? role,
    String? timeRange,
  }) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));

    try {
      final dateRange = _getDateRange(timeRange ?? '7d');

      // Load all analytics data in parallel
      final results = await Future.wait([
        _repository.getEventCounts(
          role: role,
          startDate: dateRange.$1,
          endDate: dateRange.$2,
        ),
        _repository.getPlatformCounts(
          role: role,
          startDate: dateRange.$1,
          endDate: dateRange.$2,
        ),
        _repository.getRoleCounts(
          startDate: dateRange.$1,
          endDate: dateRange.$2,
        ),
      ]);

      final eventCounts = results[0];
      final platformCounts = results[1];
      final roleCounts = results[2];

      emit(state.copyWith(
        isLoading: false,
        eventCounts: eventCounts,
        platformCounts: platformCounts,
        roleCounts: roleCounts,
      ));

      // Subscribe to recent events
      _subscribeToRecentEvents();
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load analytics: ${e.toString()}',
      ));
    }
  }

  void _subscribeToRecentEvents() {
    _recentEventsSubscription?.cancel();
    _recentEventsSubscription = _repository.getRecentEvents(limit: 10).listen(
      (events) {
        if (!isClosed) {
          emit(state.copyWith(recentEvents: events));
        }
      },
      onError: (error) {
        if (!isClosed) {
          emit(state.copyWith(
            errorMessage: 'Failed to load recent events: ${error.toString()}',
          ));
        }
      },
    );
  }

  (DateTime?, DateTime?) _getDateRange(String timeRange) {
    final now = DateTime.now();
    switch (timeRange) {
      case '1d':
        return (now.subtract(const Duration(days: 1)), now);
      case '7d':
        return (now.subtract(const Duration(days: 7)), now);
      case '30d':
        return (now.subtract(const Duration(days: 30)), now);
      case '90d':
        return (now.subtract(const Duration(days: 90)), now);
      default:
        return (now.subtract(const Duration(days: 7)), now);
    }
  }

  @override
  Future<void> close() {
    _recentEventsSubscription?.cancel();
    return super.close();
  }
}
