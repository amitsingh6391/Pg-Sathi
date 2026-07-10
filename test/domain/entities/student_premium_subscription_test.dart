import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/student_premium_subscription.dart';

StudentPremiumSubscription _make({
  bool isActive = true,
  DateTime? validTill,
}) {
  final now = DateTime.now();
  return StudentPremiumSubscription(
    id: 'sub-1',
    userId: 'user-1',
    plan: StudentPremiumPlan.monthly,
    amountPaise: StudentPremiumPlan.monthly.priceInPaise,
    startedAt: now,
    validTill: validTill ?? now.add(const Duration(days: 30)),
    isActive: isActive,
    createdAt: now,
  );
}

void main() {
  group('StudentPremiumSubscription.isCurrentlyActive', () {
    test('should_be_true_when_active_and_within_validity', () {
      final sub = _make(
        validTill: DateTime.now().add(const Duration(days: 5)),
      );
      expect(sub.isCurrentlyActive, isTrue);
    });

    test('should_be_false_when_flag_is_off_even_if_window_open', () {
      final sub = _make(
        isActive: false,
        validTill: DateTime.now().add(const Duration(days: 5)),
      );
      expect(sub.isCurrentlyActive, isFalse);
    });

    test('should_be_false_when_validity_has_expired', () {
      final sub = _make(
        validTill: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(sub.isCurrentlyActive, isFalse);
    });
  });

  group('StudentPremiumPlan pricing', () {
    test('should_expose_rupee_equivalent_from_paise', () {
      expect(StudentPremiumPlan.monthly.priceInRupees, equals(49));
      expect(StudentPremiumPlan.quarterly.priceInRupees, equals(129));
      expect(StudentPremiumPlan.yearly.priceInRupees, equals(399));
    });
  });
}
