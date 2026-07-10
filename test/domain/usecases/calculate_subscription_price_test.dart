import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/subscription_plan.dart';
import 'package:pg_manager/domain/failures/subscription_failures.dart';
import 'package:pg_manager/domain/usecases/calculate_subscription_price.dart';

void main() {
  late CalculateSubscriptionPrice useCase;

  setUp(() {
    useCase = const CalculateSubscriptionPrice();
  });

  group('CalculateSubscriptionPrice', () {
    group('should_return_correct_plan_when_seat_count_is_in_tier', () {
      test('should return tier_149 plan for 1-50 seats', () async {
        // Arrange
        const params = CalculateSubscriptionPriceParams(
          seatCount: 30,
          durationInMonths: 1,
        );

        // Act
        final result = await useCase(params);

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not fail'), (r) {
          expect(r.plan.id, 'tier_149');
          expect(r.plan.monthlyPrice, 149);
          expect(r.baseMonthlyPrice, 149);
        });
      });

      test('should return tier_299 plan for 101-150 seats', () async {
        // Arrange
        const params = CalculateSubscriptionPriceParams(
          seatCount: 120,
          durationInMonths: 1,
        );

        // Act
        final result = await useCase(params);

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not fail'), (r) {
          expect(r.plan.id, 'tier_299');
          expect(r.plan.monthlyPrice, 299);
        });
      });

      test('should return tier_349 plan for 151-200 seats', () async {
        // Arrange
        const params = CalculateSubscriptionPriceParams(
          seatCount: 180,
          durationInMonths: 1,
        );

        // Act
        final result = await useCase(params);

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not fail'), (r) {
          expect(r.plan.id, 'tier_349');
          expect(r.plan.monthlyPrice, 349);
        });
      });

      test('should return tier_499 plan for 301-350 seats', () async {
        // Arrange
        const params = CalculateSubscriptionPriceParams(
          seatCount: 320,
          durationInMonths: 1,
        );

        // Act
        final result = await useCase(params);

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not fail'), (r) {
          expect(r.plan.id, 'tier_499');
          expect(r.plan.monthlyPrice, 499);
        });
      });

      test('should return tier_699 plan for 351+ seats', () async {
        // Arrange
        const params = CalculateSubscriptionPriceParams(
          seatCount: 500,
          durationInMonths: 1,
        );

        // Act
        final result = await useCase(params);

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not fail'), (r) {
          expect(r.plan.id, 'tier_699');
          expect(r.plan.monthlyPrice, 699);
        });
      });
    });

    group('should_apply_correct_duration_discount', () {
      test('should apply 0% discount for 1 month', () async {
        // Arrange
        const params = CalculateSubscriptionPriceParams(
          seatCount: 30,
          durationInMonths: 1,
        );

        // Act
        final result = await useCase(params);

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not fail'), (r) {
          expect(r.discountPercent, 0.0);
          expect(r.discountAmount, 0.0);
          expect(r.grossAmount, 149);
          expect(r.finalAmount, 149);
        });
      });

      test('should apply 0% discount for 3 months', () async {
        // Arrange
        const params = CalculateSubscriptionPriceParams(
          seatCount: 30,
          durationInMonths: 3,
        );

        // Act
        final result = await useCase(params);

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not fail'), (r) {
          expect(r.discountPercent, 0.0);
          expect(r.grossAmount, 149 * 3); // 447
          expect(r.discountAmount, 0.0);
          expect(r.finalAmount, 447); // No discount
        });
      });

      test('should apply 0% discount for 6 months', () async {
        // Arrange
        const params = CalculateSubscriptionPriceParams(
          seatCount: 30,
          durationInMonths: 6,
        );

        // Act
        final result = await useCase(params);

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not fail'), (r) {
          expect(r.discountPercent, 0.0);
          expect(r.grossAmount, 149 * 6); // 894
          expect(r.discountAmount, 0.0);
          expect(r.finalAmount, 894); // No discount
        });
      });

      test('should apply 5% discount for 12 months', () async {
        // Arrange
        const params = CalculateSubscriptionPriceParams(
          seatCount: 30,
          durationInMonths: 12,
        );

        // Act
        final result = await useCase(params);

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not fail'), (r) {
          expect(r.discountPercent, 5.0);
          expect(r.grossAmount, 149 * 12); // 1788
          expect(r.discountAmount, 1788 * 0.05); // 89.4
          expect(r.finalAmount, 1788 - 89.4); // 1698.6
        });
      });
    });

    group('should_fail_when_invalid_parameters', () {
      test('should fail for invalid seat count (0)', () async {
        // Arrange
        const params = CalculateSubscriptionPriceParams(
          seatCount: 0,
          durationInMonths: 1,
        );

        // Act
        final result = await useCase(params);

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (l) => expect(l, isA<InvalidSeatCountFailure>()),
          (r) => fail('Should fail'),
        );
      });

      test('should fail for invalid seat count (negative)', () async {
        // Arrange
        const params = CalculateSubscriptionPriceParams(
          seatCount: -5,
          durationInMonths: 1,
        );

        // Act
        final result = await useCase(params);

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (l) => expect(l, isA<InvalidSeatCountFailure>()),
          (r) => fail('Should fail'),
        );
      });

      test('should fail for invalid duration', () async {
        // Arrange
        const params = CalculateSubscriptionPriceParams(
          seatCount: 30,
          durationInMonths: 5, // Not a valid duration
        );

        // Act
        final result = await useCase(params);

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (l) => expect(l, isA<InvalidDurationFailure>()),
          (r) => fail('Should fail'),
        );
      });
    });

    group('should_calculate_correctly_for_edge_cases', () {
      test('should handle boundary seat count 1', () async {
        // Arrange
        const params = CalculateSubscriptionPriceParams(
          seatCount: 1,
          durationInMonths: 1,
        );

        // Act
        final result = await useCase(params);

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not fail'), (r) {
          expect(r.plan.id, 'tier_149');
          expect(r.plan.monthlyPrice, 149);
        });
      });

      test('should handle boundary seat count 49', () async {
        // Arrange
        const params = CalculateSubscriptionPriceParams(
          seatCount: 49,
          durationInMonths: 1,
        );

        // Act
        final result = await useCase(params);

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not fail'), (r) {
          expect(r.plan.id, 'tier_149');
          expect(r.plan.monthlyPrice, 149);
        });
      });

      test('should handle boundary seat count 50', () async {
        // Arrange
        const params = CalculateSubscriptionPriceParams(
          seatCount: 50,
          durationInMonths: 1,
        );

        // Act
        final result = await useCase(params);

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not fail'), (r) {
          expect(r.plan.id, 'tier_249');
          expect(r.plan.monthlyPrice, 249);
        });
      });

      test('should handle boundary seat count 99', () async {
        // Arrange
        const params = CalculateSubscriptionPriceParams(
          seatCount: 99,
          durationInMonths: 1,
        );

        // Act
        final result = await useCase(params);

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not fail'), (r) {
          expect(r.plan.id, 'tier_249');
          expect(r.plan.monthlyPrice, 249);
        });
      });

      test('should handle boundary seat count 149', () async {
        // Arrange
        const params = CalculateSubscriptionPriceParams(
          seatCount: 149,
          durationInMonths: 1,
        );

        // Act
        final result = await useCase(params);

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not fail'), (r) {
          expect(r.plan.id, 'tier_299');
          expect(r.plan.monthlyPrice, 299);
        });
      });

      test('should handle boundary seat count 199', () async {
        // Arrange
        const params = CalculateSubscriptionPriceParams(
          seatCount: 199,
          durationInMonths: 1,
        );

        // Act
        final result = await useCase(params);

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not fail'), (r) {
          expect(r.plan.id, 'tier_349');
          expect(r.plan.monthlyPrice, 349);
        });
      });

      test('should handle boundary seat count 299', () async {
        // Arrange
        const params = CalculateSubscriptionPriceParams(
          seatCount: 299,
          durationInMonths: 1,
        );

        // Act
        final result = await useCase(params);

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not fail'), (r) {
          expect(r.plan.id, 'tier_449');
          expect(r.plan.monthlyPrice, 449);
        });
      });

      test('should handle boundary seat count 349', () async {
        // Arrange
        const params = CalculateSubscriptionPriceParams(
          seatCount: 349,
          durationInMonths: 1,
        );

        // Act
        final result = await useCase(params);

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not fail'), (r) {
          expect(r.plan.id, 'tier_499');
          expect(r.plan.monthlyPrice, 499);
        });
      });

      test('should handle boundary seat count 350', () async {
        // Arrange
        const params = CalculateSubscriptionPriceParams(
          seatCount: 350,
          durationInMonths: 1,
        );

        // Act
        final result = await useCase(params);

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not fail'), (r) {
          expect(r.plan.id, 'tier_699');
          expect(r.plan.monthlyPrice, 699);
        });
      });

      test('should handle very large seat count', () async {
        // Arrange
        const params = CalculateSubscriptionPriceParams(
          seatCount: 10000,
          durationInMonths: 12,
        );

        // Act
        final result = await useCase(params);

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not fail'), (r) {
          expect(r.plan.id, 'tier_699');
          expect(r.plan.monthlyPrice, 699);
          expect(r.grossAmount, 699 * 12);
          expect(r.discountPercent, 5.0);
        });
      });
    });
  });

  group('SubscriptionPlan', () {
    test('should return correct discount for all durations', () {
      expect(SubscriptionPlan.getDiscountForDuration(1), 0.0);
      expect(SubscriptionPlan.getDiscountForDuration(3), 0.0);
      expect(SubscriptionPlan.getDiscountForDuration(6), 0.0);
      expect(SubscriptionPlan.getDiscountForDuration(12), 5.0);
    });

    test('should return 0 for invalid duration', () {
      expect(SubscriptionPlan.getDiscountForDuration(2), 0.0);
      expect(SubscriptionPlan.getDiscountForDuration(5), 0.0);
      expect(SubscriptionPlan.getDiscountForDuration(24), 0.0);
    });

    test('should have correct pricing tiers', () {
      expect(SubscriptionPlan.pricingTiers.length, 8);

      // Verify tier boundaries
      expect(SubscriptionPlan.pricingTiers[0].minSeats, 1);
      expect(SubscriptionPlan.pricingTiers[0].maxSeats, 49);
      expect(SubscriptionPlan.pricingTiers[0].monthlyPrice, 149);

      expect(SubscriptionPlan.pricingTiers[7].minSeats, 350);
      expect(SubscriptionPlan.pricingTiers[7].maxSeats, -1); // Unlimited
      expect(SubscriptionPlan.pricingTiers[7].monthlyPrice, 699);
    });

    test('getPlanForSeats should return correct plan', () {
      expect(SubscriptionPlan.getPlanForSeats(1).id, 'tier_149');
      expect(SubscriptionPlan.getPlanForSeats(25).id, 'tier_149');
      expect(SubscriptionPlan.getPlanForSeats(49).id, 'tier_149');
      expect(SubscriptionPlan.getPlanForSeats(50).id, 'tier_249');
      expect(SubscriptionPlan.getPlanForSeats(75).id, 'tier_249');
      expect(SubscriptionPlan.getPlanForSeats(99).id, 'tier_249');
      expect(SubscriptionPlan.getPlanForSeats(100).id, 'tier_299');
      expect(SubscriptionPlan.getPlanForSeats(125).id, 'tier_299');
      expect(SubscriptionPlan.getPlanForSeats(149).id, 'tier_299');
      expect(SubscriptionPlan.getPlanForSeats(150).id, 'tier_349');
      expect(SubscriptionPlan.getPlanForSeats(175).id, 'tier_349');
      expect(SubscriptionPlan.getPlanForSeats(199).id, 'tier_349');
      expect(SubscriptionPlan.getPlanForSeats(200).id, 'tier_399');
      expect(SubscriptionPlan.getPlanForSeats(225).id, 'tier_399');
      expect(SubscriptionPlan.getPlanForSeats(249).id, 'tier_399');
      expect(SubscriptionPlan.getPlanForSeats(250).id, 'tier_449');
      expect(SubscriptionPlan.getPlanForSeats(275).id, 'tier_449');
      expect(SubscriptionPlan.getPlanForSeats(299).id, 'tier_449');
      expect(SubscriptionPlan.getPlanForSeats(300).id, 'tier_499');
      expect(SubscriptionPlan.getPlanForSeats(325).id, 'tier_499');
      expect(SubscriptionPlan.getPlanForSeats(349).id, 'tier_499');
      expect(SubscriptionPlan.getPlanForSeats(350).id, 'tier_699');
      expect(SubscriptionPlan.getPlanForSeats(1000).id, 'tier_699');
    });

    test('should have 3 days trial period', () {
      expect(SubscriptionPlan.trialDays, 3);
    });
  });
}
