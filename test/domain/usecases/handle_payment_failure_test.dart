import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/core/services/analytics_service.dart';
import 'package:pg_manager/domain/entities/membership.dart';
import 'package:pg_manager/domain/entities/payment.dart';
import 'package:pg_manager/domain/entities/slot.dart';
import 'package:pg_manager/domain/failures/payment_failures.dart';
import 'package:pg_manager/domain/repositories/membership_repository.dart';
import 'package:pg_manager/domain/repositories/payment_repository.dart';
import 'package:pg_manager/domain/usecases/handle_payment_failure.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'handle_payment_failure_test.mocks.dart';

@GenerateMocks([MembershipRepository, PaymentRepository, AnalyticsService])
void main() {
  late HandlePaymentFailure useCase;
  late MockMembershipRepository mockMembershipRepo;
  late MockPaymentRepository mockPaymentRepo;
  late MockAnalyticsService mockAnalyticsService;

  setUp(() {
    mockMembershipRepo = MockMembershipRepository();
    mockPaymentRepo = MockPaymentRepository();
    mockAnalyticsService = MockAnalyticsService();
    useCase = HandlePaymentFailure(
      membershipRepository: mockMembershipRepo,
      paymentRepository: mockPaymentRepo,
      analyticsService: mockAnalyticsService,
    );
  });

  final now = DateTime.now();
  final testPayment = Payment(
    id: 'pay-1',
    membershipId: 'mem-1',
    userId: 'user-1',
    libraryId: 'lib-1',
    amount: 500.0,
    currency: 'INR',
    status: PaymentStatus.initiated,
    gatewayOrderId: 'order_xyz',
    createdAt: now,
    expiresAt: now.add(const Duration(minutes: 15)),
  );

  final testMembership = Membership(
    id: 'mem-1',
    userId: 'user-1',
    libraryId: 'lib-1',
    plan: MembershipPlan.monthly,
    startDate: now,
    endDate: now.add(const Duration(days: 30)),
    status: MembershipStatus.pendingPayment,
    phoneNumber: '+919876543210',
    assignedSeatId: 'seat-1',
    slot: Slot.morning,
    createdAt: now,
  );

  const testParams = HandlePaymentFailureParams(
    paymentId: 'pay-1',
    reason: 'Payment declined by bank',
  );

  group('HandlePaymentFailure', () {
    test('should return failure when payment not found', () async {
      when(
        mockPaymentRepo.getPaymentById(any),
      ).thenAnswer((_) async => const Left(PaymentNotFoundFailure()));

      final result = await useCase(testParams);

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<PaymentNotFoundFailure>()),
        (_) => fail('Should not return success'),
      );
    });

    test(
      'should return failure when trying to fail successful payment',
      () async {
        final successfulPayment = testPayment.copyWith(
          status: PaymentStatus.success,
        );

        when(
          mockPaymentRepo.getPaymentById(any),
        ).thenAnswer((_) async => Right(successfulPayment));

        final result = await useCase(testParams);

        expect(result.isLeft(), true);
        result.fold(
          (failure) => expect(failure, isA<PaymentAlreadyProcessedFailure>()),
          (_) => fail('Should not return success'),
        );
      },
    );

    test('should mark payment as failed and cancel membership', () async {
      when(
        mockPaymentRepo.getPaymentById(any),
      ).thenAnswer((_) async => Right(testPayment));
      when(mockPaymentRepo.updatePayment(any)).thenAnswer((invocation) async {
        return Right(invocation.positionalArguments[0] as Payment);
      });
      when(
        mockMembershipRepo.getMembershipById(any),
      ).thenAnswer((_) async => Right(testMembership));
      when(mockMembershipRepo.updateMembership(any)).thenAnswer((
        invocation,
      ) async {
        return Right(invocation.positionalArguments[0] as Membership);
      });

      final result = await useCase(testParams);

      expect(result.isRight(), true);
      result.fold((_) => fail('Should not return failure'), (failResult) {
        expect(failResult.payment.status, PaymentStatus.failed);
        expect(failResult.payment.failureReason, testParams.reason);
        expect(failResult.membership.status, MembershipStatus.cancelled);
        expect(failResult.membership.assignedSeatId, isNull);
      });

      verify(mockPaymentRepo.updatePayment(any)).called(1);
      verify(mockMembershipRepo.updateMembership(any)).called(1);
    });

    test('should not cancel already active membership', () async {
      final activeMembership = testMembership.copyWith(
        status: MembershipStatus.active,
      );

      when(
        mockPaymentRepo.getPaymentById(any),
      ).thenAnswer((_) async => Right(testPayment));
      when(mockPaymentRepo.updatePayment(any)).thenAnswer((invocation) async {
        return Right(invocation.positionalArguments[0] as Payment);
      });
      when(
        mockMembershipRepo.getMembershipById(any),
      ).thenAnswer((_) async => Right(activeMembership));

      final result = await useCase(testParams);

      expect(result.isRight(), true);
      result.fold((_) => fail('Should not return failure'), (failResult) {
        expect(failResult.payment.status, PaymentStatus.failed);
        expect(failResult.membership.status, MembershipStatus.active);
      });

      verifyNever(mockMembershipRepo.updateMembership(any));
    });
  });
}
