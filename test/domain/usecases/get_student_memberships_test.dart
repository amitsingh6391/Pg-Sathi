import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/library.dart';
import 'package:pg_manager/domain/entities/membership.dart';
import 'package:pg_manager/domain/entities/slot.dart';
import 'package:pg_manager/domain/failures/membership_failures.dart';
import 'package:pg_manager/domain/repositories/library_repository.dart';
import 'package:pg_manager/domain/repositories/membership_repository.dart';
import 'package:pg_manager/domain/repositories/slot_repository.dart';
import 'package:pg_manager/domain/usecases/get_student_memberships.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'get_student_memberships_test.mocks.dart';

@GenerateMocks([MembershipRepository, LibraryRepository, SlotRepository])
void main() {
  late GetStudentMemberships useCase;
  late MockMembershipRepository mockMembershipRepo;
  late MockLibraryRepository mockLibraryRepo;
  late MockSlotRepository mockSlotRepo;

  setUp(() {
    mockMembershipRepo = MockMembershipRepository();
    mockLibraryRepo = MockLibraryRepository();
    mockSlotRepo = MockSlotRepository();
    useCase = GetStudentMemberships(
      membershipRepository: mockMembershipRepo,
      libraryRepository: mockLibraryRepo,
      slotRepository: mockSlotRepo,
    );
  });

  const testUserId = 'user-123';
  const testLibraryId = 'lib-123';

  final testLibrary = Library(
    id: testLibraryId,
    ownerId: 'owner-1',
    name: 'Central Library',
    location: 'Mumbai',
    capacity: 50,
  );

  final activeMembership = Membership(
    id: 'mem-1',
    userId: testUserId,
    libraryId: testLibraryId,
    plan: MembershipPlan.monthly,
    startDate: DateTime.now(),
    endDate: DateTime.now().add(const Duration(days: 30)),
    status: MembershipStatus.active,
    phoneNumber: '+919876543210',
    assignedSeatId: 'S05',
    slot: Slot.morning,
  );

  final pendingMembership = Membership(
    id: 'mem-2',
    userId: testUserId,
    libraryId: testLibraryId,
    plan: MembershipPlan.weekly,
    startDate: DateTime.now(),
    endDate: DateTime.now().add(const Duration(days: 7)),
    status: MembershipStatus.pendingPayment,
    phoneNumber: '+919876543210',
    assignedSeatId: 'S10',
    slot: Slot.evening,
  );

  final expiredMembership = Membership(
    id: 'mem-3',
    userId: testUserId,
    libraryId: testLibraryId,
    plan: MembershipPlan.daily,
    startDate: DateTime.now().subtract(const Duration(days: 2)),
    endDate: DateTime.now().subtract(const Duration(days: 1)),
    status: MembershipStatus.expired,
    phoneNumber: '+919876543210',
    assignedSeatId: 'S01',
    slot: Slot.morning,
  );

  group('GetStudentMemberships', () {
    test('should return empty list when user has no memberships', () async {
      // Arrange
      when(
        mockMembershipRepo.getMembershipsByUserId(testUserId),
      ).thenAnswer((_) async => const Right([]));

      // Act
      final result = await useCase(
        const GetStudentMembershipsParams(userId: testUserId),
      );

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (l) => fail('Should not return failure'),
        (r) => expect(r, isEmpty),
      );
    });

    test('should return only active and pending memberships', () async {
      // Arrange
      when(mockMembershipRepo.getMembershipsByUserId(testUserId)).thenAnswer(
        (_) async =>
            Right([activeMembership, pendingMembership, expiredMembership]),
      );
      when(
        mockLibraryRepo.getLibraryById(testLibraryId),
      ).thenAnswer((_) async => Right(testLibrary));
      when(
        mockSlotRepo.getSlotsByLibraryId(testLibraryId),
      ).thenAnswer((_) async => const Right([]));

      // Act
      final result = await useCase(
        const GetStudentMembershipsParams(userId: testUserId),
      );

      // Assert
      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.length, 2); // Only active and pending
        expect(r.any((m) => m.membership.id == 'mem-1'), true);
        expect(r.any((m) => m.membership.id == 'mem-2'), true);
        expect(
          r.any((m) => m.membership.id == 'mem-3'),
          false,
        ); // Expired excluded
      });
    });

    test('should include library name for each membership', () async {
      // Arrange
      when(
        mockMembershipRepo.getMembershipsByUserId(testUserId),
      ).thenAnswer((_) async => Right([activeMembership]));
      when(
        mockLibraryRepo.getLibraryById(testLibraryId),
      ).thenAnswer((_) async => Right(testLibrary));
      when(
        mockSlotRepo.getSlotsByLibraryId(testLibraryId),
      ).thenAnswer((_) async => const Right([]));

      // Act
      final result = await useCase(
        const GetStudentMembershipsParams(userId: testUserId),
      );

      // Assert
      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.length, 1);
        expect(r.first.libraryName, 'Central Library');
      });
    });

    test('should set isActive true for active membership', () async {
      // Arrange
      when(
        mockMembershipRepo.getMembershipsByUserId(testUserId),
      ).thenAnswer((_) async => Right([activeMembership]));
      when(
        mockLibraryRepo.getLibraryById(testLibraryId),
      ).thenAnswer((_) async => Right(testLibrary));
      when(
        mockSlotRepo.getSlotsByLibraryId(testLibraryId),
      ).thenAnswer((_) async => const Right([]));

      // Act
      final result = await useCase(
        const GetStudentMembershipsParams(userId: testUserId),
      );

      // Assert
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.first.isActive, true);
        expect(r.first.isPendingPayment, false);
      });
    });

    test('should set isPendingPayment true for pending membership', () async {
      // Arrange
      when(
        mockMembershipRepo.getMembershipsByUserId(testUserId),
      ).thenAnswer((_) async => Right([pendingMembership]));
      when(
        mockLibraryRepo.getLibraryById(testLibraryId),
      ).thenAnswer((_) async => Right(testLibrary));
      when(
        mockSlotRepo.getSlotsByLibraryId(testLibraryId),
      ).thenAnswer((_) async => const Right([]));

      // Act
      final result = await useCase(
        const GetStudentMembershipsParams(userId: testUserId),
      );

      // Assert
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.first.isActive, false);
        expect(r.first.isPendingPayment, true);
      });
    });

    test('should sort memberships by slot (morning first)', () async {
      // Arrange - evening membership created first but should appear second
      when(mockMembershipRepo.getMembershipsByUserId(testUserId)).thenAnswer(
        (_) async =>
            Right([pendingMembership, activeMembership]), // evening, morning
      );
      when(
        mockLibraryRepo.getLibraryById(testLibraryId),
      ).thenAnswer((_) async => Right(testLibrary));
      when(
        mockSlotRepo.getSlotsByLibraryId(testLibraryId),
      ).thenAnswer((_) async => const Right([]));

      // Act
      final result = await useCase(
        const GetStudentMembershipsParams(userId: testUserId),
      );

      // Assert
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.first.membership.slot, Slot.morning);
        expect(r.last.membership.slot, Slot.evening);
      });
    });

    test('should propagate repository failure', () async {
      // Arrange
      when(
        mockMembershipRepo.getMembershipsByUserId(testUserId),
      ).thenAnswer((_) async => const Left(MembershipNotFoundFailure()));

      // Act
      final result = await useCase(
        const GetStudentMembershipsParams(userId: testUserId),
      );

      // Assert
      expect(result.isLeft(), true);
    });

    test('should handle library not found gracefully', () async {
      // Arrange
      when(
        mockMembershipRepo.getMembershipsByUserId(testUserId),
      ).thenAnswer((_) async => Right([activeMembership]));
      when(
        mockLibraryRepo.getLibraryById(testLibraryId),
      ).thenAnswer((_) async => const Right(null));
      // Slot repo won't be called if library is null, but mock it anyway
      when(
        mockSlotRepo.getSlotsByLibraryId(testLibraryId),
      ).thenAnswer((_) async => const Right([]));

      // Act
      final result = await useCase(
        const GetStudentMembershipsParams(userId: testUserId),
      );

      // Assert
      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.length, 1);
        expect(r.first.libraryName, isNull); // Library not found
      });
    });

    test(
      'should attach stacked active renewal as upcoming when both periods overlap',
      () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final currentPlan = Membership(
          id: 'mem-current',
          userId: testUserId,
          libraryId: testLibraryId,
          plan: MembershipPlan.monthly,
          startDate: today.subtract(const Duration(days: 30)),
          endDate: today,
          status: MembershipStatus.active,
          phoneNumber: '+919876543210',
          assignedSeatId: 'S05',
          slot: Slot.morning,
        );
        final renewalPlan = Membership(
          id: 'mem-renewal',
          userId: testUserId,
          libraryId: testLibraryId,
          plan: MembershipPlan.monthly,
          startDate: today,
          endDate: today.add(const Duration(days: 30)),
          status: MembershipStatus.active,
          phoneNumber: '+919876543210',
          assignedSeatId: 'S05',
          slot: Slot.morning,
        );

        when(
          mockMembershipRepo.getMembershipsByUserId(testUserId),
        ).thenAnswer((_) async => Right([renewalPlan, currentPlan]));
        when(
          mockLibraryRepo.getLibraryById(testLibraryId),
        ).thenAnswer((_) async => Right(testLibrary));
        when(
          mockSlotRepo.getSlotsByLibraryId(testLibraryId),
        ).thenAnswer((_) async => const Right([]));

        final result = await useCase(
          const GetStudentMembershipsParams(userId: testUserId),
        );

        expect(result.isRight(), true);
        result.fold((l) => fail('Should not return failure'), (r) {
          expect(r.length, 1);
          expect(r.first.membership.id, 'mem-current');
          expect(r.first.upcomingMembership?.id, 'mem-renewal');
        });
      },
    );

    test('should cache library name for same libraryId', () async {
      // Arrange - two memberships with same libraryId
      final membership2 = activeMembership.copyWith(
        id: 'mem-4',
        slot: Slot.evening,
        status: MembershipStatus.pendingPayment,
      );

      when(
        mockMembershipRepo.getMembershipsByUserId(testUserId),
      ).thenAnswer((_) async => Right([activeMembership, membership2]));
      when(
        mockLibraryRepo.getLibraryById(testLibraryId),
      ).thenAnswer((_) async => Right(testLibrary));
      when(
        mockSlotRepo.getSlotsByLibraryId(testLibraryId),
      ).thenAnswer((_) async => const Right([]));

      // Act
      final result = await useCase(
        const GetStudentMembershipsParams(userId: testUserId),
      );

      // Assert
      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.length, 2);
        expect(r[0].libraryName, 'Central Library');
        expect(r[1].libraryName, 'Central Library');
      });
      // Verify library was fetched only once (cached)
      verify(mockLibraryRepo.getLibraryById(testLibraryId)).called(1);
    });
  });

  group('StudentMembershipInfo', () {
    test('should calculate daysRemaining correctly', () async {
      // Arrange
      when(
        mockMembershipRepo.getMembershipsByUserId(testUserId),
      ).thenAnswer((_) async => Right([activeMembership]));
      when(
        mockLibraryRepo.getLibraryById(testLibraryId),
      ).thenAnswer((_) async => Right(testLibrary));
      when(
        mockSlotRepo.getSlotsByLibraryId(testLibraryId),
      ).thenAnswer((_) async => const Right([]));

      // Act
      final result = await useCase(
        const GetStudentMembershipsParams(userId: testUserId),
      );

      // Assert
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.first.daysRemaining, inInclusiveRange(29, 30));
      });
    });

    test('seatNumber should return assignedSeatId', () async {
      // Arrange
      when(
        mockMembershipRepo.getMembershipsByUserId(testUserId),
      ).thenAnswer((_) async => Right([activeMembership]));
      when(
        mockLibraryRepo.getLibraryById(testLibraryId),
      ).thenAnswer((_) async => Right(testLibrary));
      when(
        mockSlotRepo.getSlotsByLibraryId(testLibraryId),
      ).thenAnswer((_) async => const Right([]));

      // Act
      final result = await useCase(
        const GetStudentMembershipsParams(userId: testUserId),
      );

      // Assert
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.first.seatNumber, 'S05');
      });
    });

    test('slotName should return slot displayName', () async {
      // Arrange
      when(
        mockMembershipRepo.getMembershipsByUserId(testUserId),
      ).thenAnswer((_) async => Right([activeMembership]));
      when(
        mockLibraryRepo.getLibraryById(testLibraryId),
      ).thenAnswer((_) async => Right(testLibrary));
      when(
        mockSlotRepo.getSlotsByLibraryId(testLibraryId),
      ).thenAnswer((_) async => const Right([]));

      // Act
      final result = await useCase(
        const GetStudentMembershipsParams(userId: testUserId),
      );

      // Assert
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.first.slotName, 'Morning');
      });
    });

    test('validTill should return membership endDate', () async {
      // Arrange
      when(
        mockMembershipRepo.getMembershipsByUserId(testUserId),
      ).thenAnswer((_) async => Right([activeMembership]));
      when(
        mockLibraryRepo.getLibraryById(testLibraryId),
      ).thenAnswer((_) async => Right(testLibrary));
      when(
        mockSlotRepo.getSlotsByLibraryId(testLibraryId),
      ).thenAnswer((_) async => const Right([]));

      // Act
      final result = await useCase(
        const GetStudentMembershipsParams(userId: testUserId),
      );

      // Assert
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.first.validTill, activeMembership.endDate);
      });
    });

    test('paymentAmount should return correct amount for each plan', () {
      final plans = {
        MembershipPlan.daily: 50.0,
        MembershipPlan.weekly: 300.0,
        MembershipPlan.monthly: 1000.0,
        MembershipPlan.quarterly: 2500.0,
        MembershipPlan.yearly: 8000.0,
      };

      for (final entry in plans.entries) {
        final membership = activeMembership.copyWith(plan: entry.key);
        final info = StudentMembershipInfo(
          membership: membership,
          daysRemaining: 30,
          isPendingPayment: false,
          isActive: true,
          isExpired: false,
          libraryName: 'Test Library',
        );
        expect(info.paymentAmount, entry.value);
      }
    });
  });
}
