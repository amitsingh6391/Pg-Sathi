import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/membership.dart';
import 'package:pg_manager/domain/entities/presence.dart';
import 'package:pg_manager/domain/failures/membership_failures.dart';
import 'package:pg_manager/domain/failures/presence_failures.dart';
import 'package:pg_manager/domain/repositories/membership_repository.dart';
import 'package:pg_manager/domain/repositories/presence_repository.dart';
import 'package:pg_manager/domain/usecases/validate_daily_presence.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'validate_daily_presence_test.mocks.dart';

@GenerateMocks([PresenceRepository, MembershipRepository])
void main() {
  late ValidateDailyPresence useCase;
  late MockPresenceRepository mockPresenceRepository;
  late MockMembershipRepository mockMembershipRepository;

  setUp(() {
    mockPresenceRepository = MockPresenceRepository();
    mockMembershipRepository = MockMembershipRepository();
    useCase = ValidateDailyPresence(
      presenceRepository: mockPresenceRepository,
      membershipRepository: mockMembershipRepository,
    );
  });

  final now = DateTime(2024, 6, 15, 9, 30); // 9:30 AM
  final today = DateTime(2024, 6, 15);

  final testParams = ValidateDailyPresenceParams(
    presenceId: 'presence-1',
    userId: 'user-1',
    libraryId: 'lib-1',
    checkInTime: now,
  );

  final activeMembership = Membership(
    id: 'mem-1',
    userId: 'user-1',
    libraryId: 'lib-1',
    plan: MembershipPlan.monthly,
    startDate: now.subtract(const Duration(days: 10)),
    endDate: now.add(const Duration(days: 20)),
    status: MembershipStatus.active,
    phoneNumber: '+919876543210',
    assignedSeatId: 'seat-1',
  );

  final recordedPresence = Presence(
    id: 'presence-1',
    userId: 'user-1',
    libraryId: 'lib-1',
    date: today,
    checkInTime: now,
    seatId: 'seat-1',
    status: PresenceStatus.checkedIn,
  );

  group('ValidateDailyPresence', () {
    test(
      'should_record_presence_successfully_when_membership_active_and_not_checked_in',
      () async {
        // Arrange
        when(
          mockMembershipRepository.getActiveMembershipByUserAndLibrary(
            userId: anyNamed('userId'),
            libraryId: anyNamed('libraryId'),
          ),
        ).thenAnswer((_) async => Right(activeMembership));

        when(
          mockPresenceRepository.getTodayPresenceByUserAndLibrary(
            userId: anyNamed('userId'),
            libraryId: anyNamed('libraryId'),
            date: anyNamed('date'),
          ),
        ).thenAnswer((_) async => const Right(null));

        when(
          mockPresenceRepository.checkIn(any),
        ).thenAnswer((_) async => Right(recordedPresence));

        // Act
        final result = await useCase(testParams);

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not return failure'), (r) {
          expect(r.userId, 'user-1');
          expect(r.libraryId, 'lib-1');
          expect(r.status, PresenceStatus.checkedIn);
        });

        verify(mockPresenceRepository.checkIn(any)).called(1);
      },
    );

    test('should_return_failure_when_no_membership_found', () async {
      // Arrange
      when(
        mockMembershipRepository.getActiveMembershipByUserAndLibrary(
          userId: anyNamed('userId'),
          libraryId: anyNamed('libraryId'),
        ),
      ).thenAnswer((_) async => const Right(null));

      // Act
      final result = await useCase(testParams);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (l) => expect(l, isA<MembershipNotFoundFailure>()),
        (r) => fail('Should return failure'),
      );

      verifyNever(mockPresenceRepository.checkIn(any));
    });

    test('should_return_failure_when_membership_is_expired', () async {
      // Arrange
      final expiredMembership = Membership(
        id: 'mem-1',
        userId: 'user-1',
        libraryId: 'lib-1',
        plan: MembershipPlan.monthly,
        phoneNumber: '+919876543210',
        startDate: now.subtract(const Duration(days: 40)),
        endDate: now.subtract(const Duration(days: 10)),
        status: MembershipStatus.active,
      );

      when(
        mockMembershipRepository.getActiveMembershipByUserAndLibrary(
          userId: anyNamed('userId'),
          libraryId: anyNamed('libraryId'),
        ),
      ).thenAnswer((_) async => Right(expiredMembership));

      // Act
      final result = await useCase(testParams);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (l) => expect(l, isA<MembershipExpiredFailure>()),
        (r) => fail('Should return failure'),
      );
    });

    test('should_return_failure_when_membership_is_suspended', () async {
      // Arrange
      final suspendedMembership = activeMembership.copyWith(
        status: MembershipStatus.suspended,
      );

      when(
        mockMembershipRepository.getActiveMembershipByUserAndLibrary(
          userId: anyNamed('userId'),
          libraryId: anyNamed('libraryId'),
        ),
      ).thenAnswer((_) async => Right(suspendedMembership));

      // Act
      final result = await useCase(testParams);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (l) => expect(l, isA<MembershipInactiveFailure>()),
        (r) => fail('Should return failure'),
      );
    });

    test('should_return_failure_when_membership_is_cancelled', () async {
      // Arrange
      final cancelledMembership = activeMembership.copyWith(
        status: MembershipStatus.cancelled,
      );

      when(
        mockMembershipRepository.getActiveMembershipByUserAndLibrary(
          userId: anyNamed('userId'),
          libraryId: anyNamed('libraryId'),
        ),
      ).thenAnswer((_) async => Right(cancelledMembership));

      // Act
      final result = await useCase(testParams);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (l) => expect(l, isA<MembershipInactiveFailure>()),
        (r) => fail('Should return failure'),
      );
    });

    test('should_return_failure_when_already_checked_in_today', () async {
      // Arrange
      final existingPresence = Presence(
        id: 'existing-presence',
        userId: 'user-1',
        libraryId: 'lib-1',
        date: today,
        checkInTime: now.subtract(const Duration(hours: 1)),
        status: PresenceStatus.checkedIn,
      );

      when(
        mockMembershipRepository.getActiveMembershipByUserAndLibrary(
          userId: anyNamed('userId'),
          libraryId: anyNamed('libraryId'),
        ),
      ).thenAnswer((_) async => Right(activeMembership));

      when(
        mockPresenceRepository.getTodayPresenceByUserAndLibrary(
          userId: anyNamed('userId'),
          libraryId: anyNamed('libraryId'),
          date: anyNamed('date'),
        ),
      ).thenAnswer((_) async => Right(existingPresence));

      // Act
      final result = await useCase(testParams);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (l) => expect(l, isA<AlreadyCheckedInFailure>()),
        (r) => fail('Should return failure'),
      );

      verifyNever(mockPresenceRepository.checkIn(any));
    });

    test('should_allow_check_in_when_previously_checked_out_today', () async {
      // Arrange
      final checkedOutPresence = Presence(
        id: 'existing-presence',
        userId: 'user-1',
        libraryId: 'lib-1',
        date: today,
        checkInTime: now.subtract(const Duration(hours: 4)),
        checkOutTime: now.subtract(const Duration(hours: 1)),
        status: PresenceStatus.checkedOut,
      );

      when(
        mockMembershipRepository.getActiveMembershipByUserAndLibrary(
          userId: anyNamed('userId'),
          libraryId: anyNamed('libraryId'),
        ),
      ).thenAnswer((_) async => Right(activeMembership));

      when(
        mockPresenceRepository.getTodayPresenceByUserAndLibrary(
          userId: anyNamed('userId'),
          libraryId: anyNamed('libraryId'),
          date: anyNamed('date'),
        ),
      ).thenAnswer((_) async => Right(checkedOutPresence));

      when(
        mockPresenceRepository.checkIn(any),
      ).thenAnswer((_) async => Right(recordedPresence));

      // Act
      final result = await useCase(testParams);

      // Assert
      expect(result.isRight(), true);
      verify(mockPresenceRepository.checkIn(any)).called(1);
    });

    test('should_include_assigned_seat_in_presence_record', () async {
      // Arrange
      when(
        mockMembershipRepository.getActiveMembershipByUserAndLibrary(
          userId: anyNamed('userId'),
          libraryId: anyNamed('libraryId'),
        ),
      ).thenAnswer((_) async => Right(activeMembership));

      when(
        mockPresenceRepository.getTodayPresenceByUserAndLibrary(
          userId: anyNamed('userId'),
          libraryId: anyNamed('libraryId'),
          date: anyNamed('date'),
        ),
      ).thenAnswer((_) async => const Right(null));

      Presence? capturedPresence;
      when(mockPresenceRepository.checkIn(any)).thenAnswer((invocation) {
        capturedPresence = invocation.positionalArguments[0] as Presence;
        return Future.value(Right(capturedPresence!));
      });

      // Act
      await useCase(testParams);

      // Assert
      expect(capturedPresence?.seatId, 'seat-1');
    });
  });

  group('ValidateDailyPresenceParams', () {
    test('should_have_correct_props', () {
      expect(testParams.props, [
        testParams.presenceId,
        testParams.userId,
        testParams.libraryId,
        testParams.checkInTime,
      ]);
    });
  });
}
