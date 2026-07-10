import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/membership.dart';
import 'package:pg_manager/domain/entities/slot.dart';
import 'package:pg_manager/domain/repositories/membership_repository.dart';
import 'package:pg_manager/domain/usecases/expire_memberships.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'expire_memberships_test.mocks.dart';

@GenerateMocks([MembershipRepository])
void main() {
  late ExpireMemberships useCase;
  late MockMembershipRepository mockMembershipRepo;

  setUp(() {
    mockMembershipRepo = MockMembershipRepository();
    useCase = ExpireMemberships(membershipRepository: mockMembershipRepo);
  });

  final now = DateTime.now();

  group('ExpireMemberships', () {
    test('should return zero count when no memberships to expire', () async {
      when(
        mockMembershipRepo.getExpiredMemberships(any),
      ).thenAnswer((_) async => const Right([]));

      final result = await useCase(ExpireMembershipsParams(currentDate: now));

      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.expiredCount, 0);
        expect(r.expiredMembershipIds, isEmpty);
      });
      verifyNever(mockMembershipRepo.batchUpdateMembershipStatus(any));
    });

    test('should expire memberships and clear seats', () async {
      final expiredMemberships = [
        Membership(
          id: 'mem-1',
          userId: 'user-1',
          libraryId: 'lib-1',
          plan: MembershipPlan.monthly,
          startDate: now.subtract(const Duration(days: 30)),
          endDate: now.subtract(const Duration(days: 1)),
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
          startDate: now.subtract(const Duration(days: 30)),
          endDate: now.subtract(const Duration(days: 1)),
          status: MembershipStatus.active,
          phoneNumber: '+919876543211',
          assignedSeatId: 'seat-2',
          slot: Slot.evening,
        ),
      ];

      when(
        mockMembershipRepo.getExpiredMemberships(any),
      ).thenAnswer((_) async => Right(expiredMemberships));
      when(
        mockMembershipRepo.batchUpdateMembershipStatus(any),
      ).thenAnswer((_) async => const Right(null));

      final result = await useCase(ExpireMembershipsParams(currentDate: now));

      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.expiredCount, 2);
        expect(r.expiredMembershipIds, ['mem-1', 'mem-2']);
      });

      verify(
        mockMembershipRepo.batchUpdateMembershipStatus(
          argThat(
            predicate<List<Membership>>((memberships) {
              return memberships.length == 2 &&
                  memberships.every(
                    (m) =>
                        m.status == MembershipStatus.expired &&
                        m.assignedSeatId == null &&
                        m.slot == null,
                  );
            }),
          ),
        ),
      ).called(1);
    });

    test('should handle memberships without seats', () async {
      final membership = Membership(
        id: 'mem-1',
        userId: 'user-1',
        libraryId: 'lib-1',
        plan: MembershipPlan.monthly,
        startDate: now.subtract(const Duration(days: 30)),
        endDate: now.subtract(const Duration(days: 1)),
        status: MembershipStatus.active,
        phoneNumber: '+919876543210',
        assignedSeatId: null,
        slot: null,
      );

      when(
        mockMembershipRepo.getExpiredMemberships(any),
      ).thenAnswer((_) async => Right([membership]));
      when(
        mockMembershipRepo.batchUpdateMembershipStatus(any),
      ).thenAnswer((_) async => const Right(null));

      final result = await useCase(ExpireMembershipsParams(currentDate: now));

      expect(result.isRight(), true);
      result.fold(
        (l) => fail('Should not return failure'),
        (r) => expect(r.expiredCount, 1),
      );
    });
  });
}
