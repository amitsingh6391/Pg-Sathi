import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/core/failure.dart';
import '../../../../domain/repositories/job_alerts_repository.dart';
import '../../../../domain/usecases/job_alerts/job_alerts_usecases.dart';

class AdminJobAnalyticsState extends Equatable {
  const AdminJobAnalyticsState({
    this.analytics,
    this.isLoading = false,
    this.failure,
  });

  final JobAlertAnalytics? analytics;
  final bool isLoading;
  final Failure? failure;

  AdminJobAnalyticsState copyWith({
    JobAlertAnalytics? analytics,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return AdminJobAnalyticsState(
      analytics: analytics ?? this.analytics,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [analytics, isLoading, failure];
}

class AdminJobAnalyticsCubit extends Cubit<AdminJobAnalyticsState> {
  AdminJobAnalyticsCubit({required this.getJobAlertAnalytics})
      : super(const AdminJobAnalyticsState());

  final GetJobAlertAnalytics getJobAlertAnalytics;

  Future<void> load(String jobId) async {
    emit(state.copyWith(isLoading: true, clearFailure: true));
    final result = await getJobAlertAnalytics(jobId);
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, failure: failure)),
      (a) => emit(state.copyWith(analytics: a, isLoading: false)),
    );
  }
}
