import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/membership.dart';

Membership _membership({
  MembershipPlan plan = MembershipPlan.monthly,
  int? customDurationDays,
  int? customDurationMonths,
  MembershipStatus status = MembershipStatus.active,
}) {
  return Membership(
    id: 'm1',
    libraryId: 'lib1',
    plan: plan,
    startDate: DateTime(2025, 1, 1),
    endDate: DateTime(2025, 2, 1),
    status: status,
    phoneNumber: '+911234567890',
    customDurationDays: customDurationDays,
    customDurationMonths: customDurationMonths,
  );
}

void main() {
  group('Membership plan display', () {
    test('planDisplayLabel uses plan when no custom duration', () {
      expect(_membership(plan: MembershipPlan.monthly).planDisplayLabel, 'Monthly');
      expect(_membership(plan: MembershipPlan.yearly).planDisplayLabel, 'Yearly');
    });

    test('planDisplayLabel shows custom days', () {
      expect(
        _membership(customDurationDays: 20).planDisplayLabel,
        '20 days (custom)',
      );
      expect(
        _membership(customDurationDays: 1).planDisplayLabel,
        '1 day (custom)',
      );
    });

    test('planDisplayLabel shows custom months when set', () {
      expect(
        _membership(customDurationMonths: 4).planDisplayLabel,
        '4 months (custom)',
      );
      expect(
        _membership(customDurationMonths: 1).planDisplayLabel,
        '1 month (custom)',
      );
    });

    test('custom months take precedence over custom days for label', () {
      expect(
        _membership(customDurationDays: 5, customDurationMonths: 2)
            .planDisplayLabel,
        '2 months (custom)',
      );
    });

    test('hasCustomDuration is false when custom fields null or zero', () {
      expect(_membership().hasCustomDuration, false);
      expect(
        _membership(customDurationDays: 0, customDurationMonths: 0)
            .hasCustomDuration,
        false,
      );
    });

    test('hasCustomDuration is true when days or months positive', () {
      expect(_membership(customDurationDays: 10).hasCustomDuration, true);
      expect(_membership(customDurationMonths: 3).hasCustomDuration, true);
    });
  });

  group('Membership.isEditable', () {
    test('should_be_true_when_status_is_active', () {
      expect(
        _membership(status: MembershipStatus.active).isEditable,
        isTrue,
      );
    });

    test('should_be_true_when_status_is_pendingPayment', () {
      expect(
        _membership(status: MembershipStatus.pendingPayment).isEditable,
        isTrue,
      );
    });

    test('should_be_false_when_status_is_expired', () {
      expect(
        _membership(status: MembershipStatus.expired).isEditable,
        isFalse,
      );
    });

    test('should_be_false_when_status_is_cancelled', () {
      expect(
        _membership(status: MembershipStatus.cancelled).isEditable,
        isFalse,
      );
    });

    test('should_be_false_when_status_is_suspended', () {
      expect(
        _membership(status: MembershipStatus.suspended).isEditable,
        isFalse,
      );
    });
  });
}
