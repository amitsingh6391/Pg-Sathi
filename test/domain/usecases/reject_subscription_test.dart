import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/core/services/analytics_service.dart';
import 'package:pg_manager/domain/core/failure.dart';
import 'package:pg_manager/domain/entities/subscription.dart';
import 'package:pg_manager/domain/failures/subscription_failures.dart';
import 'package:pg_manager/domain/repositories/subscription_repository.dart';
import 'package:pg_manager/domain/usecases/reject_subscription.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'reject_subscription_test.mocks.dart';

@GenerateMocks([SubscriptionRepository, AnalyticsService])
void main() {
  late RejectSubscription useCase;
  late MockSubscriptionRepository mockRepository;
  late MockAnalyticsService mockAnalyticsService;

  setUp(() {
    mockRepository = MockSubscriptionRepository();
    mockAnalyticsService = MockAnalyticsService();
    useCase = RejectSubscription(
      subscriptionRepository: mockRepository,
      analyticsService: mockAnalyticsService,
    );
  });

  final testSubscription = Subscription(
    id: 'sub-1',
    ownerId: 'owner-1',
    libraryId: 'lib-1',
    seatCount: 50,
    planId: 'tier_149',
    baseMonthlyPrice: 149,
    durationInMonths: 3,
    discountPercent: 0,
    finalAmount: 447,
    startDate: DateTime(2024, 1, 1),
    endDate: DateTime(2024, 4, 1),
    status: SubscriptionStatus.pendingVerification,
  );

  const testParams = RejectSubscriptionParams(
    subscriptionId: 'sub-1',
    adminId: 'admin-1',
    reason: 'Invalid transaction',
  );

  group('RejectSubscription', () {
    test(
      'should return failure when subscription is not found',
      () async {
        // Arrange
        when(mockRepository.getSubscriptionById(any)).thenAnswer(
          (_) async => const Left(
            _SubscriptionDataFailure(message: 'Subscription not found'),
          ),
        );

        // Act
        final result = await useCase(testParams);

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) {
            expect(failure.message, 'Subscription not found');
          },
          (_) => fail('Should return failure'),
        );
        verify(mockRepository.getSubscriptionById('sub-1')).called(1);
        verifyNever(mockRepository.updateSubscription(any));
      },
    );

    test(
      'should successfully reject subscription with pendingVerification status',
      () async {
        // Arrange
        when(mockRepository.getSubscriptionById(any))
            .thenAnswer((_) async => Right(testSubscription));
        when(mockRepository.updateSubscription(any)).thenAnswer(
          (invocation) async => Right(invocation.positionalArguments[0]),
        );

        // Act
        final result = await useCase(testParams);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (_) => fail('Should not return failure'),
          (rejectedSubscription) {
            expect(rejectedSubscription.status, SubscriptionStatus.rejected);
            expect(rejectedSubscription.approvedBy, 'admin-1');
            expect(rejectedSubscription.rejectionReason, 'Invalid transaction');
          },
        );
        verify(mockRepository.getSubscriptionById('sub-1')).called(1);
        verify(mockRepository.updateSubscription(any)).called(1);
      },
    );

    test(
      'should successfully reject subscription with pending status',
      () async {
        // Arrange
        final pendingSubscription = testSubscription.copyWith(
          status: SubscriptionStatus.pending,
        );
        when(mockRepository.getSubscriptionById(any))
            .thenAnswer((_) async => Right(pendingSubscription));
        when(mockRepository.updateSubscription(any)).thenAnswer(
          (invocation) async => Right(invocation.positionalArguments[0]),
        );

        // Act
        final result = await useCase(testParams);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (_) => fail('Should not return failure'),
          (rejectedSubscription) {
            expect(rejectedSubscription.status, SubscriptionStatus.rejected);
            expect(rejectedSubscription.approvedBy, 'admin-1');
            expect(rejectedSubscription.rejectionReason, 'Invalid transaction');
          },
        );
        verify(mockRepository.getSubscriptionById('sub-1')).called(1);
        verify(mockRepository.updateSubscription(any)).called(1);
      },
    );

    test(
      'should return failure when subscription is already active',
      () async {
        // Arrange
        final activeSubscription = testSubscription.copyWith(
          status: SubscriptionStatus.active,
        );
        when(mockRepository.getSubscriptionById(any))
            .thenAnswer((_) async => Right(activeSubscription));

        // Act
        final result = await useCase(testParams);

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) {
            expect(failure, isA<SubscriptionFailure>());
            expect(
              failure.message,
              contains('Subscription cannot be rejected'),
            );
            expect(failure.message, contains('Active'));
          },
          (_) => fail('Should return failure'),
        );
        verify(mockRepository.getSubscriptionById('sub-1')).called(1);
        verifyNever(mockRepository.updateSubscription(any));
      },
    );

    test(
      'should return failure when subscription is already expired',
      () async {
        // Arrange
        final expiredSubscription = testSubscription.copyWith(
          status: SubscriptionStatus.expired,
        );
        when(mockRepository.getSubscriptionById(any))
            .thenAnswer((_) async => Right(expiredSubscription));

        // Act
        final result = await useCase(testParams);

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) {
            expect(failure, isA<SubscriptionFailure>());
            expect(
              failure.message,
              contains('Subscription cannot be rejected'),
            );
            expect(failure.message, contains('Expired'));
          },
          (_) => fail('Should return failure'),
        );
        verify(mockRepository.getSubscriptionById('sub-1')).called(1);
        verifyNever(mockRepository.updateSubscription(any));
      },
    );

    test(
      'should return failure when subscription is already rejected',
      () async {
        // Arrange
        final rejectedSubscription = testSubscription.copyWith(
          status: SubscriptionStatus.rejected,
        );
        when(mockRepository.getSubscriptionById(any))
            .thenAnswer((_) async => Right(rejectedSubscription));

        // Act
        final result = await useCase(testParams);

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) {
            expect(failure, isA<SubscriptionFailure>());
            expect(
              failure.message,
              contains('Subscription cannot be rejected'),
            );
            expect(failure.message, contains('Rejected'));
          },
          (_) => fail('Should return failure'),
        );
        verify(mockRepository.getSubscriptionById('sub-1')).called(1);
        verifyNever(mockRepository.updateSubscription(any));
      },
    );

    test(
      'should return failure when subscription is cancelled',
      () async {
        // Arrange
        final cancelledSubscription = testSubscription.copyWith(
          status: SubscriptionStatus.cancelled,
        );
        when(mockRepository.getSubscriptionById(any))
            .thenAnswer((_) async => Right(cancelledSubscription));

        // Act
        final result = await useCase(testParams);

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) {
            expect(failure, isA<SubscriptionFailure>());
            expect(
              failure.message,
              contains('Subscription cannot be rejected'),
            );
            expect(failure.message, contains('Cancelled'));
          },
          (_) => fail('Should return failure'),
        );
        verify(mockRepository.getSubscriptionById('sub-1')).called(1);
        verifyNever(mockRepository.updateSubscription(any));
      },
    );

    test(
      'should return failure when repository update fails',
      () async {
        // Arrange
        when(mockRepository.getSubscriptionById(any))
            .thenAnswer((_) async => Right(testSubscription));
        when(mockRepository.updateSubscription(any)).thenAnswer(
          (_) async => const Left(
            _SubscriptionDataFailure(message: 'Update failed'),
          ),
        );

        // Act
        final result = await useCase(testParams);

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) {
            expect(failure.message, 'Update failed');
          },
          (_) => fail('Should return failure'),
        );
        verify(mockRepository.getSubscriptionById('sub-1')).called(1);
        verify(mockRepository.updateSubscription(any)).called(1);
      },
    );
  });
}

/// Test failure class for subscription operations.
class _SubscriptionDataFailure extends Failure {
  const _SubscriptionDataFailure({super.message});
}
