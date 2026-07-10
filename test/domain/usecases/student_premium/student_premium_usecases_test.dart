import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/data/failures/data_failures.dart';
import 'package:pg_manager/domain/entities/student_premium_subscription.dart';
import 'package:pg_manager/domain/repositories/student_premium_repository.dart';
import 'package:pg_manager/domain/usecases/student_premium/student_premium_usecases.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements StudentPremiumRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(StudentPremiumPlan.monthly);
  });

  late _MockRepo mockRepo;

  setUp(() => mockRepo = _MockRepo());

  final now = DateTime(2026, 5, 1);
  final testSub = StudentPremiumSubscription(
    id: 'sub-1',
    userId: 'user-1',
    plan: StudentPremiumPlan.monthly,
    amountPaise: 4900,
    startedAt: now,
    validTill: now.add(const Duration(days: 30)),
    isActive: true,
    createdAt: now,
  );

  group('GetActiveStudentPremium', () {
    late GetActiveStudentPremium useCase;
    setUp(() => useCase = GetActiveStudentPremium(mockRepo));

    test('should_return_subscription_when_repo_finds_one', () async {
      when(() => mockRepo.getActiveSubscription('user-1'))
          .thenAnswer((_) async => Right(testSub));

      final result = await useCase('user-1');

      result.fold(
        (_) => fail('expected Right'),
        (sub) => expect(sub, equals(testSub)),
      );
    });

    test('should_return_null_when_user_has_no_subscription', () async {
      when(() => mockRepo.getActiveSubscription('user-1'))
          .thenAnswer((_) async => const Right(null));

      final result = await useCase('user-1');

      result.fold(
        (_) => fail('expected Right'),
        (sub) => expect(sub, isNull),
      );
    });

    test('should_propagate_failure', () async {
      when(() => mockRepo.getActiveSubscription(any())).thenAnswer(
        (_) async => const Left(ServerFailure(message: 'no')),
      );

      final result = await useCase('user-1');
      expect(result.isLeft(), isTrue);
    });
  });

  group('ActivateStudentPremium', () {
    late ActivateStudentPremium useCase;
    setUp(() => useCase = ActivateStudentPremium(mockRepo));

    test('should_forward_plan_pricing_and_payment_metadata', () async {
      when(() => mockRepo.activateSubscription(
            userId: any(named: 'userId'),
            plan: any(named: 'plan'),
            amountPaise: any(named: 'amountPaise'),
            paymentId: any(named: 'paymentId'),
            paymentProvider: any(named: 'paymentProvider'),
          )).thenAnswer((_) async => Right(testSub));

      await useCase(
        userId: 'user-1',
        plan: StudentPremiumPlan.yearly,
        amountPaise: StudentPremiumPlan.yearly.priceInPaise,
        paymentId: 'pay_xyz',
        paymentProvider: 'razorpay',
      );

      verify(() => mockRepo.activateSubscription(
            userId: 'user-1',
            plan: StudentPremiumPlan.yearly,
            amountPaise: StudentPremiumPlan.yearly.priceInPaise,
            paymentId: 'pay_xyz',
            paymentProvider: 'razorpay',
          )).called(1);
    });
  });

  group('CancelStudentPremium', () {
    late CancelStudentPremium useCase;
    setUp(() => useCase = CancelStudentPremium(mockRepo));

    test('should_forward_subscription_id_to_repo', () async {
      when(() => mockRepo.cancelSubscription('sub-1'))
          .thenAnswer((_) async => const Right(null));

      await useCase('sub-1');

      verify(() => mockRepo.cancelSubscription('sub-1')).called(1);
    });
  });
}
