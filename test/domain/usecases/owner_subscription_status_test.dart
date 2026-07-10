import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/usecases/get_owner_subscription.dart';

void main() {
  group('OwnerSubscriptionStatus', () {
    test('hasActivePaidPlan is true only when access is subscriptionActive', () {
      expect(
        const OwnerSubscriptionStatus(
          accessStatus: OwnerAccessStatus.subscriptionActive,
        ).hasActivePaidPlan,
        isTrue,
      );
      expect(
        const OwnerSubscriptionStatus(
          accessStatus: OwnerAccessStatus.trialActive,
        ).hasActivePaidPlan,
        isFalse,
      );
      expect(
        const OwnerSubscriptionStatus(
          accessStatus: OwnerAccessStatus.newOwner,
        ).hasActivePaidPlan,
        isFalse,
      );
      expect(
        const OwnerSubscriptionStatus(
          accessStatus: OwnerAccessStatus.pendingVerification,
        ).hasActivePaidPlan,
        isFalse,
      );
    });

    test('hasAccess includes trial; hasActivePaidPlan does not', () {
      const trial = OwnerSubscriptionStatus(
        accessStatus: OwnerAccessStatus.trialActive,
      );
      expect(trial.hasAccess, isTrue);
      expect(trial.hasActivePaidPlan, isFalse);
    });
  });
}
