import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/entities/job_alert_candidate.dart';
import '../../../../domain/usecases/job_alerts/job_alerts_usecases.dart';
import 'admin_job_candidates_state.dart';

/// Admin inbox cubit. Owns the fetch/ignore/bulk-publish workflows and
/// multi-select session so the UI stays thin.
///
/// Bulk publish delegates to [publishJobCandidatesBulk] (which takes
/// candidate snapshots, not ids) — this lets the repository build minimal
/// [JobAlert] drafts without extra round-trips. Individual single-card
/// publish still goes through [AdminJobsCubit.publish] so the jobs list
/// on the adjacent tab stays in sync.
class AdminJobCandidatesCubit extends Cubit<AdminJobCandidatesState> {
  AdminJobCandidatesCubit({
    required this.getJobAlertCandidates,
    required this.ignoreJobAlertCandidate,
    required this.triggerJobFetchNow,
    required this.publishJobCandidatesBulk,
  }) : super(const AdminJobCandidatesState());

  final GetJobAlertCandidates getJobAlertCandidates;
  final IgnoreJobAlertCandidate ignoreJobAlertCandidate;
  final TriggerJobFetchNow triggerJobFetchNow;
  final PublishJobCandidatesBulk publishJobCandidatesBulk;

  static const _allowedFetchLimits = <int>[10, 25, 50, 100];

  Future<void> load({
    JobCandidateStatus status = JobCandidateStatus.pending,
  }) async {
    emit(state.copyWith(isLoading: true, clearFailure: true));
    final result = await getJobAlertCandidates(status: status);
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, failure: failure)),
      (items) => emit(state.copyWith(items: items, isLoading: false)),
    );
  }

  /// Clamps to the nearest allowed bucket so the UI and server agree on
  /// valid values. Silently ignored when unchanged.
  void setFetchLimit(int value) {
    final sanitized = _allowedFetchLimits.contains(value)
        ? value
        : _allowedFetchLimits.reduce(
            (a, b) => (a - value).abs() < (b - value).abs() ? a : b,
          );
    if (sanitized == state.limitPerSource) return;
    emit(state.copyWith(limitPerSource: sanitized));
  }

  /// Runs the admin-on-demand RSS pull and reloads the list.
  Future<void> fetchNow() async {
    if (state.isFetching) return;
    emit(state.copyWith(
      isFetching: true,
      clearFailure: true,
      clearFetchCount: true,
    ));

    final result =
        await triggerJobFetchNow(limitPerSource: state.limitPerSource);
    await result.fold(
      (failure) async {
        emit(state.copyWith(isFetching: false, failure: failure));
      },
      (newCount) async {
        emit(state.copyWith(
          isFetching: false,
          lastFetchNewCount: newCount,
        ));
        await load();
      },
    );
  }

  Future<void> ignore({
    required String candidateId,
    required String adminId,
    String? reason,
  }) async {
    final previous = state.items;
    emit(state.copyWith(
      items:
          previous.where((c) => c.id != candidateId).toList(growable: false),
      selectedIds: state.selectedIds.difference({candidateId}),
    ));

    final result = await ignoreJobAlertCandidate(
      candidateId: candidateId,
      adminId: adminId,
      reason: reason,
    );
    result.fold(
      (failure) => emit(state.copyWith(items: previous, failure: failure)),
      (_) {},
    );
  }

  // ---------------------------------------------------------------------------
  // Selection mode
  // ---------------------------------------------------------------------------

  void enterSelectionMode({String? initialId}) {
    emit(state.copyWith(
      selectionMode: true,
      selectedIds: initialId == null ? <String>{} : {initialId},
    ));
  }

  void exitSelectionMode() {
    emit(state.copyWith(
      selectionMode: false,
      selectedIds: const <String>{},
    ));
  }

  void toggleSelection(String candidateId) {
    final next = Set<String>.from(state.selectedIds);
    if (!next.add(candidateId)) next.remove(candidateId);
    emit(state.copyWith(
      selectedIds: next,
      selectionMode: next.isNotEmpty || state.selectionMode,
    ));
  }

  void selectAll() {
    emit(state.copyWith(
      selectedIds: state.items.map((c) => c.id).toSet(),
      selectionMode: true,
    ));
  }

  // ---------------------------------------------------------------------------
  // Bulk publish
  // ---------------------------------------------------------------------------

  /// Publishes every currently-selected candidate with minimal defaults.
  /// The admin can enrich each resulting job via the edit form later.
  Future<bool> publishSelected({required String adminId}) async {
    if (state.selectedIds.isEmpty || state.isBulkPublishing) return false;

    final selected = state.items
        .where((c) => state.selectedIds.contains(c.id))
        .toList(growable: false);

    emit(state.copyWith(
      isBulkPublishing: true,
      clearFailure: true,
      clearBulkCount: true,
    ));

    final result = await publishJobCandidatesBulk(
      candidates: selected,
      adminId: adminId,
    );
    return result.fold<bool>(
      (failure) {
        emit(state.copyWith(
          isBulkPublishing: false,
          failure: failure,
        ));
        return false;
      },
      (published) {
        // Remove published candidates from the inbox list locally.
        final publishedIds = selected.map((c) => c.id).toSet();
        emit(state.copyWith(
          items: state.items
              .where((c) => !publishedIds.contains(c.id))
              .toList(growable: false),
          isBulkPublishing: false,
          selectedIds: const <String>{},
          selectionMode: false,
          lastBulkPublishedCount: published.length,
        ));
        return true;
      },
    );
  }

  /// Ignores every currently-selected candidate. Stops on the first
  /// failure and surfaces it so the admin can retry.
  Future<void> ignoreSelected({required String adminId}) async {
    if (state.selectedIds.isEmpty) return;
    final ids = state.selectedIds.toList();
    for (final id in ids) {
      await ignore(candidateId: id, adminId: adminId);
      if (state.failure != null) break;
    }
    emit(state.copyWith(
      selectionMode: false,
      selectedIds: const <String>{},
    ));
  }

  /// Called after a sibling cubit publishes a candidate so this screen's
  /// list stays in sync without another round trip.
  void markPublishedLocally(String candidateId) {
    emit(state.copyWith(
      items: state.items
          .where((c) => c.id != candidateId)
          .toList(growable: false),
      selectedIds: state.selectedIds.difference({candidateId}),
    ));
  }

  /// Resets one-shot UI flags after the view has surfaced them (snackbars
  /// etc.) so they don't re-fire on the next rebuild.
  void acknowledgeFetchResult() {
    if (state.lastFetchNewCount == null) return;
    emit(state.copyWith(clearFetchCount: true));
  }

  void acknowledgeBulkPublishResult() {
    if (state.lastBulkPublishedCount == null) return;
    emit(state.copyWith(clearBulkCount: true));
  }

  void acknowledgeFailure() {
    if (state.failure == null) return;
    emit(state.copyWith(clearFailure: true));
  }
}
