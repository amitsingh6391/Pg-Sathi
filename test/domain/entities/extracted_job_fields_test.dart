import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/extracted_job_fields.dart';

void main() {
  group('ExtractedJobFields.applyUrl', () {
    test('should_return_apply_link_when_present', () {
      const fields = ExtractedJobFields(links: [
        ExtractedLink(label: 'Apply Online', url: 'https://apply.test', kind: 'apply'),
        ExtractedLink(label: 'Official Website', url: 'https://official.test', kind: 'official'),
      ]);
      expect(fields.applyUrl, equals('https://apply.test'));
    });

    test('should_fall_back_to_official_when_apply_missing', () {
      const fields = ExtractedJobFields(links: [
        ExtractedLink(label: 'Official Website', url: 'https://official.test', kind: 'official'),
      ]);
      expect(fields.applyUrl, equals('https://official.test'));
    });

    test('should_return_null_when_no_apply_or_official_link', () {
      const fields = ExtractedJobFields(links: [
        ExtractedLink(label: 'Notification', url: 'https://x.test/pdf', kind: 'notification'),
      ]);
      expect(fields.applyUrl, isNull);
    });

    test('should_return_null_when_links_empty', () {
      const fields = ExtractedJobFields();
      expect(fields.applyUrl, isNull);
    });
  });

  group('ExtractedJobFields.generalFeeRupees', () {
    test('should_return_general_bucket_when_present', () {
      const fields = ExtractedJobFields(fees: {
        'General / OBC / EWS': 850,
        'SC / ST': 500,
      });
      expect(fields.generalFeeRupees, equals(850));
    });

    test('should_fall_back_to_first_bucket_when_no_general_match', () {
      const fields = ExtractedJobFields(fees: {
        'All Categories': 100,
      });
      expect(fields.generalFeeRupees, equals(100));
    });

    test('should_skip_general_female_bucket_when_choosing_general', () {
      const fields = ExtractedJobFields(fees: {
        'General Female': 50,
        'General Male': 600,
      });
      expect(fields.generalFeeRupees, equals(600));
    });

    test('should_return_null_when_fees_empty', () {
      const fields = ExtractedJobFields();
      expect(fields.generalFeeRupees, isNull);
    });
  });

  group('ExtractedJobFields.reservedFeeRupees', () {
    test('should_match_sc_st_label', () {
      const fields = ExtractedJobFields(fees: {
        'General': 500,
        'SC / ST / PH': 100,
      });
      expect(fields.reservedFeeRupees, equals(100));
    });

    test('should_return_null_when_no_reserved_label', () {
      const fields = ExtractedJobFields(fees: {
        'General': 500,
      });
      expect(fields.reservedFeeRupees, isNull);
    });
  });

  group('ExtractedJobFields.hasMeaningfulData', () {
    test('should_return_true_when_vacancies_present', () {
      expect(
        const ExtractedJobFields(vacancies: 100).hasMeaningfulData,
        isTrue,
      );
    });

    test('should_return_true_when_only_age_present', () {
      expect(
        const ExtractedJobFields(ageMin: 18).hasMeaningfulData,
        isTrue,
      );
    });

    test('should_return_false_when_only_title_present', () {
      expect(
        const ExtractedJobFields(title: 'Some title').hasMeaningfulData,
        isFalse,
      );
    });
  });

  group('ExtractedJobFields.toImportantLinks', () {
    test('should_put_apply_url_first_then_pdfs_then_aggregator', () {
      const fields = ExtractedJobFields(links: [
        ExtractedLink(
          label: 'Notification',
          url: 'https://x.test/notif.pdf',
          kind: 'notification',
        ),
        ExtractedLink(
          label: 'Apply Online',
          url: 'https://apply.test',
          kind: 'apply',
        ),
        ExtractedLink(
          label: 'Syllabus',
          url: 'https://x.test/syl.pdf',
          kind: 'syllabus',
        ),
        ExtractedLink(
          label: 'Official',
          url: 'https://official.test',
          kind: 'official',
        ),
      ]);
      final out = fields.toImportantLinks(
        aggregatorUrl: 'https://agg.test/post',
      );
      expect(out.map((l) => l.label), [
        'Apply on Official Site',
        'Notification PDF',
        'Syllabus PDF',
        'Official Website',
        'Source (admin reference)',
      ]);
      expect(out.first.url, equals('https://apply.test'));
      expect(out.last.url, equals('https://agg.test/post'));
    });

    test('should_skip_official_when_same_as_apply_url', () {
      const fields = ExtractedJobFields(links: [
        ExtractedLink(
          label: 'Apply',
          url: 'https://same.test',
          kind: 'apply',
        ),
        ExtractedLink(
          label: 'Official',
          url: 'https://same.test',
          kind: 'official',
        ),
      ]);
      final out = fields.toImportantLinks(aggregatorUrl: 'https://agg');
      expect(out.where((l) => l.label == 'Official Website'), isEmpty);
    });

    test('should_omit_aggregator_when_url_is_empty', () {
      const fields = ExtractedJobFields(links: [
        ExtractedLink(label: 'Apply', url: 'https://apply.test', kind: 'apply'),
      ]);
      final out = fields.toImportantLinks(aggregatorUrl: '');
      expect(out.where((l) => l.label.contains('Source')), isEmpty);
    });

    test('should_return_only_aggregator_when_no_extracted_links', () {
      const fields = ExtractedJobFields();
      final out = fields.toImportantLinks(aggregatorUrl: 'https://agg.test');
      expect(out, hasLength(1));
      expect(out.first.label, equals('Source (admin reference)'));
    });

    test('should_emit_View_Result_link_for_result_typed_extraction', () {
      // Regression: result candidates were dropping the actual result
      // PDF before the mapper fix — students saw only the aggregator
      // link with no way to view the result.
      const fields = ExtractedJobFields(links: [
        ExtractedLink(
          label: 'Result',
          url: 'https://gov.in/r.pdf',
          kind: 'result',
        ),
        ExtractedLink(
          label: 'Cutoff',
          url: 'https://gov.in/c.pdf',
          kind: 'notification',
        ),
      ]);
      final out =
          fields.toImportantLinks(aggregatorUrl: 'https://agg.test/r');
      expect(out.map((l) => l.label), contains('View Result'));
      expect(
        out.firstWhere((l) => l.label == 'View Result').url,
        'https://gov.in/r.pdf',
      );
    });

    test('should_emit_Download_Admit_Card_link_for_admitCard_extraction', () {
      const fields = ExtractedJobFields(links: [
        ExtractedLink(
          label: 'Admit Card',
          url: 'https://gov.in/ac.pdf',
          kind: 'admitCard',
        ),
      ]);
      final out =
          fields.toImportantLinks(aggregatorUrl: 'https://agg.test/ac');
      expect(out.map((l) => l.label), contains('Download Admit Card'));
      expect(
        out.firstWhere((l) => l.label == 'Download Admit Card').url,
        'https://gov.in/ac.pdf',
      );
    });

    test('should_put_primary_action_links_before_supporting_docs', () {
      // Order matters: the first non-aggregator link is the inline
      // CTA target. Notification/syllabus PDFs must never out-rank
      // the typed primary action.
      const fields = ExtractedJobFields(links: [
        ExtractedLink(
          label: 'Notification',
          url: 'https://x/n.pdf',
          kind: 'notification',
        ),
        ExtractedLink(
          label: 'Result',
          url: 'https://x/r.pdf',
          kind: 'result',
        ),
      ]);
      final labels =
          fields.toImportantLinks(aggregatorUrl: '').map((l) => l.label);
      expect(labels.first, 'View Result');
    });
  });
}
