import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../../domain/core/failure.dart';
import '../../domain/entities/job_alert.dart';
import '../../domain/entities/job_alert_candidate.dart';
import '../../domain/entities/job_alert_source.dart';
import '../../domain/entities/user_job_preferences.dart';
import '../../domain/repositories/job_alerts_repository.dart';
import '../failures/data_failures.dart';
import '../models/job_alert_candidate_dto.dart';
import '../models/job_alert_dto.dart';
import '../models/job_alert_source_dto.dart';
import '../models/user_job_preferences_dto.dart';
import '../mappers/candidate_to_job_alert_mapper.dart';

/// Firestore-backed implementation of [JobAlertsRepository].
///
/// Collection layout:
/// - /jobAlertSources/{sourceId}
/// - /jobAlertCandidates/{candidateId}
/// - /jobAlerts/{jobId}
/// - /jobApplyClicks/{clickId}
/// - /userJobPreferences/{userId}
/// - /userSavedJobs/{userId}/items/{jobId}
///
/// All listing queries rely on composite indexes defined in
/// `firestore.indexes.json`.
class JobAlertsRepositoryImpl implements JobAlertsRepository {
  JobAlertsRepositoryImpl({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
    Uuid? uuid,
    CandidateToJobAlertMapper? candidateMapper,
  })  : _firestore = firestore,
        _functions = functions,
        _uuid = uuid ?? const Uuid(),
        _candidateMapper = candidateMapper ?? const CandidateToJobAlertMapper();

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final Uuid _uuid;
  final CandidateToJobAlertMapper _candidateMapper;

  // ---------------------------------------------------------------------------
  // Collection references
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> get _sourcesCol =>
      _firestore.collection('jobAlertSources');

  CollectionReference<Map<String, dynamic>> get _candidatesCol =>
      _firestore.collection('jobAlertCandidates');

  CollectionReference<Map<String, dynamic>> get _jobsCol =>
      _firestore.collection('jobAlerts');

  CollectionReference<Map<String, dynamic>> get _clicksCol =>
      _firestore.collection('jobApplyClicks');

  CollectionReference<Map<String, dynamic>> get _prefsCol =>
      _firestore.collection('userJobPreferences');

  CollectionReference<Map<String, dynamic>> _savedItemsCol(String userId) =>
      _firestore
          .collection('userSavedJobs')
          .doc(userId)
          .collection('items');

  // ---------------------------------------------------------------------------
  // Sources
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, List<JobAlertSource>>> getSources() async {
    try {
      final snap = await _sourcesCol.orderBy('name').get();
      final sources = snap.docs
          .map((d) => JobAlertSourceModel.fromFirestore(d).toEntity())
          .toList(growable: false);
      return Right(sources);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to load sources: $e'));
    }
  }

