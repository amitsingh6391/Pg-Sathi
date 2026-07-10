import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/data/repositories/job_alerts_repository_impl.dart';
import 'package:pg_manager/domain/entities/extracted_job_fields.dart';
import 'package:pg_manager/domain/entities/job_alert.dart';
import 'package:pg_manager/domain/entities/job_alert_candidate.dart';
import 'package:pg_manager/domain/entities/labeled_link.dart';
import 'package:mocktail/mocktail.dart';

class _FakeFunctions extends Mock implements FirebaseFunctions {}

/// Helper: seed a JobAlert document directly for query tests.
Future<void> _seedJob(
  FakeFirebaseFirestore db,
  String id, {
  required String category,
  required DateTime postedAt,
  int priority = 5,
  bool isActive = true,
  String status = 'openForApplication',
  String? state,
  String type = 'recruitment',
}) async {
  await db.collection('jobAlerts').doc(id).set({
    'title': 'Job $id',
    'organization': 'Org',
    'category': category,
    'type': type,
    'state': state,
    'status': status,
    'postedAt': Timestamp.fromDate(postedAt),
    'updatedAt': Timestamp.fromDate(postedAt),
    'priority': priority,
    'isActive': isActive,
    'viewCount': 0,
    'applyClickCount': 0,
    'bookmarkCount': 0,
    'importantLinks': const <Map<String, dynamic>>[],
  });
}

