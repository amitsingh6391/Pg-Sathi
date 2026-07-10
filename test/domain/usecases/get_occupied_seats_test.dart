import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/core/failure.dart';
import 'package:pg_manager/domain/entities/membership.dart';
import 'package:pg_manager/domain/entities/slot.dart';
import 'package:pg_manager/domain/entities/user.dart';
import 'package:pg_manager/domain/failures/membership_failures.dart';
import 'package:pg_manager/domain/repositories/membership_repository.dart';
import 'package:pg_manager/domain/repositories/user_repository.dart';
import 'package:pg_manager/domain/usecases/get_occupied_seats.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'get_occupied_seats_test.mocks.dart';

@GenerateMocks([MembershipRepository, UserRepository])
void main() {
  late GetOccupiedSeats useCase;
  late MockMembershipRepository mockMembershipRepo;
  late MockUserRepository mockUserRepo;

  setUp(() {
    mockMembershipRepo = MockMembershipRepository();
    mockUserRepo = MockUserRepository();
    useCase = GetOccupiedSeats(
      membershipRepository: mockMembershipRepo,
      userRepository: mockUserRepo,
    );
  });

  // Test users
  final testUser1 = User(
    id: 'user-1',
    name: 'John Doe',
    phone: '+919876543210',
    role: UserRole.student,
    isProfileComplete: true,
  );

  final testUser2 = User(
    id: 'user-2',
    name: 'Jane Smith',
    phone: '+919876543211',
    role: UserRole.student,
    isProfileComplete: true,
  );

  group('GetOccupiedSeats', () {
    test('should return empty list for empty libraryId', () async {
      // Arrange
      const params = GetOccupiedSeatsParams(libraryId: '');

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, const Right<Failure, List<OccupiedSeatInfo>>([]));
      verifyZeroInteractions(mockMembershipRepo);
      verifyZeroInteractions(mockUserRepo);
    });

    test('should return empty list when no memberships', () async {
      // Arrange
      const params = GetOccupiedSeatsParams(libraryId: 'lib-1');
      when(
        mockMembershipRepo.getActiveAndReservedMembershipsForLibrary(any),
      ).thenAnswer((_) async => const Right([]));

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (l) => fail('Should not return failure'),
        (r) => expect(r, isEmpty),
      );
    });

    test(
      'should return both active and reserved seats with user details sorted by seat number',
      () async {
        // Arrange
        const params = GetOccupiedSeatsParams(libraryId: 'lib-1');
        final now = DateTime.now();
        final memberships = [
          Membership(
            id: 'mem-1',
            userId: 'user-1',
            libraryId: 'lib-1',
            assignedSeatId: 'S03',
            plan: MembershipPlan.monthly,
            startDate: now,
            endDate: now.add(const Duration(days: 30)),
            status: MembershipStatus.active,
            phoneNumber: '+919876543210',
            slot: Slot.morning,
            createdAt: now.subtract(const Duration(days: 2)), // Older
          ),
          Membership(
            id: 'mem-2',
            userId: 'user-2',
            libraryId: 'lib-1',
            assignedSeatId: 'S01',
            plan: MembershipPlan.quarterly,
            startDate: now,
            endDate: now.add(const Duration(days: 90)),
            status: MembershipStatus.pendingPayment, // Reserved
            phoneNumber: '+919876543210',
            slot: Slot.evening,
            createdAt: now.subtract(
              const Duration(days: 1),
            ), // Newer (latest first)
          ),
        ];

        when(
          mockMembershipRepo.getActiveAndReservedMembershipsForLibrary(any),
        ).thenAnswer((_) async => Right(memberships));
        // Using batch fetch now - getUsersByIds instead of individual getUserById
        when(
          mockUserRepo.getUsersByIds(any),
        ).thenAnswer((_) async => Right({
              'user-1': testUser1,
              'user-2': testUser2,
            }));

        // Act
        final result = await useCase(params);

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not return failure'), (r) {
          expect(r.length, 2);
          // Sorted by numeric seat serial (S01 before S03)
          expect(r[0].seatId, 'S01');
          expect(r[0].isReserved, true); // Reserved
          expect(r[0].studentName, 'Jane Smith'); // User details populated
          expect(r[0].studentPhone, '+919876543211');
          expect(r[1].seatId, 'S03');
          expect(r[1].isOccupied, true); // Active
          expect(r[1].studentName, 'John Doe');
          expect(r[1].studentPhone, '+919876543210');
        });
      },
    );

    test(
      'should attach stacked active renewal as upcoming for same seat and slot',
      () async {
        const params = GetOccupiedSeatsParams(libraryId: 'lib-1');
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final currentPlan = Membership(
          id: 'mem-current',
          userId: 'user-1',
          libraryId: 'lib-1',
          assignedSeatId: 'S05',
          plan: MembershipPlan.monthly,
          startDate: today.subtract(const Duration(days: 30)),
          endDate: today,
          status: MembershipStatus.active,
          phoneNumber: '+919876543210',
          slot: Slot.morning,
          createdAt: today.subtract(const Duration(days: 30)),
        );
        final renewalPlan = Membership(
          id: 'mem-renewal',
          userId: 'user-1',
          libraryId: 'lib-1',
          assignedSeatId: 'S05',
          plan: MembershipPlan.monthly,
          startDate: today,
          endDate: today.add(const Duration(days: 30)),
          status: MembershipStatus.active,
          phoneNumber: '+919876543210',
          slot: Slot.morning,
          createdAt: now,
        );

        when(
          mockMembershipRepo.getActiveAndReservedMembershipsForLibrary(any),
        ).thenAnswer((_) async => Right([renewalPlan, currentPlan]));
        when(
          mockUserRepo.getUsersByIds(any),
        ).thenAnswer((_) async => Right({'user-1': testUser1}));

        final result = await useCase(params);

        expect(result.isRight(), true);
        result.fold((l) => fail('Should not return failure'), (r) {
          expect(r.length, 1);
          expect(r.first.membership.id, 'mem-current');
          expect(r.first.upcomingMembership?.id, 'mem-renewal');
        });
      },
    );

    test('should filter out memberships without seatId', () async {
      // Arrange
      const params = GetOccupiedSeatsParams(libraryId: 'lib-1');
      final memberships = [
        Membership(
          id: 'mem-1',
          userId: 'user-1',
          libraryId: 'lib-1',
          assignedSeatId: 'S01',
          plan: MembershipPlan.monthly,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 30)),
          status: MembershipStatus.active,
          phoneNumber: '+919876543210',
          slot: Slot.morning,
        ),
        Membership(
          id: 'mem-2',
          userId: 'user-2',
          libraryId: 'lib-1',
          assignedSeatId: null, // No seat assigned
          plan: MembershipPlan.monthly,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 30)),
          status: MembershipStatus.active,
          phoneNumber: '+919876543210',
          slot: Slot.evening,
        ),
      ];

      when(
        mockMembershipRepo.getActiveAndReservedMembershipsForLibrary(any),
      ).thenAnswer((_) async => Right(memberships));
      // Using batch fetch now
      when(
        mockUserRepo.getUsersByIds(any),
      ).thenAnswer((_) async => Right({'user-1': testUser1}));

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.length, 1);
        expect(r[0].seatId, 'S01');
        expect(r[0].studentName, 'John Doe');
      });
    });

    test('should propagate repository failure', () async {
      // Arrange
      const params = GetOccupiedSeatsParams(libraryId: 'lib-1');
      when(
        mockMembershipRepo.getActiveAndReservedMembershipsForLibrary(any),
      ).thenAnswer((_) async => const Left(MembershipNotFoundFailure()));

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.isLeft(), true);
    });

    test('should handle user not found gracefully', () async {
      // Arrange
      const params = GetOccupiedSeatsParams(libraryId: 'lib-1');
      final memberships = [
        Membership(
          id: 'mem-1',
          userId: 'user-unknown',
          libraryId: 'lib-1',
          assignedSeatId: 'S01',
          plan: MembershipPlan.monthly,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 30)),
          status: MembershipStatus.active,
          phoneNumber: '+919876543210',
          slot: Slot.morning,
        ),
      ];

      when(
        mockMembershipRepo.getActiveAndReservedMembershipsForLibrary(any),
      ).thenAnswer((_) async => Right(memberships));
      // Batch fetch returns empty map when user not found
      when(
        mockUserRepo.getUsersByIds(any),
      ).thenAnswer((_) async => const Right(<String, User>{}));

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.length, 1);
        expect(r[0].seatId, 'S01');
        expect(r[0].studentName, isNull); // User not found
        // Phone number comes from membership when user not found
        expect(r[0].studentPhone, '+919876543210');
      });
    });
  });

  group('OccupiedSeatInfo', () {
    test('should calculate seatNumber from seatId', () {
      // Arrange
      final membership = Membership(
        id: 'mem-1',
        userId: 'user-1',
        libraryId: 'lib-1',
        assignedSeatId: 'S05',
        plan: MembershipPlan.monthly,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
        status: MembershipStatus.active,
        phoneNumber: '+919876543210',
        slot: Slot.morning,
      );
      final info = OccupiedSeatInfo(seatId: 'S05', membership: membership);

      // Assert
      expect(info.seatNumber, 5);
    });

    test('should detect expiring soon for active membership', () {
      // Arrange
      final membership = Membership(
        id: 'mem-1',
        userId: 'user-1',
        libraryId: 'lib-1',
        assignedSeatId: 'S01',
        plan: MembershipPlan.monthly,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 5)),
        status: MembershipStatus.active,
        phoneNumber: '+919876543210',
        slot: Slot.morning,
      );
      final info = OccupiedSeatInfo(seatId: 'S01', membership: membership);

      // Assert
      expect(info.isOccupied, true);
      expect(info.isReserved, false);
      expect(info.isExpiringSoon, true);
      expect(info.daysRemaining, inInclusiveRange(4, 5)); // Time-sensitive
    });

    test('should identify reserved (pendingPayment) seat', () {
      // Arrange
      final membership = Membership(
        id: 'mem-1',
        userId: 'user-1',
        libraryId: 'lib-1',
        assignedSeatId: 'S01',
        plan: MembershipPlan.monthly,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
        status: MembershipStatus.pendingPayment,
        phoneNumber: '+919876543210',
        slot: Slot.evening,
      );
      final info = OccupiedSeatInfo(seatId: 'S01', membership: membership);

      // Assert
      expect(info.isReserved, true);
      expect(info.isOccupied, false);
      expect(info.isExpiringSoon, false); // Not applicable for reserved
    });

    test(
      'should not show expiring soon for reserved seat even if date is near',
      () {
        // Arrange - Reserved seat with near expiry
        final membership = Membership(
          id: 'mem-1',
          userId: 'user-1',
          libraryId: 'lib-1',
          assignedSeatId: 'S01',
          plan: MembershipPlan.monthly,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 3)),
          status: MembershipStatus.pendingPayment,
          phoneNumber: '+919876543210',
          slot: Slot.morning,
        );
        final info = OccupiedSeatInfo(seatId: 'S01', membership: membership);

        // Assert - isExpiringSoon is false because it's reserved, not occupied
        expect(info.isReserved, true);
        expect(info.isExpiringSoon, false);
      },
    );

    test('should display name with student name when available', () {
      // Arrange
      final membership = Membership(
        id: 'mem-1',
        userId: 'user-1',
        libraryId: 'lib-1',
        assignedSeatId: 'S01',
        plan: MembershipPlan.monthly,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
        status: MembershipStatus.active,
        phoneNumber: '+919876543210',
        slot: Slot.morning,
      );
      final info = OccupiedSeatInfo(
        seatId: 'S01',
        membership: membership,
        studentName: 'John Doe',
        studentPhone: '+919876543210',
      );

      // Assert
      expect(info.displayName, 'John Doe');
      expect(info.studentPhone, '+919876543210');
    });

    test('should fallback to phone in displayName when name is null', () {
      // Arrange
      final membership = Membership(
        id: 'mem-1',
        userId: 'user-1',
        libraryId: 'lib-1',
        assignedSeatId: 'S01',
        plan: MembershipPlan.monthly,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
        status: MembershipStatus.active,
        phoneNumber: '+919876543210',
        slot: Slot.morning,
      );
      final info = OccupiedSeatInfo(
        seatId: 'S01',
        membership: membership,
        studentName: null,
        studentPhone: '+919876543210',
      );

      // Assert
      expect(info.displayName, '+919876543210');
    });

    test(
      'should fallback to userId in displayName when name and phone are null',
      () {
        // Arrange
        final membership = Membership(
          id: 'mem-1',
          userId: 'user-1234567890',
          libraryId: 'lib-1',
          assignedSeatId: 'S01',
          plan: MembershipPlan.monthly,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 30)),
          status: MembershipStatus.active,
          phoneNumber: '+919876543210',
          slot: Slot.morning,
        );
        final info = OccupiedSeatInfo(
          seatId: 'S01',
          membership: membership,
          studentName: null,
          studentPhone: null,
        );

        // Assert
        // When name and phone are null, displayName falls back to phone from membership
        expect(info.displayName, '+919876543210');
      },
    );
  });
}
