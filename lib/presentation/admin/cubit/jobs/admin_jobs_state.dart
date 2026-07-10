import 'package:equatable/equatable.dart';

import '../../../../domain/core/failure.dart';
import '../../../../domain/entities/job_alert.dart';

class AdminJobsState extends Equatable {
  const AdminJobsState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isSaving = false,
    this.hasMore = false,
    this.cursor,
    this.failure,
  });

  final List<JobAlert> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isSaving;
  final bool hasMore;
  final String? cursor;
  final Failure? failure;

  AdminJobsState copyWith({
    List<JobAlert>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isSaving,
    bool? hasMore,
    String? cursor,
    Failure? failure,
    bool clearFailure = false,
    bool clearCursor = false,
  }) {
    return AdminJobsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSaving: isSaving ?? this.isSaving,
      hasMore: hasMore ?? this.hasMore,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [
        items,
        isLoading,
        isLoadingMore,
        isSaving,
        hasMore,
        cursor,
        failure,
      ];
}
