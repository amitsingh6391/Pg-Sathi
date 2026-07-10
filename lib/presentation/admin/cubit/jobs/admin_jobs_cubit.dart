import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/entities/job_alert.dart';
import '../../../../domain/usecases/job_alerts/job_alerts_usecases.dart';
import 'admin_jobs_state.dart';

/// Screen-scoped cubit for the admin "Manage Jobs" list.
///
/// Admin sees ALL jobs (active + inactive); publish / update / delete
/// all funnel through this cubit so the list reflects changes locally.
/// The [adminId] is passed to write operations so audit columns
/// (createdBy, reviewedBy) get populated consistently.
class AdminJobsCubit extends Cubit<AdminJobsState> {
  AdminJobsCubit({
    required this.getJobAlerts,
    required this.publishJobAlert,
    required this.updateJobAlert,
    required this.deleteJobAlert,
  }) : super(const AdminJobsState());

  final GetJobAlerts getJobAlerts;
  final PublishJobAlert publishJobAlert;
  final UpdateJobAlert updateJobAlert;
  final DeleteJobAlert deleteJobAlert;

  Future<void> load() async {
    emit(state.copyWith(
      isLoading: true,
      clearFailure: true,
      clearCursor: true,
    ));
    final result = await getJobAlerts(pageSize: 25);
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, failure: failure)),
      (page) => emit(state.copyWith(
        items: page.items,
        hasMore: page.hasMore,
        cursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        isLoading: false,
      )),
    );
  }

  Future<void> loadMore() async {
    if (!state.hasMore ||
        state.isLoadingMore ||
        state.isLoading ||
        state.cursor == null) {
      return;
    }
    emit(state.copyWith(isLoadingMore: true, clearFailure: true));
    final result = await getJobAlerts(pageSize: 25, cursor: state.cursor);
    result.fold(
      (failure) => emit(state.copyWith(
        isLoadingMore: false,
        failure: failure,
      )),
      (page) => emit(state.copyWith(
        items: [...state.items, ...page.items],
        hasMore: page.hasMore,
        cursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        isLoadingMore: false,
      )),
    );
  }

  /// Publishes a brand new job. When [candidateId] is non-null the
  /// originating inbox row is transitioned atomically.
  Future<bool> publish({
    required JobAlert draft,
    required String adminId,
    String? candidateId,
  }) async {
    emit(state.copyWith(isSaving: true, clearFailure: true));
    final result = await publishJobAlert(
      draft: draft,
      adminId: adminId,
      candidateId: candidateId,
    );
    return result.fold(
      (failure) {
        emit(state.copyWith(isSaving: false, failure: failure));
        return false;
      },
      (published) {
        emit(state.copyWith(
          items: [published, ...state.items],
          isSaving: false,
        ));
        return true;
      },
    );
  }

  Future<bool> update(JobAlert job) async {
    emit(state.copyWith(isSaving: true, clearFailure: true));
    final result = await updateJobAlert(job);
    return result.fold(
      (failure) {
        emit(state.copyWith(isSaving: false, failure: failure));
        return false;
      },
      (updated) {
        emit(state.copyWith(
          isSaving: false,
          items: state.items
              .map((j) => j.id == updated.id ? updated : j)
              .toList(growable: false),
        ));
        return true;
      },
    );
  }

  Future<bool> delete(String jobId) async {
    final previous = state.items;
    emit(state.copyWith(
      items: previous.where((j) => j.id != jobId).toList(growable: false),
    ));
    final result = await deleteJobAlert(jobId);
    return result.fold(
      (failure) {
        emit(state.copyWith(items: previous, failure: failure));
        return false;
      },
      (_) => true,
    );
  }
}
