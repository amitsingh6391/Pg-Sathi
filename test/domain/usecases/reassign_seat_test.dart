import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/core/services/analytics_service.dart';
import 'package:pg_manager/domain/entities/membership.dart';
import 'package:pg_manager/domain/entities/slot.dart';
import 'package:pg_manager/domain/failures/membership_failures.dart';
import 'package:pg_manager/domain/failures/seat_failures.dart';
import 'package:pg_manager/domain/repositories/library_repository.dart';
import 'package:pg_manager/domain/repositories/membership_repository.dart';
import 'package:pg_manager/domain/repositories/seat_repository.dart';
import 'package:pg_manager/domain/repositories/slot_repository.dart';
import 'package:pg_manager/domain/usecases/reassign_seat.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'reassign_seat_test.mocks.dart';

@GenerateMocks([
  MembershipRepository,
  LibraryRepository,
  SeatRepository,
  SlotRepository,
  AnalyticsService,
])
void main() {
  late ReassignSeat useCase;
  late MockMembershipRepository mockRepo;
  late MockLibraryRepository mockLibraryRepo;
  late MockSeatRepository mockSeatRepo;
  late MockSlotRepository mockSlotRepo;
  late MockAnalyticsService mockAnalyticsService;

  setUp(() {
    mockRepo = MockMembershipRepository();
    mockLibraryRepo = MockLibraryRepository();
    mockSeatRepo = MockSeatRepository();
    mockSlotRepo = MockSlotRepository();
    mockAnalyticsService = MockAnalyticsService();
    useCase = ReassignSeat(
      membershipRepository: mockRepo,
      libraryRepository: mockLibraryRepo,
      seatRepository: mockSeatRepo,
      slotRepository: mockSlotRepo,
      analyticsService: mockAnalyticsService,
    );
  });

  final now = DateTime.now();
  final testMembership = Membership(
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
  );

  group('ReassignSeat', () {
    test(
      'should return InvalidMembershipDataFailure when membership ID is empty',
      () async {
        final params = ReassignSeatParams(
          membershipId: '',
          newSeatId: 'seat-2',
        );

        final result = await useCase(params);

        expect(result.isLeft(), true);
        result.fold(
          (l) => expect(l, isA<InvalidMembershipDataFailure>()),
          (r) => fail('Should not return success'),
        );
      },
    );

    test(
      'should return InvalidMembershipDataFailure when new seat ID is empty',
      () async {
        final params = ReassignSeatParams(membershipId: 'mem-1', newSeatId: '');

        final result = await useCase(params);

        expect(result.isLeft(), true);
        result.fold(
          (l) => expect(l, isA<InvalidMembershipDataFailure>()),
          (r) => fail('Should not return success'),
        );
      },
    );

    test('should return existing membership when seat is unchanged', () async {
      when(
        mockRepo.getMembershipById(any),
      ).thenAnswer((_) async => Right(testMembership));

      final params = ReassignSeatParams(
        membershipId: 'mem-1',
        newSeatId: 'seat-1', // Same as current
      );

      final result = await useCase(params);

      expect(result.isRight(), true);
      result.fold(
        (l) => fail('Should not return failure'),
        (r) => expect(r.assignedSeatId, 'seat-1'),
      );
      verifyNever(mockRepo.updateMembership(any));
    });

    test(
      'should return MembershipNotActiveFailure for inactive membership',
      () async {
        final inactiveMembership = testMembership.copyWith(
          status: MembershipStatus.cancelled,
        );
        when(
          mockRepo.getMembershipById(any),
        ).thenAnswer((_) async => Right(inactiveMembership));

        final params = ReassignSeatParams(
          membershipId: 'mem-1',
          newSeatId: 'seat-2',
        );

        final result = await useCase(params);

        expect(result.isLeft(), true);
        result.fold(
          (l) => expect(l, isA<MembershipNotActiveFailure>()),
          (r) => fail('Should not return success'),
        );
      },
    );

    test(
      'should return SeatAlreadyOccupiedFailure when new seat is occupied',
      () async {
        when(
          mockRepo.getMembershipById(any),
        ).thenAnswer((_) async => Right(testMembership));
        when(
          mockRepo.isSeatSlotOccupied(
            libraryId: anyNamed('libraryId'),
            seatId: anyNamed('seatId'),
            slot: anyNamed('slot'),
          ),
        ).thenAnswer((_) async => const Right(true));

        final params = ReassignSeatParams(
          membershipId: 'mem-1',
          newSeatId: 'seat-2',
        );

        final result = await useCase(params);

        expect(result.isLeft(), true);
        result.fold(
          (l) => expect(l, isA<SeatAlreadyOccupiedFailure>()),
          (r) => fail('Should not return success'),
        );
      },
    );

    test('should reassign seat successfully', () async {
      when(
        mockRepo.getMembershipById(any),
      ).thenAnswer((_) async => Right(testMembership));
      when(
        mockRepo.isSeatSlotOccupied(
          libraryId: anyNamed('libraryId'),
          seatId: anyNamed('seatId'),
          slot: anyNamed('slot'),
        ),
      ).thenAnswer((_) async => const Right(false));
      when(
        mockRepo.updateMembership(any),
      ).thenAnswer((inv) async => Right(inv.positionalArguments[0]));

      final params = ReassignSeatParams(
        membershipId: 'mem-1',
        newSeatId: 'seat-2',
      );

      final result = await useCase(params);

      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.assignedSeatId, 'seat-2');
        expect(r.slot, Slot.morning); // Slot unchanged
      });
    });

    test('should reassign seat and slot successfully', () async {
      when(
        mockRepo.getMembershipById(any),
      ).thenAnswer((_) async => Right(testMembership));
      when(
        mockRepo.isSeatSlotOccupied(
          libraryId: anyNamed('libraryId'),
          seatId: anyNamed('seatId'),
          slot: anyNamed('slot'),
        ),
      ).thenAnswer((_) async => const Right(false));
      when(
        mockRepo.updateMembership(any),
      ).thenAnswer((inv) async => Right(inv.positionalArguments[0]));

      final params = ReassignSeatParams(
        membershipId: 'mem-1',
        newSeatId: 'seat-2',
        newSlot: Slot.evening,
      );

      final result = await useCase(params);

      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.assignedSeatId, 'seat-2');
        expect(r.slot, Slot.evening);
      });
    });
  });
}
