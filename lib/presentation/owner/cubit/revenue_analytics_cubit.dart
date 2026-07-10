import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../domain/usecases/get_revenue_analytics.dart';

/// State for Revenue Analytics.
class RevenueAnalyticsState extends Equatable {
  const RevenueAnalyticsState({
    this.isLoading = false,
    this.analytics,
    this.errorMessage,
  });

  final bool isLoading;
  final RevenueAnalytics? analytics;
  final String? errorMessage;

  bool get hasData => analytics != null;
  bool get hasError => errorMessage != null;

  RevenueAnalyticsState copyWith({
    bool? isLoading,
    RevenueAnalytics? analytics,
    String? errorMessage,
  }) {
    return RevenueAnalyticsState(
      isLoading: isLoading ?? this.isLoading,
      analytics: analytics ?? this.analytics,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [isLoading, analytics, errorMessage];
}

/// Cubit for managing revenue analytics state.
class RevenueAnalyticsCubit extends Cubit<RevenueAnalyticsState> {
  RevenueAnalyticsCubit({required this.getRevenueAnalytics})
    : super(const RevenueAnalyticsState());

  final GetRevenueAnalytics getRevenueAnalytics;

  /// Loads revenue analytics for a library.
  Future<void> loadAnalytics(String libraryId) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));

    final result = await getRevenueAnalytics(
      GetRevenueAnalyticsParams(libraryId: libraryId),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          isLoading: false,
          errorMessage: failure.message ?? 'Failed to load analytics',
        ),
      ),
      (analytics) =>
          emit(state.copyWith(isLoading: false, analytics: analytics)),
    );
  }

  /// Refreshes analytics data.
  Future<void> refresh(String libraryId) => loadAnalytics(libraryId);
}