void main() {
  late FakeFirebaseFirestore firestore;
  late _FakeFunctions functions;
  late JobAlertsRepositoryImpl repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    functions = _FakeFunctions();
    repository = JobAlertsRepositoryImpl(
      firestore: firestore,
      functions: functions,
    );
  });

  group('JobAlertsRepositoryImpl.getJobAlerts', () {
    test('should_return_empty_when_no_jobs_exist', () async {
      final result = await repository.getJobAlerts();

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('unexpected failure'),
        (page) {
          expect(page.items, isEmpty);
          expect(page.nextCursor, isNull);
        },
      );
    });

    test('should_exclude_inactive_jobs', () async {
      final now = DateTime(2025, 1, 1);
      await _seedJob(firestore, 'a', category: 'ssc', postedAt: now);
      await _seedJob(firestore, 'b',
          category: 'ssc', postedAt: now, isActive: false);

      final result = await repository.getJobAlerts();

      result.fold(
        (_) => fail('unexpected failure'),
        (page) {
          expect(page.items.map((j) => j.id), ['a']);
        },
      );
    });

    test('should_filter_by_categories_when_provided', () async {
      final now = DateTime(2025, 1, 1);
      await _seedJob(firestore, 'ssc1', category: 'ssc', postedAt: now);
      await _seedJob(firestore, 'rrb1', category: 'railway', postedAt: now);
      await _seedJob(firestore, 'ibps1', category: 'banking', postedAt: now);

      final result = await repository.getJobAlerts(
        categories: {JobCategory.ssc, JobCategory.banking},
      );

      result.fold(
        (_) => fail('unexpected failure'),
        (page) {
          final ids = page.items.map((j) => j.id).toSet();
          expect(ids, {'ssc1', 'ibps1'});
        },
      );
    });

    test('should_order_by_priority_desc_then_postedAt_desc', () async {
      final t0 = DateTime(2025, 1, 1);
      await _seedJob(firestore, 'low_recent',
          category: 'ssc', postedAt: t0.add(const Duration(hours: 2)),
          priority: 3);
      await _seedJob(firestore, 'high_old',
          category: 'ssc', postedAt: t0, priority: 8);
      await _seedJob(firestore, 'high_recent',
          category: 'ssc',
          postedAt: t0.add(const Duration(hours: 5)),
          priority: 8);

      final result = await repository.getJobAlerts();

      result.fold(
        (_) => fail('unexpected failure'),
        (page) {
          expect(page.items.map((j) => j.id).toList(),
              ['high_recent', 'high_old', 'low_recent']);
        },
      );
    });

    test('should_filter_by_state_client_side_when_requested', () async {
      final now = DateTime(2025, 1, 1);
      await _seedJob(firestore, 'up_job',
          category: 'statePsc', postedAt: now, state: 'UP');
      await _seedJob(firestore, 'bihar_job',
          category: 'statePsc', postedAt: now, state: 'BR');
      await _seedJob(firestore, 'central_job',
          category: 'statePsc', postedAt: now);

      final result = await repository.getJobAlerts(states: {'UP'});

      result.fold(
        (_) => fail('unexpected failure'),
        (page) {
          final ids = page.items.map((j) => j.id).toSet();
          // 'UP' matches + the null-state job is passed through.
          expect(ids.contains('up_job'), true);
          expect(ids.contains('bihar_job'), false);
          expect(ids.contains('central_job'), true);
        },
      );
    });

    test('should_filter_by_type_when_provided', () async {
      final now = DateTime(2025, 1, 1);
      await _seedJob(firestore, 'rec1', category: 'ssc', postedAt: now);
      await _seedJob(firestore, 'res1',
          category: 'ssc', postedAt: now, type: 'result');
      await _seedJob(firestore, 'admit1',
          category: 'ssc', postedAt: now, type: 'admitCard');

      final result =
          await repository.getJobAlerts(type: JobAlertType.result);

      result.fold(
        (_) => fail('unexpected failure'),
        (page) {
          expect(page.items.map((j) => j.id).toList(), ['res1']);
          expect(page.items.first.type, JobAlertType.result);
        },
      );
    });

    test('should_default_legacy_docs_without_type_to_recruitment',
        () async {
      // Mimic a pre-migration doc by writing without `type` field.
      await firestore.collection('jobAlerts').doc('legacy').set({
        'title': 'legacy',
        'organization': 'Org',
        'category': 'ssc',
        'status': 'openForApplication',
        'postedAt': Timestamp.fromDate(DateTime(2025, 1, 1)),
        'updatedAt': Timestamp.fromDate(DateTime(2025, 1, 1)),
        'priority': 5,
        'isActive': true,
        'viewCount': 0,
        'applyClickCount': 0,
        'bookmarkCount': 0,
        'importantLinks': const <Map<String, dynamic>>[],
      });

      final result = await repository.getJobAlertById('legacy');

      result.fold(
        (_) => fail('unexpected failure'),
        (job) => expect(job.type, JobAlertType.recruitment),
      );
    });

    test('should_paginate_with_cursor', () async {
      final base = DateTime(2025, 1, 1);
      for (var i = 0; i < 5; i++) {
        await _seedJob(firestore, 'j$i',
            category: 'ssc',
            postedAt: base.add(Duration(hours: i)),
            priority: 5);
      }

      final first = await repository.getJobAlerts(pageSize: 2);
      final firstPage = first.getOrElse(() => throw 'a');

      expect(firstPage.items.length, 2);
      expect(firstPage.nextCursor, isNotNull);

      final second = await repository.getJobAlerts(
        pageSize: 2,
        cursor: firstPage.nextCursor,
      );
      final secondPage = second.getOrElse(() => throw 'b');

      final firstIds = firstPage.items.map((j) => j.id).toSet();
      final secondIds = secondPage.items.map((j) => j.id).toSet();
      expect(firstIds.intersection(secondIds), isEmpty);
    });
  });

  group('JobAlertsRepositoryImpl.getJobAlertById', () {
    test('should_return_DocumentNotFoundFailure_when_missing', () async {
      final result = await repository.getJobAlertById('nope');

      expect(result.isLeft(), true);
    });

    test('should_return_entity_when_found', () async {
      await _seedJob(firestore, 'job1',
          category: 'ssc', postedAt: DateTime(2025, 1, 1));

      final result = await repository.getJobAlertById('job1');

      result.fold(
        (_) => fail('unexpected failure'),
        (job) {
          expect(job.id, 'job1');
          expect(job.category, JobCategory.ssc);
        },
      );
    });
  });

  group('JobAlertsRepositoryImpl.publishJobAlert', () {
    test('should_persist_job_and_link_candidate_when_provided', () async {
      await firestore.collection('jobAlertCandidates').doc('cand1').set({
        'title': 'Raw title',
        'organization': 'x',
        'sourceUrl': 'https://x.com',
        'fetchedAt': Timestamp.fromDate(DateTime(2025, 1, 1)),
        'status': JobCandidateStatus.pending.name,
      });

      final draft = JobAlert(
        id: '',
        title: 'SSC CGL 2025',
        organization: 'SSC',
        category: JobCategory.ssc,
        status: JobStatus.openForApplication,
        postedAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        isActive: true,
        importantLinks: const [
          LabeledLink(label: 'Apply', url: 'https://apply.ssc.nic.in'),
        ],
      );

      final result = await repository.publishJobAlert(
        draft: draft,
        candidateId: 'cand1',
        adminId: 'admin1',
      );

      expect(result.isRight(), true);
      final published = result.getOrElse(() => throw 'a');
      expect(published.id, isNotEmpty);
      expect(published.sourceCandidateId, 'cand1');

      final jobDoc =
          await firestore.collection('jobAlerts').doc(published.id).get();
      expect(jobDoc.exists, true);
      expect(jobDoc.data()?['createdBy'], 'admin1');

      final candDoc =
          await firestore.collection('jobAlertCandidates').doc('cand1').get();
      expect(candDoc.data()?['status'], JobCandidateStatus.published.name);
      expect(candDoc.data()?['publishedJobAlertId'], published.id);
    });
  });

  group('JobAlertsRepositoryImpl.publishCandidatesBulk', () {
    test(
        'should_promote_suggestedApplyUrl_to_first_important_link_when_present',
        () async {
      await firestore.collection('jobAlertCandidates').doc('c1').set({
        'sourceId': 's',
        'rawTitle': 'SSC CGL 2026 Recruitment',
        'rawLink': 'https://aggregator.test/ssc-cgl',
        'fetchedAt': Timestamp.fromDate(DateTime(2026, 5, 1)),
        'status': JobCandidateStatus.pending.name,
        'suggestedCategory': 'ssc',
        'suggestedApplyUrl': 'https://ssc.nic.in/apply',
        'normalizedKey': 'ssccgl2026recruitment',
      });

      final candidate = JobAlertCandidate(
        id: 'c1',
        sourceId: 's',
        rawTitle: 'SSC CGL 2026 Recruitment',
        rawLink: 'https://aggregator.test/ssc-cgl',
        normalizedKey: 'ssccgl2026recruitment',
        fetchedAt: DateTime(2026, 5, 1),
        status: JobCandidateStatus.pending,
        suggestedCategory: 'ssc',
        suggestedApplyUrl: 'https://ssc.nic.in/apply',
      );

      final result = await repository.publishCandidatesBulk(
        candidates: [candidate],
        adminId: 'admin-1',
      );

      final published = result.getOrElse(() => throw 'expected Right');
      expect(published, hasLength(1));
      final links = published.first.importantLinks;
      expect(links, hasLength(2));
      expect(links.first.label, equals('Apply on Official Site'));
      expect(links.first.url, equals('https://ssc.nic.in/apply'));
      expect(links.last.label, equals('Source (admin reference)'));
      expect(links.last.url, equals('https://aggregator.test/ssc-cgl'));
    });

    test('should_omit_apply_link_when_suggestion_absent', () async {
      await firestore.collection('jobAlertCandidates').doc('c1').set({
        'sourceId': 's',
        'rawTitle': 'SSC CGL 2026 Recruitment',
        'rawLink': 'https://aggregator.test/ssc-cgl',
        'fetchedAt': Timestamp.fromDate(DateTime(2026, 5, 1)),
        'status': JobCandidateStatus.pending.name,
        'suggestedCategory': 'ssc',
        'normalizedKey': 'ssccgl2026recruitment',
      });

      final candidate = JobAlertCandidate(
        id: 'c1',
        sourceId: 's',
        rawTitle: 'SSC CGL 2026 Recruitment',
        rawLink: 'https://aggregator.test/ssc-cgl',
        normalizedKey: 'ssccgl2026recruitment',
        fetchedAt: DateTime(2026, 5, 1),
        status: JobCandidateStatus.pending,
        suggestedCategory: 'ssc',
      );

      final result = await repository.publishCandidatesBulk(
        candidates: [candidate],
        adminId: 'admin-1',
      );

      final published = result.getOrElse(() => throw 'expected Right');
      final links = published.first.importantLinks;
      expect(links, hasLength(1));
      expect(links.single.label, equals('Source (admin reference)'));
    });

    test('should_publish_all_candidates_and_mark_them_published', () async {
      final now = DateTime(2026, 5, 1);
      await firestore.collection('jobAlertCandidates').doc('c1').set({
        'sourceId': 's',
        'rawTitle': 'SSC CGL 2026 Recruitment',
        'rawLink': 'https://aggregator.test/ssc-cgl',
        'rawDescription': 'desc',
        'fetchedAt': Timestamp.fromDate(now),
        'status': JobCandidateStatus.pending.name,
        'suggestedCategory': 'ssc',
        'normalizedKey': 'ssccgl2026recruitment',
      });
      await firestore.collection('jobAlertCandidates').doc('c2').set({
        'sourceId': 's',
        'rawTitle': 'RBI Assistant 2026 Notification',
        'rawLink': 'https://aggregator.test/rbi',
        'fetchedAt': Timestamp.fromDate(now),
        'status': JobCandidateStatus.pending.name,
        'suggestedCategory': 'banking',
        'normalizedKey': 'rbiassistant2026notification',
      });

      final candidates = [
        JobAlertCandidate(
          id: 'c1',
          sourceId: 's',
          rawTitle: 'SSC CGL 2026 Recruitment',
          rawLink: 'https://aggregator.test/ssc-cgl',
          normalizedKey: 'ssccgl2026recruitment',
          fetchedAt: now,
          status: JobCandidateStatus.pending,
          suggestedCategory: 'ssc',
        ),
        JobAlertCandidate(
          id: 'c2',
          sourceId: 's',
          rawTitle: 'RBI Assistant 2026 Notification',
          rawLink: 'https://aggregator.test/rbi',
          normalizedKey: 'rbiassistant2026notification',
          fetchedAt: now,
          status: JobCandidateStatus.pending,
          suggestedCategory: 'banking',
        ),
      ];

      final result = await repository.publishCandidatesBulk(
        candidates: candidates,
        adminId: 'admin-1',
      );

      expect(result.isRight(), true);
      final published = result.getOrElse(() => throw 'expected Right');
      expect(published, hasLength(2));
      expect(published.first.category, JobCategory.ssc);
      expect(published[1].category, JobCategory.banking);

      // Every originating candidate is marked published.
      for (final id in ['c1', 'c2']) {
        final doc =
            await firestore.collection('jobAlertCandidates').doc(id).get();
        expect(doc.data()?['status'], JobCandidateStatus.published.name);
      }
    });

    test('should_noop_when_candidates_list_empty', () async {
      final result = await repository.publishCandidatesBulk(
        candidates: const [],
        adminId: 'admin-1',
      );
      expect(result.isRight(), true);
      final published = result.getOrElse(() => throw 'expected Right');
      expect(published, isEmpty);
    });

    test('should_hydrate_published_jobs_from_extractedFields', () async {
      const candidateId = 'rich-candidate';
      // Local DateTime: FakeFirebaseFirestore stores naive timestamps,
      // so a UTC value would drift by the local TZ offset on read.
      final now = DateTime(2026, 5, 1);
      final extracted = ExtractedJobFields(
        title: 'Union Bank Apprentice 2026',
        shortInfo: 'Recruitment for 1865 apprentice posts',
        vacancies: 1865,
        applicationStartDate: DateTime(2026, 4, 28),
        applicationEndDate: DateTime(2026, 5, 18),
        ageMin: 20,
        ageMax: 28,
        fees: const {
          'General / OBC / EWS': 850,
          'SC / ST / PH': 600,
        },
        links: const [
          ExtractedLink(
            label: 'Apply Online',
            url: 'https://apply.union.test',
            kind: 'apply',
          ),
          ExtractedLink(
            label: 'Notification',
            url: 'https://union.test/notif.pdf',
            kind: 'notification',
          ),
        ],
      );

      // Seed the candidate doc — repo deletes it after publishing.
      await firestore
          .collection('jobAlertCandidates')
          .doc(candidateId)
          .set({
        'sourceId': 'sarkari_result_scraper',
        'rawTitle': 'Union Bank Apprentice 2026',
        'rawLink': 'https://sarkari.test/union-bank',
        'fetchedAt': Timestamp.fromDate(now),
        'status': JobCandidateStatus.pending.name,
        'normalizedKey': 'unionbankapprentice2026',
      });

      final candidate = JobAlertCandidate(
        id: candidateId,
        sourceId: 'sarkari_result_scraper',
        rawTitle: 'Union Bank Apprentice 2026',
        rawLink: 'https://sarkari.test/union-bank',
        normalizedKey: 'unionbankapprentice2026',
        fetchedAt: now,
        status: JobCandidateStatus.pending,
        suggestedCategory: 'banking',
        suggestedApplyUrl: 'https://apply.union.test',
        extractedFields: extracted,
      );

      final result = await repository.publishCandidatesBulk(
        candidates: [candidate],
        adminId: 'admin-1',
      );

      final job = result
          .getOrElse(() => throw 'expected Right')
          .single;

      expect(job.vacancies, 1865);
      expect(job.applicationStartDate, DateTime(2026, 4, 28));
      expect(job.applicationEndDate, DateTime(2026, 5, 18));
      expect(job.ageLimit, '20–28 years');
      // Fees are stored in paise on the published job.
      expect(job.applicationFeeGeneralPaise, 85000);
      expect(job.applicationFeeReservedPaise, 60000);
      expect(job.summary, contains('1865 apprentice'));

      // Apply URL is the FIRST link, with the official label, and the
      // aggregator URL is preserved last for admin traceability.
      expect(job.importantLinks, isNotEmpty);
      expect(
        job.importantLinks.first.label,
        equals('Apply on Official Site'),
      );
      expect(
        job.importantLinks.first.url,
        equals('https://apply.union.test'),
      );
      expect(
        job.importantLinks.last.label,
        equals('Source (admin reference)'),
      );
      expect(
        job.importantLinks.map((l) => l.label),
        contains('Notification PDF'),
      );
    });
  });

  group('JobAlertsRepositoryImpl.toggleBookmark', () {
    test('should_create_saved_item_and_increment_counter', () async {
      await _seedJob(firestore, 'job1',
          category: 'ssc', postedAt: DateTime(2025, 1, 1));

      final result = await repository.toggleBookmark(
        jobId: 'job1',
        userId: 'u1',
        bookmark: true,
      );

      expect(result.isRight(), true);
      final saved = await firestore
          .collection('userSavedJobs')
          .doc('u1')
          .collection('items')
          .doc('job1')
          .get();
      expect(saved.exists, true);

      final jobDoc =
          await firestore.collection('jobAlerts').doc('job1').get();
      expect(jobDoc.data()?['bookmarkCount'], 1);
    });

    test(
      'should_remove_saved_item_and_decrement_counter_when_unbookmark',
      () async {
        await _seedJob(firestore, 'job1',
            category: 'ssc', postedAt: DateTime(2025, 1, 1));
        await repository.toggleBookmark(
          jobId: 'job1',
          userId: 'u1',
          bookmark: true,
        );

        final result = await repository.toggleBookmark(
          jobId: 'job1',
          userId: 'u1',
          bookmark: false,
        );

        expect(result.isRight(), true);
        final saved = await firestore
            .collection('userSavedJobs')
            .doc('u1')
            .collection('items')
            .doc('job1')
            .get();
        expect(saved.exists, false);

        final jobDoc =
            await firestore.collection('jobAlerts').doc('job1').get();
        expect(jobDoc.data()?['bookmarkCount'], 0);
      },
    );
  });

  group('JobAlertsRepositoryImpl.getSavedJobs', () {
    test('should_return_jobs_in_savedAt_desc_order', () async {
      await _seedJob(firestore, 'j1',
          category: 'ssc', postedAt: DateTime(2025, 1, 1));
      await _seedJob(firestore, 'j2',
          category: 'ssc', postedAt: DateTime(2025, 1, 2));

      await firestore
          .collection('userSavedJobs')
          .doc('u1')
          .collection('items')
          .doc('j1')
          .set({'savedAt': Timestamp.fromDate(DateTime(2025, 6, 1))});
      await firestore
          .collection('userSavedJobs')
          .doc('u1')
          .collection('items')
          .doc('j2')
          .set({'savedAt': Timestamp.fromDate(DateTime(2025, 6, 2))});

      final result = await repository.getSavedJobs('u1');

      result.fold(
        (_) => fail('unexpected failure'),
        (jobs) {
          expect(jobs.map((j) => j.id).toList(), ['j2', 'j1']);
        },
      );
    });

    test('should_return_empty_when_no_bookmarks', () async {
      final result = await repository.getSavedJobs('u_empty');

      result.fold(
        (_) => fail('unexpected failure'),
        (jobs) => expect(jobs, isEmpty),
      );
    });
  });

  group('JobAlertsRepositoryImpl.getUserPreferences', () {
    test('should_return_default_preferences_when_no_doc', () async {
      final result = await repository.getUserPreferences('u_new');

      result.fold(
        (_) => fail('unexpected failure'),
        (prefs) {
          expect(prefs.userId, 'u_new');
          expect(prefs.categories, isEmpty);
          expect(prefs.pushEnabled, true);
        },
      );
    });

    test('should_return_persisted_preferences', () async {
      await firestore.collection('userJobPreferences').doc('u1').set({
        'userId': 'u1',
        'categories': ['ssc', 'banking'],
        'states': ['UP'],
        'frequency': 'instant',
        'pushEnabled': false,
        'updatedAt': Timestamp.fromDate(DateTime(2025, 1, 1)),
      });

      final result = await repository.getUserPreferences('u1');

      result.fold(
        (_) => fail('unexpected failure'),
        (prefs) {
          expect(prefs.pushEnabled, false);
          expect(prefs.categories,
              containsAll(<JobCategory>[JobCategory.ssc, JobCategory.banking]));
          expect(prefs.states, {'UP'});
        },
      );
    });
  });

  group('JobAlertsRepositoryImpl.recordApplyClick', () {
    test(
      'should_write_click_doc_and_increment_applyClickCount',
      () async {
        await _seedJob(firestore, 'job1',
            category: 'ssc', postedAt: DateTime(2025, 1, 1));

        final result = await repository.recordApplyClick(
          jobId: 'job1',
          userId: 'u1',
          linkIndex: 0,
          destinationUrl: 'https://apply.ssc.nic.in',
          partnerSource: null,
        );

        expect(result.isRight(), true);
        final clicks = await firestore
            .collection('jobApplyClicks')
            .where('jobId', isEqualTo: 'job1')
            .get();
        expect(clicks.docs.length, 1);

        final jobDoc =
            await firestore.collection('jobAlerts').doc('job1').get();
        expect(jobDoc.data()?['applyClickCount'], 1);
      },
    );
  });

  group('JobAlertsRepositoryImpl.getJobAlertAnalytics', () {
    test('should_aggregate_clicks_by_link_index_and_unique_users', () async {
      await _seedJob(firestore, 'job1',
          category: 'ssc', postedAt: DateTime(2025, 1, 1));
      await firestore.collection('jobAlerts').doc('job1').update({
        'viewCount': 100,
        'applyClickCount': 3,
        'bookmarkCount': 7,
      });

      for (final entry in const [
        {'userId': 'u1', 'linkIndex': 0},
        {'userId': 'u2', 'linkIndex': 0},
        {'userId': 'u1', 'linkIndex': 1},
      ]) {
        await firestore.collection('jobApplyClicks').add({
          'jobId': 'job1',
          'userId': entry['userId'],
          'linkIndex': entry['linkIndex'],
          'destinationUrl': 'https://x',
          'clickedAt': Timestamp.fromDate(DateTime(2025, 1, 1)),
        });
      }

      final result = await repository.getJobAlertAnalytics('job1');

      result.fold(
        (_) => fail('unexpected failure'),
        (a) {
          expect(a.jobId, 'job1');
          expect(a.viewCount, 100);
          expect(a.applyClickCount, 3);
          expect(a.bookmarkCount, 7);
          expect(a.uniqueClickers, 2);
          expect(a.clicksByLinkIndex[0], 2);
          expect(a.clicksByLinkIndex[1], 1);
        },
      );
    });

    test('should_return_DocumentNotFoundFailure_when_job_missing', () async {
      final result = await repository.getJobAlertAnalytics('missing');

      expect(result.isLeft(), true);
    });
  });
}
