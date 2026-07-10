import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/library.dart';
import 'package:pg_manager/domain/entities/membership.dart';
import 'package:pg_manager/domain/entities/subscription.dart';
import 'package:pg_manager/domain/entities/subscription_plan.dart';
import 'package:pg_manager/domain/failures/subscription_failures.dart';
import 'package:pg_manager/domain/repositories/library_repository.dart';
import 'package:pg_manager/domain/repositories/membership_repository.dart';
import 'package:pg_manager/domain/repositories/subscription_repository.dart';
import 'package:pg_manager/domain/usecases/validate_seat_limit.dart';
import 'package:mocktail/mocktail.dart';

class MockSubscriptionRepository extends Mock
    implements SubscriptionRepository {}

class MockLibraryRepository extends Mock implements LibraryRepository {}

class MockMembershipRepository extends Mock implements MembershipRepository {}

void main() {
  late ValidateSeatLimit useCase;
  late MockSubscriptionRepository mockSubscriptionRepository;
  late MockLibraryRepository mockLibraryRepository;
  late MockMembershipRepository mockMembershipRepository;

  setUp(() {
    mockSubscriptionRepository = MockSubscriptionRepository();
    mockLibraryRepository = MockLibraryRepository();
    mockMembershipRepository = MockMembershipRepository();
    useCase = ValidateSeatLimit(
      subscriptionRepository: mockSubscriptionRepository,
      libraryRepository: mockLibraryRepository,
      membershipRepository: mockMembershipRepository,
    );
  });

  group('ValidateSeatLimit', () {
    const testOwnerId = 'owner_123';
    const testLibraryId = 'lib_123';

    final testLibrary = Library(
      id: testLibraryId,
      ownerId: testOwnerId,
      name: 'Test Library',
      capacity: 20,
    );

    List<Membership> createMemberships(int count) {
      return List.generate(
        count,
        (i) => Membership(
          id: 'membership_$i',
          libraryId: testLibraryId,
          assignedSeatId: 'seat_$i',
          slotId: 'slot_$i',
          phoneNumber: '123456789$i',
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 30)),
          plan: MembershipPlan.monthly,
          status: MembershipStatus.active,
        ),
      );
    }

    group('with active subscription', () {
      test('should return true when adding seat within plan limit', () async {
        // Arrange - Has 45 seats, plan allows 50
        final subscription = Subscription(
          id: 'sub_1',
          ownerId: testOwnerId,
          libraryId: testLibraryId,
          seatCount: 50,
          planId: 'tier_99',
          baseMonthlyPrice: 99,
          durationInMonths: 1,
          discountPercent: 0,
          finalAmount: 99,
          startDate: DateTime.now().subtract(const Duration(days: 5)),
          endDate: DateTime.now().add(const Duration(days: 25)),
          status: SubscriptionStatus.active,
        );

        when(() => mockLibraryRepository.getLibraryByOwnerId(testOwnerId))
            .thenAnswer((_) async => Right(testLibrary));
        when(() => mockMembershipRepository
                .getActiveAndReservedMembershipsForLibrary(testLibraryId))
            .thenAnswer((_) async => Right(createMemberships(45)));
        when(() => mockSubscriptionRepository.getActiveSubscription(testOwnerId))
            .thenAnswer((_) async => Right(subscription));

        // Act
        final result = await useCase(
          const ValidateSeatLimitParams(ownerId: testOwnerId),
        );

        // Assert
        expect(result.isRight(), true);
      });

      test('should return failure when adding seat exceeds plan limit',
          () async {
        // Arrange - Already at 50 seats, plan allows 50
        final subscription = Subscription(
          id: 'sub_1',
          ownerId: testOwnerId,
          libraryId: testLibraryId,
          seatCount: 50,
          planId: 'tier_99',
          baseMonthlyPrice: 99,
          durationInMonths: 1,
          discountPercent: 0,
          finalAmount: 99,
          startDate: DateTime.now().subtract(const Duration(days: 5)),
          endDate: DateTime.now().add(const Duration(days: 25)),
          status: SubscriptionStatus.active,
        );

        when(() => mockLibraryRepository.getLibraryByOwnerId(testOwnerId))
            .thenAnswer((_) async => Right(testLibrary));
        when(() => mockMembershipRepository
                .getActiveAndReservedMembershipsForLibrary(testLibraryId))
            .thenAnswer((_) async => Right(createMemberships(50)));
        when(() => mockSubscriptionRepository.getActiveSubscription(testOwnerId))
            .thenAnswer((_) async => Right(subscription));

        // Act
        final result = await useCase(
          const ValidateSeatLimitParams(ownerId: testOwnerId),
        );

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) {
            expect(failure, isA<SeatLimitExceededFailure>());
            expect((failure as SeatLimitExceededFailure).maxSeats, 50);
          },
          (_) => fail('Should return failure'),
        );
      });
    });

    group('freemium model (no subscription)', () {
      test('should return true when under free seat limit', () async {
        // Arrange - Has 5 seats, free limit is 7
        when(() => mockLibraryRepository.getLibraryByOwnerId(testOwnerId))
            .thenAnswer((_) async => Right(testLibrary));
        when(() => mockMembershipRepository
                .getActiveAndReservedMembershipsForLibrary(testLibraryId))
            .thenAnswer((_) async => Right(createMemberships(5)));
        when(() => mockSubscriptionRepository.getActiveSubscription(testOwnerId))
            .thenAnswer((_) async => const Right(null));

        // Act
        final result = await useCase(
          const ValidateSeatLimitParams(ownerId: testOwnerId),
        );

        // Assert
        expect(result.isRight(), true);
      });

      test('should return true when at free limit minus one', () async {
        // Arrange - Has 6 seats, adding 7th is allowed (free limit is 7)
        when(() => mockLibraryRepository.getLibraryByOwnerId(testOwnerId))
            .thenAnswer((_) async => Right(testLibrary));
        when(() => mockMembershipRepository
                .getActiveAndReservedMembershipsForLibrary(testLibraryId))
            .thenAnswer((_) async => Right(createMemberships(6)));
        when(() => mockSubscriptionRepository.getActiveSubscription(testOwnerId))
            .thenAnswer((_) async => const Right(null));

        // Act
        final result = await useCase(
          const ValidateSeatLimitParams(ownerId: testOwnerId),
        );

        // Assert
        expect(result.isRight(), true);
      });

      test('should return failure when trying to exceed free limit', () async {
        // Arrange - Already has 7 seats, trying to add 8th
        when(() => mockLibraryRepository.getLibraryByOwnerId(testOwnerId))
            .thenAnswer((_) async => Right(testLibrary));
        when(() => mockMembershipRepository
                .getActiveAndReservedMembershipsForLibrary(testLibraryId))
            .thenAnswer((_) async => Right(createMemberships(7)));
        when(() => mockSubscriptionRepository.getActiveSubscription(testOwnerId))
            .thenAnswer((_) async => const Right(null));

        // Act
        final result = await useCase(
          const ValidateSeatLimitParams(ownerId: testOwnerId),
        );

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) {
            expect(failure, isA<SeatLimitExceededFailure>());
            expect((failure as SeatLimitExceededFailure).maxSeats,
                SubscriptionPlan.freeSeatsLimit);
          },
          (_) => fail('Should return failure'),
        );
      });
    });

    group('expired subscription falls back to freemium', () {
      test('should allow if under free limit with expired subscription',
          () async {
        // Arrange - Expired subscription, has 5 seats
        final expiredSubscription = Subscription(
          id: 'sub_1',
          ownerId: testOwnerId,
          libraryId: testLibraryId,
          seatCount: 50,
          planId: 'tier_99',
          baseMonthlyPrice: 99,
          durationInMonths: 1,
          discountPercent: 0,
          finalAmount: 99,
          startDate: DateTime.now().subtract(const Duration(days: 35)),
          endDate: DateTime.now().subtract(const Duration(days: 5)),
          status: SubscriptionStatus.expired,
        );

        when(() => mockLibraryRepository.getLibraryByOwnerId(testOwnerId))
            .thenAnswer((_) async => Right(testLibrary));
        when(() => mockMembershipRepository
                .getActiveAndReservedMembershipsForLibrary(testLibraryId))
            .thenAnswer((_) async => Right(createMemberships(5)));
        when(() => mockSubscriptionRepository.getActiveSubscription(testOwnerId))
            .thenAnswer((_) async => Right(expiredSubscription));

        // Act
        final result = await useCase(
          const ValidateSeatLimitParams(ownerId: testOwnerId),
        );

        // Assert
        expect(result.isRight(), true);
      });

      test('should block if over free limit with expired subscription',
          () async {
        // Arrange - Expired subscription, has 7 seats
        final expiredSubscription = Subscription(
          id: 'sub_1',
          ownerId: testOwnerId,
          libraryId: testLibraryId,
          seatCount: 50,
          planId: 'tier_99',
          baseMonthlyPrice: 99,
          durationInMonths: 1,
          discountPercent: 0,
          finalAmount: 99,
          startDate: DateTime.now().subtract(const Duration(days: 35)),
          endDate: DateTime.now().subtract(const Duration(days: 5)),
          status: SubscriptionStatus.expired,
        );

        when(() => mockLibraryRepository.getLibraryByOwnerId(testOwnerId))
            .thenAnswer((_) async => Right(testLibrary));
        when(() => mockMembershipRepository
                .getActiveAndReservedMembershipsForLibrary(testLibraryId))
            .thenAnswer((_) async => Right(createMemberships(7)));
        when(() => mockSubscriptionRepository.getActiveSubscription(testOwnerId))
            .thenAnswer((_) async => Right(expiredSubscription));

        // Act
        final result = await useCase(
          const ValidateSeatLimitParams(ownerId: testOwnerId),
        );

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) => expect(failure, isA<SeatLimitExceededFailure>()),
          (_) => fail('Should return failure'),
        );
      });
    });

    group('new owner (no library)', () {
      test('should return true for new owner without library', () async {
        // Arrange - No library yet
        when(() => mockLibraryRepository.getLibraryByOwnerId(testOwnerId))
            .thenAnswer((_) async => const Right(null));

        // Act
        final result = await useCase(
          const ValidateSeatLimitParams(ownerId: testOwnerId),
        );

        // Assert
        expect(result.isRight(), true);
      });
    });
  });
}
