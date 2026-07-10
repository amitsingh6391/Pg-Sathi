import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/job_alert.dart';
import '../entities/job_alert_candidate.dart';
import '../entities/job_alert_source.dart';
import '../entities/user_job_preferences.dart';

/// Paginated results helper. Kept free of Firestore types so domain callers
/// (use cases, cubits) are oblivious to the storage engine.
class PaginatedJobAlerts {
  const PaginatedJobAlerts({
    required this.items,
    required this.nextCursor,
  });

  final List<JobAlert> items;

  /// Opaque cursor for the next page. Null when no more pages are available.
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}

/// Analytics rollup for a single job alert.
class JobAlertAnalytics {
  const JobAlertAnalytics({
    required this.jobId,
    required this.viewCount,
    required this.applyClickCount,
    required this.bookmarkCount,
    required this.uniqueViewers,
    required this.uniqueClickers,
    required this.clicksByLinkIndex,
  });

  final String jobId;
  final int viewCount;
  final int applyClickCount;
  final int bookmarkCount;
  final int uniqueViewers;
  final int uniqueClickers;

  /// Breakdown of apply clicks per importantLinks index.
  final Map<int, int> clicksByLinkIndex;

  /// Click-through-rate on views. Guards against zero viewers.
  double get clickRate =>
      viewCount > 0 ? (applyClickCount / viewCount) * 100.0 : 0.0;
}

/// Repository contract for everything job-alert related: discovery,
/// curation, publishing, analytics, and student-side reads.
///
/// Implementations are expected to treat all failures as recoverable
/// (mapped to [Failure]); throwing is reserved for programmer errors.
abstract class JobAlertsRepository {
  // ---------------------------------------------------------------------------
  // Sources (admin-only config)
  // ---------------------------------------------------------------------------

  Future<Either<Failure, List<JobAlertSource>>> getSources();

  Future<Either<Failure, JobAlertSource>> upsertSource(JobAlertSource source);

  // ---------------------------------------------------------------------------
  // Candidates (admin inbox)
  // ---------------------------------------------------------------------------

  /// List inbox candidates, most recent first. Filter by [status] to
  /// show only pending or already-processed items.
  Future<Either<Failure, List<JobAlertCandidate>>> getCandidates({
    required JobCandidateStatus status,
    int limit = 50,
  });

  Future<Either<Failure, JobAlertCandidate>> getCandidateById(String id);

  /// Mark a candidate as ignored without publishing.
  Future<Either<Failure, void>> ignoreCandidate({
    required String candidateId,
    required String adminId,
    String? reason,
  });

  /// Triggers an immediate upstream fetch on behalf of an admin.
  /// [limitPerSource] caps how many items are parsed per source per run
  /// (1–100 inclusive; values outside this range are clamped server-side).
  /// Returns the number of new candidates created (across all sources).
  Future<Either<Failure, int>> triggerFetchNow({int limitPerSource = 25});

  /// Admin-only: publishes a set of candidates in a single batch with
  /// minimal-but-valid defaults (title + category + openForApplication
  /// status + source link). Intended for low-effort bulk workflows;
  /// admins are expected to edit individual cards afterwards to enrich.
  ///
  /// Returns the list of freshly published [JobAlert]s in the same
  /// order as [candidates]. Stops on the first failure and rolls back
  /// already-published drafts via a best-effort delete.
  Future<Either<Failure, List<JobAlert>>> publishCandidatesBulk({
    required List<JobAlertCandidate> candidates,
    required String adminId,
  });

  // ---------------------------------------------------------------------------
  // Published job alerts
  // ---------------------------------------------------------------------------

  /// Student-facing feed. Filters are ANDed together. Pass empty sets
  /// (or nulls) to disable a filter dimension.
  Future<Either<Failure, PaginatedJobAlerts>> getJobAlerts({
    Set<JobCategory>? categories,
    Set<String>? states,
    JobStatus? status,
    JobAlertType? type,
    String? cursor,
    int pageSize = 20,
  });

  Future<Either<Failure, JobAlert>> getJobAlertById(String id);

  /// Admin-only: create a fresh job alert, optionally linked to the
  /// [candidateId] that seeded it (which will be marked as published).
  Future<Either<Failure, JobAlert>> publishJobAlert({
    required JobAlert draft,
    String? candidateId,
    required String adminId,
  });

  Future<Either<Failure, JobAlert>> updateJobAlert(JobAlert job);

  Future<Either<Failure, void>> deleteJobAlert(String id);

  // ---------------------------------------------------------------------------
  // Student interactions
  // ---------------------------------------------------------------------------

  /// Atomically increment the view counter. Safe to call at most once per
  /// session per student per job (caller handles deduplication).
  Future<Either<Failure, void>> recordJobView({
    required String jobId,
    required String userId,
  });

  /// Records an outbound click and atomically increments the click counter.
  Future<Either<Failure, void>> recordApplyClick({
    required String jobId,
    required String userId,
    required int linkIndex,
    required String destinationUrl,
    String? partnerSource,
  });

  Future<Either<Failure, void>> toggleBookmark({
    required String jobId,
    required String userId,
    required bool bookmark,
  });

  Future<Either<Failure, List<JobAlert>>> getSavedJobs(String userId);

  // ---------------------------------------------------------------------------
  // Preferences
  // ---------------------------------------------------------------------------

  Future<Either<Failure, UserJobPreferences>> getUserPreferences(
    String userId,
  );

  Future<Either<Failure, UserJobPreferences>> updateUserPreferences(
    UserJobPreferences prefs,
  );

  // ---------------------------------------------------------------------------
  // Analytics (admin)
  // ---------------------------------------------------------------------------

  Future<Either<Failure, JobAlertAnalytics>> getJobAlertAnalytics(String id);
}
