import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/custom_slot.dart';
import 'package:pg_manager/domain/entities/membership.dart';
import 'package:pg_manager/domain/entities/slot.dart';
import 'package:pg_manager/domain/repositories/membership_repository.dart';
import 'package:pg_manager/domain/repositories/slot_repository.dart';
import 'package:pg_manager/domain/usecases/get_library_stats.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'get_library_stats_test.mocks.dart';

@GenerateMocks([MembershipRepository, SlotRepository])
void main() {
  late GetLibraryStats useCase;
  late MockMembershipRepository mockMembershipRepo;
  late MockSlotRepository mockSlotRepo;

  setUp(() {
    mockMembershipRepo = MockMembershipRepository();
    mockSlotRepo = MockSlotRepository();
    useCase = GetLibraryStats(
      membershipRepository: mockMembershipRepo,
      slotRepository: mockSlotRepo,
    );
  });

  final now = DateTime.now();

  final testMemberships = [
    Membership(
      id: 'mem-1',
      userId: 'user-1',
      libraryId: 'lib-1',
      plan: MembershipPlan.monthly,
      startDate: now.subtract(const Duration(days: 10)),
      endDate: now.add(const Duration(days: 20)),
      status: MembershipStatus.active,
      phoneNumber: '+919876543210',
      assignedSeatId: 'seat-1',
      slot: Slot.morning,
    ),
    Membership(
      id: 'mem-2',
      userId: 'user-2',
      libraryId: 'lib-1',
      plan: MembershipPlan.monthly,
      startDate: now.subtract(const Duration(days: 10)),
      endDate: now.add(const Duration(days: 20)),
      status: MembershipStatus.active,
      phoneNumber: '+919876543211',
      assignedSeatId: 'seat-2',
      slot: Slot.evening,
    ),
    Membership(
      id: 'mem-3',
      userId: 'user-3',
      libraryId: 'lib-1',
      plan: MembershipPlan.monthly,
      startDate: now.subtract(const Duration(days: 10)),
      endDate: now.add(const Duration(days: 20)),
      status: MembershipStatus.active,
      phoneNumber: '+919876543212',
      assignedSeatId: 'seat-3',
      slot: Slot.morning,
    ),
  ];

  group('GetLibraryStats', () {
    test('should return empty stats when library ID is empty', () async {
      final result = await useCase(const GetLibraryStatsParams(libraryId: ''));

      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.totalSeats, 0);
        expect(r.occupiedSeats, 0);
        expect(r.reservedSeats, 0);
      });
    });

    test('should return empty stats when no slots exist', () async {
      when(
        mockSlotRepo.getActiveSlotsByLibraryId(any),
      ).thenAnswer((_) async => const Right([]));
      when(
        mockMembershipRepo.getActiveAndReservedMembershipsForLibrary(any),
      ).thenAnswer((_) async => const Right([]));

      final result = await useCase(
        const GetLibraryStatsParams(libraryId: 'lib-1'),
      );

      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.totalSeats, 0);
        expect(r.occupiedSeats, 0);
        expect(r.reservedSeats, 0);
      });
    });

    test('should calculate slot-aware stats correctly', () async {
      final testSlots = [
        CustomSlot(
          id: 'slot-1',
          libraryId: 'lib-1',
          name: 'Morning',
          startTime: 360,
          endTime: 840,
          price: 500,
          capacity: 10,
        ),
      ];

      when(
        mockSlotRepo.getActiveSlotsByLibraryId(any),
      ).thenAnswer((_) async => Right(testSlots));
      when(
        mockMembershipRepo.getActiveAndReservedMembershipsForLibrary(any),
      ).thenAnswer((_) async => Right(testMemberships));

      final result = await useCase(
        const GetLibraryStatsParams(libraryId: 'lib-1'),
      );

      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.totalSeats, 10);
        // Three distinct seats (legacy slot on mems); stacked renewals would not add +1
        expect(r.occupiedSeats, 3);
        expect(r.reservedSeats, 0);
        expect(r.availableSeats, 7);
      });
    });

    test(
      'should count one occupied seat when two active memberships share seat and slot',
      () async {
        final testSlots = [
          CustomSlot(
            id: 'slot-morning',
            libraryId: 'lib-1',
            name: 'Morning',
            startTime: 360,
            endTime: 840,
            price: 500,
            capacity: 20,
          ),
        ];

        final stacked = [
          Membership(
            id: 'mem-current',
            userId: 'user-1',
            libraryId: 'lib-1',
            plan: MembershipPlan.monthly,
            startDate: now.subtract(const Duration(days: 60)),
            endDate: DateTime(now.year, now.month, now.day),
            status: MembershipStatus.active,
            phoneNumber: '+919876543210',
            assignedSeatId: 'S01',
            slotId: 'slot-morning',
          ),
          Membership(
            id: 'mem-renewal',
            userId: 'user-1',
            libraryId: 'lib-1',
            plan: MembershipPlan.monthly,
            startDate: DateTime(now.year, now.month, now.day),
            endDate: now.add(const Duration(days: 30)),
            status: MembershipStatus.active,
            phoneNumber: '+919876543210',
            assignedSeatId: 'S01',
            slotId: 'slot-morning',
          ),
        ];

        when(
          mockSlotRepo.getActiveSlotsByLibraryId(any),
        ).thenAnswer((_) async => Right(testSlots));
        when(
          mockMembershipRepo.getActiveAndReservedMembershipsForLibrary(any),
        ).thenAnswer((_) async => Right(stacked));

        final result = await useCase(
          const GetLibraryStatsParams(libraryId: 'lib-1'),
        );

        expect(result.isRight(), true);
        result.fold((l) => fail('Should not return failure'), (r) {
          expect(r.totalSeats, 20);
          expect(r.occupiedSeats, 1);
          expect(r.reservedSeats, 0);
          expect(r.availableSeats, 19);
        });
    });

    test('should return all available when no memberships', () async {
      final testSlots = [
        CustomSlot(
          id: 'slot-1',
          libraryId: 'lib-1',
          name: 'Morning',
          startTime: 360,
          endTime: 840,
          price: 500,
          capacity: 10,
        ),
      ];

      when(
        mockSlotRepo.getActiveSlotsByLibraryId(any),
      ).thenAnswer((_) async => Right(testSlots));
      when(
        mockMembershipRepo.getActiveAndReservedMembershipsForLibrary(any),
      ).thenAnswer((_) async => const Right([]));

      final result = await useCase(
        const GetLibraryStatsParams(libraryId: 'lib-1'),
      );

      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.totalSeats, 10);
        expect(r.occupiedSeats, 0);
        expect(r.reservedSeats, 0);
        expect(r.availableSeats, 10);
      });
    });

    test('should ignore memberships without assignedSeatId', () async {
      final testSlots = [
        CustomSlot(
          id: 'slot-1',
          libraryId: 'lib-1',
          name: 'Morning',
          startTime: 360,
          endTime: 840,
          price: 500,
          capacity: 10,
        ),
      ];

      final membershipsWithNull = [
        Membership(
          id: 'mem-1',
          userId: 'user-1',
          libraryId: 'lib-1',
          plan: MembershipPlan.monthly,
          startDate: now.subtract(const Duration(days: 10)),
          endDate: now.add(const Duration(days: 20)),
          status: MembershipStatus.active,
          phoneNumber: '+919876543210',
          assignedSeatId: null, // No seat assigned
          slot: Slot.morning,
        ),
      ];

      when(
        mockSlotRepo.getActiveSlotsByLibraryId(any),
      ).thenAnswer((_) async => Right(testSlots));
      when(
        mockMembershipRepo.getActiveAndReservedMembershipsForLibrary(any),
      ).thenAnswer((_) async => Right(membershipsWithNull));

      final result = await useCase(
        const GetLibraryStatsParams(libraryId: 'lib-1'),
      );

      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.totalSeats, 10);
        expect(r.occupiedSeats, 0);
        expect(r.reservedSeats, 0);
      });
    });

    test(
      'should count active and pending payment memberships separately',
      () async {
        final mixedMemberships = [
          // Active (occupied)
          Membership(
            id: 'mem-1',
            userId: 'user-1',
            libraryId: 'lib-1',
            plan: MembershipPlan.monthly,
            startDate: now.subtract(const Duration(days: 10)),
            endDate: now.add(const Duration(days: 20)),
            status: MembershipStatus.active,
            phoneNumber: '+919876543210',
            assignedSeatId: 'seat-1',
            slot: Slot.morning,
          ),
          // Pending payment (reserved)
          Membership(
            id: 'mem-2',
            userId: 'user-2',
            libraryId: 'lib-1',
            plan: MembershipPlan.monthly,
            startDate: now,
            endDate: now.add(const Duration(days: 30)),
            status: MembershipStatus.pendingPayment,
            phoneNumber: '+919876543211',
            assignedSeatId: 'seat-2',
            slot: Slot.morning,
          ),
          // Pending payment (reserved) - evening
          Membership(
            id: 'mem-3',
            userId: 'user-3',
            libraryId: 'lib-1',
            plan: MembershipPlan.monthly,
            startDate: now,
            endDate: now.add(const Duration(days: 30)),
            status: MembershipStatus.pendingPayment,
            phoneNumber: '+919876543212',
            assignedSeatId: 'seat-3',
            slot: Slot.evening,
          ),
          // Cancelled - should not be counted (usually filtered by repo)
          Membership(
            id: 'mem-4',
            userId: 'user-4',
            libraryId: 'lib-1',
            plan: MembershipPlan.monthly,
            startDate: now.subtract(const Duration(days: 10)),
            endDate: now.add(const Duration(days: 20)),
            status: MembershipStatus.cancelled,
            phoneNumber: '+919876543213',
            assignedSeatId: 'seat-4',
            slot: Slot.evening,
          ),
        ];

        final testSlots = [
          CustomSlot(
            id: 'slot-1',
            libraryId: 'lib-1',
            name: 'Morning',
            startTime: 360,
            endTime: 840,
            price: 500,
            capacity: 10,
          ),
        ];

        when(
          mockSlotRepo.getActiveSlotsByLibraryId(any),
        ).thenAnswer((_) async => Right(testSlots));
        when(
          mockMembershipRepo.getActiveAndReservedMembershipsForLibrary(any),
        ).thenAnswer((_) async => Right(mixedMemberships));

        final result = await useCase(
          const GetLibraryStatsParams(libraryId: 'lib-1'),
        );

        expect(result.isRight(), true);
        result.fold((l) => fail('Should not return failure'), (r) {
          expect(r.totalSeats, 10);
          expect(r.occupiedSeats, 1);
          expect(r.reservedSeats, 2);
          expect(r.availableSeats, 7);
        });
      },
    );

    test('should verify reserved seats are not counted as available', () async {
      // All seats reserved (pending payment)
      final allReserved = [
        Membership(
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
        ),
        Membership(
          id: 'mem-2',
          userId: 'user-2',
          libraryId: 'lib-1',
          plan: MembershipPlan.monthly,
          startDate: now,
          endDate: now.add(const Duration(days: 30)),
          status: MembershipStatus.pendingPayment,
          phoneNumber: '+919876543210',
          assignedSeatId: 'seat-2',
          slot: Slot.morning,
        ),
      ];

      final testSlots = [
        CustomSlot(
          id: 'slot-1',
          libraryId: 'lib-1',
          name: 'Morning',
          startTime: 360,
          endTime: 840,
          price: 500,
          capacity: 2,
        ),
      ];

      when(
        mockSlotRepo.getActiveSlotsByLibraryId(any),
      ).thenAnswer((_) async => Right(testSlots));
      when(
        mockMembershipRepo.getActiveAndReservedMembershipsForLibrary(any),
      ).thenAnswer((_) async => Right(allReserved));

      final result = await useCase(
        const GetLibraryStatsParams(libraryId: 'lib-1'),
      );

      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.totalSeats, 2);
        expect(r.occupiedSeats, 0);
        expect(r.reservedSeats, 2);
        expect(r.availableSeats, 0);
      });
    });
  });
}
