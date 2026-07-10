import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/job_alert.dart';

JobAlert _make({
  DateTime? endDate,
  JobStatus status = JobStatus.openForApplication,
}) {
  final now = DateTime(2026, 5, 1, 12);
  return JobAlert(
    id: 'job-1',
    title: 'SSC CGL 2026 Notification',
    organization: 'SSC',
    category: JobCategory.ssc,
    status: status,
    postedAt: now.subtract(const Duration(days: 1)),
    updatedAt: now,
    isActive: true,
    applicationEndDate: endDate,
  );
}

void main() {
  group('JobAlert.isApplyOpen', () {
    test('should_return_true_when_status_is_open_and_endDate_in_future', () {
      final job = _make(
        endDate: DateTime.now().add(const Duration(days: 5)),
      );
      expect(job.isApplyOpen, isTrue);
    });

    test('should_return_false_when_endDate_has_passed', () {
      final job = _make(
        endDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(job.isApplyOpen, isFalse);
    });

    test('should_return_false_when_status_is_closed', () {
      final job = _make(
        endDate: DateTime.now().add(const Duration(days: 5)),
        status: JobStatus.closed,
      );
      expect(job.isApplyOpen, isFalse);
    });

    test('should_return_true_when_endDate_is_null_and_open', () {
      final job = _make(endDate: null);
      expect(job.isApplyOpen, isTrue);
    });
  });

  group('JobAlert.isEndingSoon', () {
    test('should_return_true_when_within_72_hours_of_endDate', () {
      final job = _make(
        endDate: DateTime.now().add(const Duration(hours: 48)),
      );
      expect(job.isEndingSoon, isTrue);
    });

    test('should_return_false_when_endDate_is_more_than_72_hours_away', () {
      final job = _make(
        endDate: DateTime.now().add(const Duration(days: 10)),
      );
      expect(job.isEndingSoon, isFalse);
    });

    test('should_return_false_when_already_closed', () {
      final job = _make(
        endDate: DateTime.now().subtract(const Duration(hours: 1)),
      );
      expect(job.isEndingSoon, isFalse);
    });
  });

  group('JobAlert.daysRemainingToApply', () {
    test('should_return_null_when_endDate_is_null', () {
      expect(_make(endDate: null).daysRemainingToApply, isNull);
    });

    test('should_return_positive_days_for_future_endDate', () {
      final job = _make(
        endDate: DateTime.now().add(const Duration(days: 7, hours: 1)),
      );
      expect(job.daysRemainingToApply, inInclusiveRange(6, 7));
    });

    test('should_return_negative_days_for_past_endDate', () {
      final job = _make(
        endDate: DateTime.now().subtract(const Duration(days: 3)),
      );
      expect(job.daysRemainingToApply, lessThan(0));
    });
  });

  group('JobAlert.copyWith', () {
    test('should_preserve_identity_when_no_changes_requested', () {
      final job = _make(endDate: DateTime(2026, 12, 31));
      final copy = job.copyWith();
      expect(copy, equals(job));
    });

    test('should_override_only_requested_fields', () {
      final job = _make();
      final copy = job.copyWith(title: 'Updated');
      expect(copy.title, equals('Updated'));
      expect(copy.organization, equals(job.organization));
      expect(copy.category, equals(job.category));
    });
  });
}
