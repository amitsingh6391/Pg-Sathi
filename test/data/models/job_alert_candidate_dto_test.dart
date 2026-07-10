import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/data/models/job_alert_candidate_dto.dart';
import 'package:pg_manager/domain/entities/extracted_job_fields.dart';
import 'package:pg_manager/domain/entities/job_alert.dart';
import 'package:pg_manager/domain/entities/job_alert_candidate.dart';

void main() {
  group('JobAlertCandidateModel.suggestedApplyUrl', () {
    late FakeFirebaseFirestore firestore;

    setUp(() => firestore = FakeFirebaseFirestore());

    test('should_preserve_suggestedApplyUrl_through_firestore_roundtrip',
        () async {
      final ref = firestore.collection('jobAlertCandidates').doc('c1');
      final entity = JobAlertCandidate(
        id: 'c1',
        sourceId: 'src-1',
        rawTitle: 'SSC CGL 2026 Recruitment',
        rawLink: 'https://aggregator.test/ssc-cgl',
        rawDescription: 'Apply at ssc.nic.in',
        fetchedAt: DateTime.utc(2026, 5, 1, 10, 30),
        status: JobCandidateStatus.pending,
        suggestedCategory: 'ssc',
        suggestedApplyUrl: 'https://ssc.nic.in/apply',
        normalizedKey: 'ssccgl2026recruitment',
      );

      await ref
          .set(JobAlertCandidateModel.fromEntity(entity).toFirestore());
      final snap = await ref.get();
      final restored =
          JobAlertCandidateModel.fromFirestore(snap).toEntity();

      expect(restored.suggestedApplyUrl, equals('https://ssc.nic.in/apply'));
      expect(restored.rawTitle, equals(entity.rawTitle));
      expect(restored.suggestedCategory, equals('ssc'));
    });

    test('should_allow_null_suggestedApplyUrl', () async {
      final ref = firestore.collection('jobAlertCandidates').doc('c2');
      await ref.set({
        'sourceId': 'src-1',
        'rawTitle': 'Some job',
        'rawLink': 'https://aggregator.test/x',
        'fetchedAt': null,
        'status': 'pending',
        'normalizedKey': 'somejob',
      });

      final restored = JobAlertCandidateModel.fromFirestore(
        await ref.get(),
      ).toEntity();

      expect(restored.suggestedApplyUrl, isNull);
    });
  });

  group('JobAlertCandidateModel.extractedFields', () {
    late FakeFirebaseFirestore firestore;

    setUp(() => firestore = FakeFirebaseFirestore());

    test('should_roundtrip_full_extracted_payload', () async {
      final ref = firestore.collection('jobAlertCandidates').doc('rich');
      // Use local DateTime to avoid UTC↔local roundtrip drift through
      // FakeFirebaseFirestore (which stores naive timestamps).
      final extracted = ExtractedJobFields(
        title: 'Union Bank Apprentice 2026',
        postDate: '01 May 2026',
        shortInfo: 'Recruitment for 1865 apprentice posts',
        vacancies: 1865,
        applicationStartDate: DateTime(2026, 4, 28),
        applicationEndDate: DateTime(2026, 5, 18),
        feeLastDate: DateTime(2026, 5, 18),
        examDateText: 'June 2026',
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
      final entity = JobAlertCandidate(
        id: 'rich',
        sourceId: 'sarkari_result_scraper',
        rawTitle: 'Union Bank Apprentice 2026',
        rawLink: 'https://sarkari.test/union-bank',
        fetchedAt: DateTime(2026, 5, 1, 10, 30),
        status: JobCandidateStatus.pending,
        normalizedKey: 'unionbankapprentice2026',
        extractedFields: extracted,
      );

      await ref
          .set(JobAlertCandidateModel.fromEntity(entity).toFirestore());
      final restored = JobAlertCandidateModel.fromFirestore(
        await ref.get(),
      ).toEntity();

      final out = restored.extractedFields!;
      expect(out.vacancies, 1865);
      expect(out.ageMin, 20);
      expect(out.ageMax, 28);
      expect(out.applicationEndDate, DateTime(2026, 5, 18));
      expect(out.fees['General / OBC / EWS'], 850);
      expect(out.fees['SC / ST / PH'], 600);
      expect(out.links, hasLength(2));
      expect(out.links.first.kind, equals('apply'));
      expect(out.links.first.url, equals('https://apply.union.test'));
    });

    test('should_return_null_extractedFields_when_field_missing_in_doc',
        () async {
      final ref = firestore.collection('jobAlertCandidates').doc('legacy');
      await ref.set({
        'sourceId': 'rss-legacy',
        'rawTitle': 'Legacy candidate',
        'rawLink': 'https://x.test/y',
        'fetchedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'status': 'pending',
        'normalizedKey': 'legacycandidate',
      });
      final restored = JobAlertCandidateModel.fromFirestore(
        await ref.get(),
      ).toEntity();
      expect(restored.extractedFields, isNull);
    });

    test('should_tolerate_partial_extracted_fields_payload', () async {
      final ref = firestore.collection('jobAlertCandidates').doc('partial');
      await ref.set({
        'sourceId': 'sarkari_result_scraper',
        'rawTitle': 'Partial scrape',
        'rawLink': 'https://x.test/y',
        'fetchedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'status': 'pending',
        'normalizedKey': 'partialscrape',
        'extractedFields': {
          'title': 'Partial scrape',
          'vacancies': 50,
          'fees': {},
          'links': [],
        },
      });
      final restored = JobAlertCandidateModel.fromFirestore(
        await ref.get(),
      ).toEntity();
      expect(restored.extractedFields, isNotNull);
      expect(restored.extractedFields!.vacancies, 50);
      expect(restored.extractedFields!.applicationEndDate, isNull);
      expect(restored.extractedFields!.fees, isEmpty);
      expect(restored.extractedFields!.links, isEmpty);
    });

    test('should_default_legacy_doc_without_type_to_recruitment',
        () async {
      final ref = firestore.collection('jobAlertCandidates').doc('legacy_t');
      await ref.set({
        'sourceId': 'rss-legacy',
        'rawTitle': 'Pre-migration candidate',
        'rawLink': '',
        'fetchedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'status': 'pending',
        'normalizedKey': 'pre',
      });
      final restored = JobAlertCandidateModel.fromFirestore(
        await ref.get(),
      ).toEntity();
      expect(restored.type, JobAlertType.recruitment);
    });

    test('should_roundtrip_type_through_firestore', () async {
      final ref = firestore.collection('jobAlertCandidates').doc('admit_c');
      final entity = JobAlertCandidate(
        id: 'admit_c',
        sourceId: 'sarkari_result_admit_cards',
        rawTitle: 'RRB NTPC Admit Card 2026',
        rawLink: 'https://sarkari.test/admit',
        fetchedAt: DateTime(2026, 5, 1, 10, 30),
        status: JobCandidateStatus.pending,
        type: JobAlertType.admitCard,
        normalizedKey: 'rrbntpcadmit2026',
      );
      await ref
          .set(JobAlertCandidateModel.fromEntity(entity).toFirestore());
      final restored = JobAlertCandidateModel.fromFirestore(
        await ref.get(),
      ).toEntity();
      expect(restored.type, JobAlertType.admitCard);
    });

    test(
        'should_coerce_int_field_from_string_when_legacy_doc_used_string_amount',
        () async {
      final ref = firestore.collection('jobAlertCandidates').doc('coerce');
      await ref.set({
        'sourceId': 'sarkari_result_scraper',
        'rawTitle': 'Coerce',
        'rawLink': '',
        'fetchedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'status': 'pending',
        'normalizedKey': 'coerce',
        'extractedFields': {
          'vacancies': '300',
          'ageMin': '21',
          'fees': {'General': '500'},
        },
      });
      final restored = JobAlertCandidateModel.fromFirestore(
        await ref.get(),
      ).toEntity();
      expect(restored.extractedFields!.vacancies, 300);
      expect(restored.extractedFields!.ageMin, 21);
      expect(restored.extractedFields!.fees['General'], 500);
    });
  });
}
