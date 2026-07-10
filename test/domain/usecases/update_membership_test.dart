import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/membership.dart';
import 'package:pg_manager/domain/entities/slot.dart';
import 'package:pg_manager/domain/failures/membership_failures.dart';
import 'package:pg_manager/domain/failures/seat_failures.dart';
import 'package:pg_manager/domain/repositories/invoice_repository.dart';
import 'package:pg_manager/domain/repositories/membership_repository.dart';
import 'package:pg_manager/domain/repositories/slot_repository.dart';
import 'package:pg_manager/domain/usecases/update_membership.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'update_membership_test.mocks.dart';

@GenerateMocks([
  MembershipRepository,
  InvoiceRepository,
  SlotRepository,
])
void main() {
  late UpdateMembership useCase;
  late MockMembershipRepository mockRepository;
  late MockInvoiceRepository mockInvoiceRepository;
  late MockSlotRepository mockSlotRepository;

  setUp(() {
    mockRepository = MockMembershipRepository();
    mockInvoiceRepository = MockInvoiceRepository();
    mockSlotRepository = MockSlotRepository();
    useCase = UpdateMembership(
      membershipRepository: mockRepository,
      invoiceRepository: mockInvoiceRepository,
      slotRepository: mockSlotRepository,
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

  group('UpdateMembership', () {
    test(
      'should return InvalidMembershipDataFailure when membership ID is empty',
      () async {
        final params = UpdateMembershipParams(
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
      'should_return_MembershipNotActiveFailure_when_status_is_expired',
      () async {
        final expiredMembership = testMembership.copyWith(
          status: MembershipStatus.expired,
        );
        when(
          mockRepository.getMembershipById(any),
        ).thenAnswer((_) async => Right(expiredMembership));

        final params = UpdateMembershipParams(
          membershipId: 'mem-1',
          newSeatId: 'seat-2',
        );

        final result = await useCase(params);

        expect(result.isLeft(), true);
        result.fold(
          (l) {
            expect(l, isA<MembershipNotActiveFailure>());
            expect(l.message, contains('expired'));
          },
          (r) => fail('Should not return success'),
        );
      },
    );

    test(
      'should_return_MembershipNotActiveFailure_when_status_is_cancelled',
      () async {
        final cancelledMembership = testMembership.copyWith(
          status: MembershipStatus.cancelled,
        );
        when(
          mockRepository.getMembershipById(any),
        ).thenAnswer((_) async => Right(cancelledMembership));

        final params = UpdateMembershipParams(
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
      'should_allow_update_when_status_is_pendingPayment',
      () async {
        final pendingMembership = testMembership.copyWith(
          status: MembershipStatus.pendingPayment,
        );
        when(
          mockRepository.getMembershipById(any),
        ).thenAnswer((_) async => Right(pendingMembership));
        when(
          mockRepository.isSeatSlotOccupied(
            libraryId: anyNamed('libraryId'),
            seatId: anyNamed('seatId'),
            slot: anyNamed('slot'),
          ),
        ).thenAnswer((_) async => const Right(false));
        when(
          mockRepository.updateMembership(any),
        ).thenAnswer((inv) async => Right(inv.positionalArguments[0]));

        final params = UpdateMembershipParams(
          membershipId: 'mem-1',
          newSeatId: 'seat-2',
        );

        final result = await useCase(params);

        expect(result.isRight(), true);
        result.fold(
          (l) => fail('Should not return failure: ${l.message}'),
          (r) {
            expect(r.assignedSeatId, 'seat-2');
            // Status must be preserved — we are NOT activating the
            // membership as a side-effect of editing it.
            expect(r.status, MembershipStatus.pendingPayment);
          },
        );
      },
    );

    test(
      'should return SeatAlreadyOccupiedFailure when new seat+slot is occupied',
      () async {
        when(
          mockRepository.getMembershipById(any),
        ).thenAnswer((_) async => Right(testMembership));
        when(
          mockRepository.isSeatSlotOccupied(
            libraryId: anyNamed('libraryId'),
            seatId: anyNamed('seatId'),
            slot: anyNamed('slot'),
          ),
        ).thenAnswer((_) async => const Right(true));

        final params = UpdateMembershipParams(
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

    test('should update membership seat successfully', () async {
      when(
        mockRepository.getMembershipById(any),
      ).thenAnswer((_) async => Right(testMembership));
      when(
        mockRepository.isSeatSlotOccupied(
          libraryId: anyNamed('libraryId'),
          seatId: anyNamed('seatId'),
          slot: anyNamed('slot'),
        ),
      ).thenAnswer((_) async => const Right(false));
      when(
        mockRepository.updateMembership(any),
      ).thenAnswer((inv) async => Right(inv.positionalArguments[0]));

      final params = UpdateMembershipParams(
        membershipId: 'mem-1',
        newSeatId: 'seat-2',
      );

      final result = await useCase(params);

      expect(result.isRight(), true);
      result.fold(
        (l) => fail('Should not return failure'),
        (r) => expect(r.assignedSeatId, 'seat-2'),
      );
    });

    test('should update membership slot successfully', () async {
      when(
        mockRepository.getMembershipById(any),
      ).thenAnswer((_) async => Right(testMembership));
      when(
        mockRepository.isSeatSlotOccupied(
          libraryId: anyNamed('libraryId'),
          seatId: anyNamed('seatId'),
          slot: anyNamed('slot'),
        ),
      ).thenAnswer((_) async => const Right(false));
      when(
        mockRepository.updateMembership(any),
      ).thenAnswer((inv) async => Right(inv.positionalArguments[0]));

      final params = UpdateMembershipParams(
        membershipId: 'mem-1',
        newSlot: Slot.evening,
      );

      final result = await useCase(params);

      expect(result.isRight(), true);
      result.fold(
        (l) => fail('Should not return failure'),
        (r) => expect(r.slot, Slot.evening),
      );
    });
  });
}
