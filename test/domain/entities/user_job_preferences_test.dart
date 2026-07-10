import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/job_alert.dart';
import 'package:pg_manager/domain/entities/user_job_preferences.dart';

void main() {
  group('UserJobPreferences.defaultFor', () {
    test('should_enable_push_with_daily_digest_frequency_by_default', () {
      final prefs = UserJobPreferences.defaultFor('user-1');
      expect(prefs.pushEnabled, isTrue);
      // Default is digest (single 9 AM IST push) — not instant — so a
      // brand-new student doesn't get woken up by every published
      // alert across every category they haven't filtered yet.
      expect(prefs.frequency, equals(JobPushFrequency.digest9am));
      expect(prefs.categories, isEmpty);
      expect(prefs.states, isEmpty);
    });
  });

  group('UserJobPreferences.isSubscribedTo', () {
    test('should_return_true_for_any_category_when_empty_filter', () {
      final prefs = UserJobPreferences.defaultFor('user-1');
      for (final c in JobCategory.values) {
        expect(prefs.isSubscribedTo(c), isTrue);
      }
    });

    test('should_return_true_only_for_selected_categories', () {
      final prefs = UserJobPreferences.defaultFor('user-1').copyWith(
        categories: {JobCategory.ssc, JobCategory.banking},
      );
      expect(prefs.isSubscribedTo(JobCategory.ssc), isTrue);
      expect(prefs.isSubscribedTo(JobCategory.banking), isTrue);
      expect(prefs.isSubscribedTo(JobCategory.upsc), isFalse);
    });

    test('should_return_false_when_push_is_disabled', () {
      final prefs = UserJobPreferences.defaultFor('user-1').copyWith(
        pushEnabled: false,
      );
      expect(prefs.isSubscribedTo(JobCategory.ssc), isFalse);
    });
  });
}
