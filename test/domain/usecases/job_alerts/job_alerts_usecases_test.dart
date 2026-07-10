import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/data/failures/data_failures.dart';
import 'package:pg_manager/domain/entities/job_alert.dart';
import 'package:pg_manager/domain/entities/job_alert_candidate.dart';
import 'package:pg_manager/domain/entities/user_job_preferences.dart';
import 'package:pg_manager/domain/repositories/job_alerts_repository.dart';
import 'package:pg_manager/domain/usecases/job_alerts/job_alerts_usecases.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements JobAlertsRepository {}

class _FakeJobAlert extends Fake implements JobAlert {}

class _FakeJobCandidate extends Fake implements JobAlertCandidate {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeJobAlert());
    registerFallbackValue(_FakeJobCandidate());
    registerFallbackValue(JobCandidateStatus.pending);
  });

  late _MockRepo mockRepo;
  setUp(() => mockRepo = _MockRepo());

  final testJob = JobAlert(
    id: 'job-1',
    title: 'SSC CGL 2026',
    organization: 'SSC',
    category: JobCategory.ssc,
    status: JobStatus.openForApplication,
    postedAt: DateTime(2026, 5, 1),
    updatedAt: DateTime(2026, 5, 1),
    isActive: true,
  );

  group('GetJobAlerts', () {
    late GetJobAlerts useCase;
    setUp(() => useCase = GetJobAlerts(mockRepo));

    test('should_forward_paginated_result_on_success', () async {
      when(() => mockRepo.getJobAlerts(
            categories: any(named: 'categories'),
            states: any(named: 'states'),
            status: any(named: 'status'),
            type: any(named: 'type'),
            cursor: any(named: 'cursor'),
            pageSize: any(named: 'pageSize'),
          )).thenAnswer(
        (_) async => Right(
          PaginatedJobAlerts(items: [testJob], nextCursor: null),
        ),
      );

      final result = await useCase();

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected Right'),
        (page) {
          expect(page.items, hasLength(1));
          expect(page.hasMore, isFalse);
        },
      );
    });

    test('should_propagate_failure_when_repo_fails', () async {
      when(() => mockRepo.getJobAlerts(
            categories: any(named: 'categories'),
            states: any(named: 'states'),
            status: any(named: 'status'),
            type: any(named: 'type'),
            cursor: any(named: 'cursor'),
            pageSize: any(named: 'pageSize'),
          )).thenAnswer(
        (_) async => const Left(ServerFailure(message: 'boom')),
      );

      final result = await useCase();

      expect(result.isLeft(), isTrue);
    });

    test('should_pass_filters_through_to_repository', () async {
      when(() => mockRepo.getJobAlerts(
            categories: any(named: 'categories'),
            states: any(named: 'states'),
            status: any(named: 'status'),
            type: any(named: 'type'),
            cursor: any(named: 'cursor'),
            pageSize: any(named: 'pageSize'),
          )).thenAnswer(
        (_) async => const Right(
          PaginatedJobAlerts(items: [], nextCursor: null),
        ),
      );

      await useCase(
        categories: {JobCategory.ssc},
        status: JobStatus.openForApplication,
        type: JobAlertType.admitCard,
        pageSize: 10,
      );

      verify(() => mockRepo.getJobAlerts(
            categories: {JobCategory.ssc},
            states: null,
            status: JobStatus.openForApplication,
            type: JobAlertType.admitCard,
            cursor: null,
            pageSize: 10,
          )).called(1);
    });
  });

  group('RecordApplyClick', () {
    late RecordApplyClick useCase;
    setUp(() => useCase = RecordApplyClick(mockRepo));

    test('should_forward_all_arguments_to_repository', () async {
      when(() => mockRepo.recordApplyClick(
            jobId: any(named: 'jobId'),
            userId: any(named: 'userId'),
            linkIndex: any(named: 'linkIndex'),
            destinationUrl: any(named: 'destinationUrl'),
            partnerSource: any(named: 'partnerSource'),
          )).thenAnswer((_) async => const Right(null));

      await useCase(
        jobId: 'job-1',
        userId: 'user-1',
        linkIndex: 0,
        destinationUrl: 'https://example.com',
        partnerSource: 'testbook',
      );

      verify(() => mockRepo.recordApplyClick(
            jobId: 'job-1',
            userId: 'user-1',
            linkIndex: 0,
            destinationUrl: 'https://example.com',
            partnerSource: 'testbook',
          )).called(1);
    });
  });

  group('ToggleJobBookmark', () {
    late ToggleJobBookmark useCase;
    setUp(() => useCase = ToggleJobBookmark(mockRepo));

    test('should_forward_bookmark_true_to_repository', () async {
      when(() => mockRepo.toggleBookmark(
            jobId: any(named: 'jobId'),
            userId: any(named: 'userId'),
            bookmark: any(named: 'bookmark'),
          )).thenAnswer((_) async => const Right(null));

      await useCase(jobId: 'j', userId: 'u', bookmark: true);

      verify(() => mockRepo.toggleBookmark(
            jobId: 'j',
            userId: 'u',
            bookmark: true,
          )).called(1);
    });
  });

  group('GetJobAlertCandidates', () {
    late GetJobAlertCandidates useCase;
    setUp(() => useCase = GetJobAlertCandidates(mockRepo));

    test('should_default_to_pending_status', () async {
      when(() => mockRepo.getCandidates(
            status: any(named: 'status'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => const Right([]));

      await useCase();

      verify(() => mockRepo.getCandidates(
            status: JobCandidateStatus.pending,
            limit: 50,
          )).called(1);
    });
  });

  group('PublishJobAlert', () {
    late PublishJobAlert useCase;
    setUp(() => useCase = PublishJobAlert(mockRepo));

    test('should_forward_candidateId_when_provided', () async {
      when(() => mockRepo.publishJobAlert(
            draft: any(named: 'draft'),
            candidateId: any(named: 'candidateId'),
            adminId: any(named: 'adminId'),
          )).thenAnswer((_) async => Right(testJob));

      await useCase(
        draft: testJob,
        adminId: 'admin-1',
        candidateId: 'cand-1',
      );

      verify(() => mockRepo.publishJobAlert(
            draft: testJob,
            candidateId: 'cand-1',
            adminId: 'admin-1',
          )).called(1);
    });
  });

  group('GetUserJobPreferences', () {
    late GetUserJobPreferences useCase;
    setUp(() => useCase = GetUserJobPreferences(mockRepo));

    test('should_return_preferences_from_repository', () async {
      final prefs = UserJobPreferences.defaultFor('user-1');
      when(() => mockRepo.getUserPreferences('user-1'))
          .thenAnswer((_) async => Right(prefs));

      final result = await useCase('user-1');

      result.fold(
        (_) => fail('expected Right'),
        (p) => expect(p, equals(prefs)),
      );
    });
  });

  group('TriggerJobFetchNow', () {
    late TriggerJobFetchNow useCase;
    setUp(() => useCase = TriggerJobFetchNow(mockRepo));

    test('should_default_limit_to_25_when_unspecified', () async {
      when(() => mockRepo.triggerFetchNow(
            limitPerSource: any(named: 'limitPerSource'),
          )).thenAnswer((_) async => const Right(12));

      await useCase();

      verify(() =>
              mockRepo.triggerFetchNow(limitPerSource: 25))
          .called(1);
    });

    test('should_forward_custom_limit_to_repository', () async {
      when(() => mockRepo.triggerFetchNow(
            limitPerSource: any(named: 'limitPerSource'),
          )).thenAnswer((_) async => const Right(0));

      await useCase(limitPerSource: 100);

      verify(() =>
              mockRepo.triggerFetchNow(limitPerSource: 100))
          .called(1);
    });

    test('should_propagate_failure_from_repository', () async {
      when(() => mockRepo.triggerFetchNow(
            limitPerSource: any(named: 'limitPerSource'),
          )).thenAnswer(
        (_) async => const Left(ServerFailure(message: 'down')),
      );

      final result = await useCase();

      expect(result.isLeft(), isTrue);
    });
  });

  group('PublishJobCandidatesBulk', () {
    late PublishJobCandidatesBulk useCase;
    setUp(() => useCase = PublishJobCandidatesBulk(mockRepo));

    final candidate = JobAlertCandidate(
      id: 'cand-1',
      sourceId: 'src-1',
      rawTitle: 'SSC CGL 2026 recruitment',
      rawLink: 'https://example.com/ssc-cgl',
      normalizedKey: 'ssccgl2026recruitment',
      fetchedAt: DateTime(2026, 5, 1),
      status: JobCandidateStatus.pending,
    );

    test('should_forward_candidates_and_adminId_to_repository', () async {
      when(() => mockRepo.publishCandidatesBulk(
            candidates: any(named: 'candidates'),
            adminId: any(named: 'adminId'),
          )).thenAnswer((_) async => Right([testJob]));

      final result = await useCase(
        candidates: [candidate],
        adminId: 'admin-1',
      );

      expect(result.isRight(), isTrue);
      verify(() => mockRepo.publishCandidatesBulk(
            candidates: [candidate],
            adminId: 'admin-1',
          )).called(1);
    });

    test('should_propagate_failure_when_bulk_fails', () async {
      when(() => mockRepo.publishCandidatesBulk(
            candidates: any(named: 'candidates'),
            adminId: any(named: 'adminId'),
          )).thenAnswer(
        (_) async => const Left(ServerFailure(message: 'boom')),
      );

      final result = await useCase(
        candidates: [candidate],
        adminId: 'admin-1',
      );

      expect(result.isLeft(), isTrue);
    });
  });
}
