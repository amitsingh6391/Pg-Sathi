import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/job_alert_candidate.dart';

void main() {
  group('JobAlertCandidate.normalizeTitleForKey', () {
    test('should_return_lowercase_alphanumeric_only', () {
      final key = JobAlertCandidate.normalizeTitleForKey(
        'SSC CGL 2026 - Notification Out!',
      );
      expect(key, equals('ssccgl2026notificationout'));
    });

    test('should_cap_length_at_40_characters', () {
      final input = 'A' * 100;
      final key = JobAlertCandidate.normalizeTitleForKey(input);
      expect(key.length, equals(40));
    });

    test('should_be_identical_for_duplicate_titles_with_different_whitespace', () {
      final a = JobAlertCandidate.normalizeTitleForKey('SSC   CGL  2026');
      final b = JobAlertCandidate.normalizeTitleForKey('ssc-cgl-2026');
      expect(a, equals(b));
    });

    test('should_be_empty_for_whitespace_only_input', () {
      expect(
        JobAlertCandidate.normalizeTitleForKey('     '),
        equals(''),
      );
    });

    test('should_strip_unicode_punctuation', () {
      final key = JobAlertCandidate.normalizeTitleForKey(
        'Railway RRB – NTPC 2026: Exam!',
      );
      expect(key, equals('railwayrrbntpc2026exam'));
    });
  });
}
