import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/membership.dart';
import 'package:pg_manager/domain/entities/slot.dart';
import 'package:pg_manager/domain/failures/membership_failures.dart';
import 'package:pg_manager/domain/repositories/membership_repository.dart';
import 'package:pg_manager/domain/usecases/cancel_membership.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'cancel_membership_test.mocks.dart';

@GenerateMocks([MembershipRepository])
void main() {
  late CancelMembership useCase;
  late MockMembershipRepository mockRepo;

  setUp(() {
    mockRepo = MockMembershipRepository();
    useCase = CancelMembership(membershipRepository: mockRepo);
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

  group('CancelMembership', () {
    test(
      'should_return_InvalidMembershipDataFailure_when_ID_is_empty',
      () async {
        final params = CancelMembershipParams(membershipId: '');

        final result = await useCase(params);

        expect(result.isLeft(), true);
        result.fold(
          (l) => expect(l, isA<InvalidMembershipDataFailure>()),
          (r) => fail('Should not return success'),
        );
      },
    );

    test(
      'should_return_MembershipNotFoundFailure_when_not_found',
      () async {
        when(
          mockRepo.getMembershipById(any),
        ).thenAnswer((_) async => const Left(MembershipNotFoundFailure()));

        final params = CancelMembershipParams(membershipId: 'mem-1');

        final result = await useCase(params);

        expect(result.isLeft(), true);
        result.fold(
          (l) => expect(l, isA<MembershipNotFoundFailure>()),
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
          mockRepo.getMembershipById(any),
        ).thenAnswer((_) async => Right(cancelledMembership));

        final params = CancelMembershipParams(membershipId: 'mem-1');

        final result = await useCase(params);

        expect(result.isLeft(), true);
        result.fold(
          (l) => expect(l, isA<MembershipNotActiveFailure>()),
          (r) => fail('Should not return success'),
        );
      },
    );

    test('should_cancel_active_membership_and_clear_seat', () async {
      when(
        mockRepo.getMembershipById(any),
      ).thenAnswer((_) async => Right(testMembership));
      when(
        mockRepo.updateMembership(any),
      ).thenAnswer((inv) async => Right(inv.positionalArguments[0]));

      final params = CancelMembershipParams(membershipId: 'mem-1');

      final result = await useCase(params);

      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.status, MembershipStatus.cancelled);
        expect(r.assignedSeatId, null);
        expect(r.slot, null);
      });

      verify(
        mockRepo.updateMembership(
          argThat(
            predicate<Membership>(
              (m) =>
                  m.status == MembershipStatus.cancelled &&
                  m.assignedSeatId == null &&
                  m.slot == null,
            ),
          ),
        ),
      ).called(1);

      verifyNever(mockRepo.getMembershipsByPhoneNumber(any));
    });

    test('should_cancel_pending_reservation_and_clear_seat', () async {
      final pendingMembership = testMembership.copyWith(
        status: MembershipStatus.pendingPayment,
      );
      when(
        mockRepo.getMembershipById(any),
      ).thenAnswer((_) async => Right(pendingMembership));
      when(
        mockRepo.updateMembership(any),
      ).thenAnswer((inv) async => Right(inv.positionalArguments[0]));

      final params = CancelMembershipParams(membershipId: 'mem-1');

      final result = await useCase(params);

      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.status, MembershipStatus.cancelled);
        expect(r.assignedSeatId, null);
        expect(r.slot, null);
      });

      verify(
        mockRepo.updateMembership(
          argThat(
            predicate<Membership>(
              (m) =>
                  m.status == MembershipStatus.cancelled &&
                  m.assignedSeatId == null &&
                  m.slot == null,
            ),
          ),
        ),
      ).called(1);

      verifyNever(mockRepo.getMembershipsByPhoneNumber(any));
    });

    test(
      'should_cancel_expired_membership_and_clear_seat_without_affecting_siblings',
      () async {
        final expiredMembership = testMembership.copyWith(
          status: MembershipStatus.expired,
        );
        when(
          mockRepo.getMembershipById(any),
        ).thenAnswer((_) async => Right(expiredMembership));
        when(
          mockRepo.updateMembership(any),
        ).thenAnswer((inv) async => Right(inv.positionalArguments[0]));

        final params = CancelMembershipParams(membershipId: 'mem-1');

        final result = await useCase(params);

        expect(result.isRight(), true);
        result.fold((l) => fail('Should not return failure'), (r) {
          expect(r.status, MembershipStatus.cancelled);
          expect(r.assignedSeatId, null);
          expect(r.slot, null);
        });

        verify(mockRepo.updateMembership(any)).called(1);
        verifyNever(mockRepo.getMembershipsByPhoneNumber(any));
        verifyNever(mockRepo.batchUpdateMembershipStatus(any));
      },
    );
  });
}
