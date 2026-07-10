import 'package:equatable/equatable.dart';

import '../../../../domain/core/failure.dart';
import '../../../../domain/entities/job_alert_candidate.dart';

/// Admin inbox state. Tracks fetch / ignore / bulk-publish workflows
/// plus multi-select session so the UI can render checkboxes and a
/// floating action bar without re-deriving state from BLoC listeners.
class AdminJobCandidatesState extends Equatable {
  const AdminJobCandidatesState({
    this.items = const [],
    this.isLoading = false,
    this.isFetching = false,
    this.isBulkPublishing = false,
    this.failure,
    this.lastFetchNewCount,
    this.limitPerSource = 25,
    this.selectedIds = const <String>{},
    this.selectionMode = false,
    this.lastBulkPublishedCount,
  });

  final List<JobAlertCandidate> items;
  final bool isLoading;

  /// True while the admin-triggered "Fetch Now" is in flight.
  final bool isFetching;

  /// True while a bulk-publish batch is in flight.
  final bool isBulkPublishing;

  final Failure? failure;

  /// Populated after a successful "Fetch Now" so the UI can surface
  /// feedback (e.g. "12 new candidates added").
  final int? lastFetchNewCount;

  /// Items-per-source cap sent to the Cloud Function on the next
  /// "Fetch Now" call. Kept in state so it survives rebuilds without
  /// a separate controller.
  final int limitPerSource;

  /// Ids of candidates currently selected for a bulk action. Empty when
  /// not in [selectionMode].
  final Set<String> selectedIds;

  /// Toggles the multi-select affordance. When true, tiles render
  /// checkboxes and the floating action bar is visible.
  final bool selectionMode;

  /// Populated after a successful bulk publish so the UI can toast
  /// "Published N jobs".
  final int? lastBulkPublishedCount;

  AdminJobCandidatesState copyWith({
    List<JobAlertCandidate>? items,
    bool? isLoading,
    bool? isFetching,
    bool? isBulkPublishing,
    Failure? failure,
    int? lastFetchNewCount,
    int? limitPerSource,
    Set<String>? selectedIds,
    bool? selectionMode,
    int? lastBulkPublishedCount,
    bool clearFailure = false,
    bool clearFetchCount = false,
    bool clearBulkCount = false,
  }) {
    return AdminJobCandidatesState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isFetching: isFetching ?? this.isFetching,
      isBulkPublishing: isBulkPublishing ?? this.isBulkPublishing,
      failure: clearFailure ? null : (failure ?? this.failure),
      lastFetchNewCount: clearFetchCount
          ? null
          : (lastFetchNewCount ?? this.lastFetchNewCount),
      limitPerSource: limitPerSource ?? this.limitPerSource,
      selectedIds: selectedIds ?? this.selectedIds,
      selectionMode: selectionMode ?? this.selectionMode,
      lastBulkPublishedCount: clearBulkCount
          ? null
          : (lastBulkPublishedCount ?? this.lastBulkPublishedCount),
    );
  }

  @override
  List<Object?> get props => [
        items,
        isLoading,
        isFetching,
        isBulkPublishing,
        failure,
        lastFetchNewCount,
        limitPerSource,
        selectedIds,
        selectionMode,
        lastBulkPublishedCount,
      ];
}
