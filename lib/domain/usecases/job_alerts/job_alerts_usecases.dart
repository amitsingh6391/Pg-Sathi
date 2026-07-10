import 'package:dartz/dartz.dart';

import '../../core/failure.dart';
import '../../entities/job_alert.dart';
import '../../entities/job_alert_candidate.dart';
import '../../entities/job_alert_source.dart';
import '../../entities/user_job_preferences.dart';
import '../../repositories/job_alerts_repository.dart';

// =============================================================================
// Student-facing use cases
// =============================================================================

/// Fetches the paginated student feed. Passing null / empty filter values
/// disables the corresponding filter dimension.
class GetJobAlerts {
  const GetJobAlerts(this.repository);
  final JobAlertsRepository repository;

  Future<Either<Failure, PaginatedJobAlerts>> call({
    Set<JobCategory>? categories,
    Set<String>? states,
    JobStatus? status,
    JobAlertType? type,
    String? cursor,
    int pageSize = 20,
  }) {
    return repository.getJobAlerts(
      categories: categories,
      states: states,
      status: status,
      type: type,
      cursor: cursor,
      pageSize: pageSize,
    );
  }
}

class GetJobAlertById {
  const GetJobAlertById(this.repository);
  final JobAlertsRepository repository;

  Future<Either<Failure, JobAlert>> call(String id) {
    return repository.getJobAlertById(id);
  }
}

/// Records a view. Callers must pre-filter to once-per-session per job so
/// the view counter is not inflated by list scrolls.
class RecordJobView {
  const RecordJobView(this.repository);
  final JobAlertsRepository repository;

  Future<Either<Failure, void>> call({
    required String jobId,
    required String userId,
  }) {
    return repository.recordJobView(jobId: jobId, userId: userId);
  }
}

/// Records an outbound apply click. The caller is expected to open the
/// [destinationUrl] *after* this returns so the click is attributed even
/// if the launcher fails.
class RecordApplyClick {
  const RecordApplyClick(this.repository);
  final JobAlertsRepository repository;

  Future<Either<Failure, void>> call({
    required String jobId,
    required String userId,
    required int linkIndex,
    required String destinationUrl,
    String? partnerSource,
  }) {
    return repository.recordApplyClick(
      jobId: jobId,
      userId: userId,
      linkIndex: linkIndex,
      destinationUrl: destinationUrl,
      partnerSource: partnerSource,
    );
  }
}

class ToggleJobBookmark {
  const ToggleJobBookmark(this.repository);
  final JobAlertsRepository repository;

  Future<Either<Failure, void>> call({
    required String jobId,
    required String userId,
    required bool bookmark,
  }) {
    return repository.toggleBookmark(
      jobId: jobId,
      userId: userId,
      bookmark: bookmark,
    );
  }
}

class GetSavedJobs {
  const GetSavedJobs(this.repository);
  final JobAlertsRepository repository;

  Future<Either<Failure, List<JobAlert>>> call(String userId) {
    return repository.getSavedJobs(userId);
  }
}

class GetUserJobPreferences {
  const GetUserJobPreferences(this.repository);
  final JobAlertsRepository repository;

  Future<Either<Failure, UserJobPreferences>> call(String userId) {
    return repository.getUserPreferences(userId);
  }
}

class UpdateUserJobPreferences {
  const UpdateUserJobPreferences(this.repository);
  final JobAlertsRepository repository;

  Future<Either<Failure, UserJobPreferences>> call(
    UserJobPreferences prefs,
  ) {
    return repository.updateUserPreferences(prefs);
  }
}

// =============================================================================
// Admin-facing use cases
// =============================================================================

class GetJobAlertSources {
  const GetJobAlertSources(this.repository);
  final JobAlertsRepository repository;

  Future<Either<Failure, List<JobAlertSource>>> call() {
    return repository.getSources();
  }
}

class UpsertJobAlertSource {
  const UpsertJobAlertSource(this.repository);
  final JobAlertsRepository repository;

  Future<Either<Failure, JobAlertSource>> call(JobAlertSource source) {
    return repository.upsertSource(source);
  }
}

class GetJobAlertCandidates {
  const GetJobAlertCandidates(this.repository);
  final JobAlertsRepository repository;

  Future<Either<Failure, List<JobAlertCandidate>>> call({
    JobCandidateStatus status = JobCandidateStatus.pending,
    int limit = 50,
  }) {
    return repository.getCandidates(status: status, limit: limit);
  }
}

class IgnoreJobAlertCandidate {
  const IgnoreJobAlertCandidate(this.repository);
  final JobAlertsRepository repository;

  Future<Either<Failure, void>> call({
    required String candidateId,
    required String adminId,
    String? reason,
  }) {
    return repository.ignoreCandidate(
      candidateId: candidateId,
      adminId: adminId,
      reason: reason,
    );
  }
}

/// Triggers the ingestion Cloud Function on demand. Returns the count of
/// new candidates surfaced by the call. [limitPerSource] caps how many
/// items are parsed per source (1–100, default 25).
class TriggerJobFetchNow {
  const TriggerJobFetchNow(this.repository);
  final JobAlertsRepository repository;

  Future<Either<Failure, int>> call({int limitPerSource = 25}) {
    return repository.triggerFetchNow(limitPerSource: limitPerSource);
  }
}

/// Publishes a batch of candidates with minimal defaults derived from
/// the raw RSS data. Intended for rapid triage; individual posts can be
/// enriched later via [UpdateJobAlert].
class PublishJobCandidatesBulk {
  const PublishJobCandidatesBulk(this.repository);
  final JobAlertsRepository repository;

  Future<Either<Failure, List<JobAlert>>> call({
    required List<JobAlertCandidate> candidates,
    required String adminId,
  }) {
    return repository.publishCandidatesBulk(
      candidates: candidates,
      adminId: adminId,
    );
  }
}

/// Publishes a draft job alert. When [candidateId] is provided, the
/// matching inbox row is transitioned to
/// [JobCandidateStatus.published].
class PublishJobAlert {
  const PublishJobAlert(this.repository);
  final JobAlertsRepository repository;

  Future<Either<Failure, JobAlert>> call({
    required JobAlert draft,
    required String adminId,
    String? candidateId,
  }) {
    return repository.publishJobAlert(
      draft: draft,
      adminId: adminId,
      candidateId: candidateId,
    );
  }
}

class UpdateJobAlert {
  const UpdateJobAlert(this.repository);
  final JobAlertsRepository repository;

  Future<Either<Failure, JobAlert>> call(JobAlert job) {
    return repository.updateJobAlert(job);
  }
}

class DeleteJobAlert {
  const DeleteJobAlert(this.repository);
  final JobAlertsRepository repository;

  Future<Either<Failure, void>> call(String id) {
    return repository.deleteJobAlert(id);
  }
}

class GetJobAlertAnalytics {
  const GetJobAlertAnalytics(this.repository);
  final JobAlertsRepository repository;

  Future<Either<Failure, JobAlertAnalytics>> call(String jobId) {
    return repository.getJobAlertAnalytics(jobId);
  }
}