  @override
  Future<Either<Failure, JobAlertSource>> upsertSource(
    JobAlertSource source,
  ) async {
    try {
      final id = source.id.isEmpty ? _uuid.v4() : source.id;
      final withId = source.copyWith(id: id);
      final model = JobAlertSourceModel.fromEntity(withId);
      await _sourcesCol.doc(id).set(model.toFirestore());
      return Right(withId);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to save source: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Candidates
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, List<JobAlertCandidate>>> getCandidates({
    required JobCandidateStatus status,
    int limit = 50,
  }) async {
    try {
      final snap = await _candidatesCol
          .where('status', isEqualTo: status.name)
          .orderBy('fetchedAt', descending: true)
          .limit(limit)
          .get();
      final items = snap.docs
          .map((d) => JobAlertCandidateModel.fromFirestore(d).toEntity())
          .toList(growable: false);
      return Right(items);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to load candidates: $e'));
    }
  }

  @override
  Future<Either<Failure, JobAlertCandidate>> getCandidateById(
    String id,
  ) async {
    try {
      final doc = await _candidatesCol.doc(id).get();
      if (!doc.exists) {
        return const Left(
          DocumentNotFoundFailure(message: 'Candidate not found'),
        );
      }
      return Right(JobAlertCandidateModel.fromFirestore(doc).toEntity());
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to load candidate: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> ignoreCandidate({
    required String candidateId,
    required String adminId,
    String? reason,
  }) async {
    try {
      await _candidatesCol.doc(candidateId).update({
        'status': JobCandidateStatus.ignored.name,
        'reviewedBy': adminId,
        'reviewedAt': FieldValue.serverTimestamp(),
        'ignoredReason': reason,
      });
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to ignore candidate: $e'));
    }
  }

  @override
  Future<Either<Failure, int>> triggerFetchNow({
    int limitPerSource = 25,
  }) async {
    try {
      final clamped = limitPerSource.clamp(1, 100);
      final callable = _functions.httpsCallable('fetchJobAlertSourcesNow');
      final result = await callable.call<Map<String, dynamic>>({
        'limitPerSource': clamped,
      });
      final created = (result.data['newCandidates'] as num?)?.toInt() ?? 0;
      return Right(created);
    } on FirebaseFunctionsException catch (e) {
      return Left(ServerFailure(
        message: e.message ?? 'Fetch failed (${e.code})',
      ));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to trigger fetch: $e'));
    }
  }

  @override
  Future<Either<Failure, List<JobAlert>>> publishCandidatesBulk({
    required List<JobAlertCandidate> candidates,
    required String adminId,
  }) async {
    if (candidates.isEmpty) return const Right([]);

    final published = <JobAlert>[];
    try {
      for (final candidate in candidates) {
        final draft = _candidateMapper(candidate, adminId);
        final result = await publishJobAlert(
          draft: draft,
          adminId: adminId,
          candidateId: candidate.id,
        );
        final job = result.fold<JobAlert?>(
          (_) => null,
          (j) => j,
        );
        if (job == null) {
          // Best-effort rollback of partials so the admin isn't left with
          // a half-published batch.
          for (final prior in published) {
            await deleteJobAlert(prior.id);
          }
          final failure = result.fold((l) => l, (_) => null);
          return Left(failure ??
              const ServerFailure(message: 'Bulk publish failed'));
        }
        published.add(job);
      }
      return Right(published);
    } catch (e) {
      for (final prior in published) {
        await deleteJobAlert(prior.id);
      }
      return Left(ServerFailure(message: 'Bulk publish failed: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Job alerts (student + admin)
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, PaginatedJobAlerts>> getJobAlerts({
    Set<JobCategory>? categories,
    Set<String>? states,
    JobStatus? status,
    JobAlertType? type,
    String? cursor,
    int pageSize = 20,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _jobsCol
          .where('isActive', isEqualTo: true)
          .orderBy('priority', descending: true)
          .orderBy('postedAt', descending: true);

      if (categories != null && categories.isNotEmpty) {
        query = query.where(
          'category',
          whereIn: categories.map((c) => c.name).toList(),
        );
      }

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      if (type != null) {
        query = query.where('type', isEqualTo: type.name);
      }

      query = query.limit(pageSize);

      if (cursor != null && cursor.isNotEmpty) {
        final cursorDoc = await _jobsCol.doc(cursor).get();
        if (cursorDoc.exists) {
          query = query.startAfterDocument(cursorDoc);
        }
      }

      final snap = await query.get();

      // Client-side state filter — only applied when requested, since
      // Firestore cannot combine arrayContains-any with whereIn cleanly.
      List<JobAlert> items = snap.docs
          .map((d) => JobAlertModel.fromFirestore(d).toEntity())
          .toList();

      if (states != null && states.isNotEmpty) {
        items = items
            .where((j) => j.state == null || states.contains(j.state))
            .toList();
      }

      final nextCursor =
          snap.docs.length < pageSize ? null : snap.docs.last.id;

      return Right(
        PaginatedJobAlerts(items: items, nextCursor: nextCursor),
      );
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to load jobs: $e'));
    }
  }

  @override
  Future<Either<Failure, JobAlert>> getJobAlertById(String id) async {
    try {
      final doc = await _jobsCol.doc(id).get();
      if (!doc.exists) {
        return const Left(
          DocumentNotFoundFailure(message: 'Job alert not found'),
        );
      }
      return Right(JobAlertModel.fromFirestore(doc).toEntity());
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to load job: $e'));
    }
  }

  @override
  Future<Either<Failure, JobAlert>> publishJobAlert({
    required JobAlert draft,
    String? candidateId,
    required String adminId,
  }) async {
    try {
      final id = draft.id.isEmpty ? _uuid.v4() : draft.id;
      final now = DateTime.now();
      final toPersist = draft.copyWith(
        id: id,
        postedAt: draft.postedAt,
        updatedAt: now,
        createdBy: adminId,
        sourceCandidateId: candidateId,
        isActive: true,
      );

      final batch = _firestore.batch();
      batch.set(
        _jobsCol.doc(id),
        JobAlertModel.fromEntity(toPersist).toFirestore(),
      );

      if (candidateId != null) {
        batch.update(_candidatesCol.doc(candidateId), {
          'status': JobCandidateStatus.published.name,
          'publishedJobAlertId': id,
          'reviewedBy': adminId,
          'reviewedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      return Right(toPersist);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to publish job: $e'));
    }
  }

  @override
  Future<Either<Failure, JobAlert>> updateJobAlert(JobAlert job) async {
    try {
      final withTimestamp = job.copyWith(updatedAt: DateTime.now());
      final model = JobAlertModel.fromEntity(withTimestamp);
      await _jobsCol.doc(job.id).update(model.toFirestore());
      return Right(withTimestamp);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to update job: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteJobAlert(String id) async {
    try {
      await _jobsCol.doc(id).delete();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to delete job: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Student interactions
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, void>> recordJobView({
    required String jobId,
    required String userId,
  }) async {
    try {
      await _jobsCol.doc(jobId).update({
        'viewCount': FieldValue.increment(1),
      });
      return const Right(null);
    } catch (e) {
      // View tracking failures are non-fatal for the user flow.
      return Left(ServerFailure(message: 'Failed to record view: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> recordApplyClick({
    required String jobId,
    required String userId,
    required int linkIndex,
    required String destinationUrl,
    String? partnerSource,
  }) async {
    try {
      final clickId = _uuid.v4();
      final batch = _firestore.batch();
      batch.set(_clicksCol.doc(clickId), {
        'userId': userId,
        'jobId': jobId,
        'linkIndex': linkIndex,
        'destinationUrl': destinationUrl,
        'clickedAt': FieldValue.serverTimestamp(),
        'partnerSource': partnerSource,
      });
      batch.update(_jobsCol.doc(jobId), {
        'applyClickCount': FieldValue.increment(1),
      });
      await batch.commit();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to record click: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> toggleBookmark({
    required String jobId,
    required String userId,
    required bool bookmark,
  }) async {
    try {
      final ref = _savedItemsCol(userId).doc(jobId);
      final jobRef = _jobsCol.doc(jobId);
      final batch = _firestore.batch();

      if (bookmark) {
        // Denormalize applicationEndDate to support "expiring soon" queries
        // without a subsequent fan-out read.
        final jobDoc = await jobRef.get();
        final endTs = (jobDoc.data()?['applicationEndDate'] as Timestamp?);
        batch.set(ref, {
          'savedAt': FieldValue.serverTimestamp(),
          'applicationEndDate': endTs,
        });
        batch.update(jobRef, {
          'bookmarkCount': FieldValue.increment(1),
        });
      } else {
        batch.delete(ref);
        batch.update(jobRef, {
          'bookmarkCount': FieldValue.increment(-1),
        });
      }

      await batch.commit();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to update bookmark: $e'));
    }
  }

  @override
  Future<Either<Failure, List<JobAlert>>> getSavedJobs(String userId) async {
    try {
      final saved = await _savedItemsCol(userId)
          .orderBy('savedAt', descending: true)
          .limit(100)
          .get();

      if (saved.docs.isEmpty) return const Right([]);

      // Batch-fetch referenced jobs (getAll in chunks of 10, Firestore limit).
      final ids = saved.docs.map((d) => d.id).toList();
      final jobs = <JobAlert>[];
      for (var i = 0; i < ids.length; i += 10) {
        final slice = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
        final snap =
            await _jobsCol.where(FieldPath.documentId, whereIn: slice).get();
        for (final doc in snap.docs) {
          jobs.add(JobAlertModel.fromFirestore(doc).toEntity());
        }
      }

      // Preserve the savedAt order returned by the subcollection.
      final jobsById = {for (final j in jobs) j.id: j};
      final ordered = ids
          .map((id) => jobsById[id])
          .whereType<JobAlert>()
          .toList(growable: false);
      return Right(ordered);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to load saved jobs: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Preferences
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, UserJobPreferences>> getUserPreferences(
    String userId,
  ) async {
    try {
      final doc = await _prefsCol.doc(userId).get();
      if (!doc.exists) {
        return Right(UserJobPreferences.defaultFor(userId));
      }
      return Right(UserJobPreferencesModel.fromFirestore(doc).toEntity());
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to load preferences: $e'));
    }
  }

  @override
  Future<Either<Failure, UserJobPreferences>> updateUserPreferences(
    UserJobPreferences prefs,
  ) async {
    try {
      final model = UserJobPreferencesModel.fromEntity(prefs);
      await _prefsCol.doc(prefs.userId).set(model.toFirestore());
      return Right(prefs.copyWith(updatedAt: DateTime.now()));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to save preferences: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Analytics
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, JobAlertAnalytics>> getJobAlertAnalytics(
    String id,
  ) async {
    try {
      final jobDoc = await _jobsCol.doc(id).get();
      if (!jobDoc.exists) {
        return const Left(
          DocumentNotFoundFailure(message: 'Job alert not found'),
        );
      }
      final job = JobAlertModel.fromFirestore(jobDoc).toEntity();

      // Fetch the click records to compute unique users and link breakdown.
      final clicks =
          await _clicksCol.where('jobId', isEqualTo: id).limit(1000).get();

      final uniqueClickers = <String>{};
      final clicksByLink = <int, int>{};
      for (final doc in clicks.docs) {
        final data = doc.data();
        final uid = data['userId'] as String?;
        final idx = data['linkIndex'] as int? ?? -1;
        if (uid != null) uniqueClickers.add(uid);
        if (idx >= 0) {
          clicksByLink.update(idx, (v) => v + 1, ifAbsent: () => 1);
        }
      }

      // Unique viewers is not tracked per-user yet; surfacing an
      // optimistic approximation equal to viewCount keeps the API stable
      // and can be replaced with a dedup query later.
      return Right(JobAlertAnalytics(
        jobId: id,
        viewCount: job.viewCount,
        applyClickCount: job.applyClickCount,
        bookmarkCount: job.bookmarkCount,
        uniqueViewers: job.viewCount,
        uniqueClickers: uniqueClickers.length,
        clicksByLinkIndex: clicksByLink,
      ));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to load analytics: $e'));
    }
  }
}
