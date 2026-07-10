import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/data/repositories/membership_repository_impl.dart';
import 'package:pg_manager/domain/entities/membership.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MembershipRepositoryImpl repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = MembershipRepositoryImpl(firestore: fakeFirestore);
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
  );

  group('MembershipRepositoryImpl', () {
    group('createMembership', () {
      test('should_create_membership_successfully', () async {
        // Act
        final result = await repository.createMembership(testMembership);

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not return failure'), (r) {
          expect(r.id, testMembership.id);
          expect(r.userId, testMembership.userId);
        });
      });
    });

    group('getMembershipById', () {
      test('should_return_membership_when_exists', () async {
        // Arrange
        await repository.createMembership(testMembership);

        // Act
        final result = await repository.getMembershipById(testMembership.id);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (l) => fail('Should not return failure'),
          (r) => expect(r.id, testMembership.id),
        );
      });

      test('should_return_failure_when_membership_not_found', () async {
        // Act
        final result = await repository.getMembershipById('non-existent');

        // Assert
        expect(result.isLeft(), true);
      });
    });

    group('getActiveMembershipByUserAndLibrary', () {
      test('should_return_active_membership', () async {
        // Arrange
        await repository.createMembership(testMembership);

        // Act
        final result = await repository.getActiveMembershipByUserAndLibrary(
          userId: testMembership.userId!,
          libraryId: testMembership.libraryId,
        );

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not return failure'), (r) {
          expect(r, isNotNull);
          expect(r!.status, MembershipStatus.active);
        });
      });

      test('should_return_null_when_no_active_membership', () async {
        // Arrange
        await repository.createMembership(
          testMembership.copyWith(status: MembershipStatus.expired),
        );

        // Act
        final result = await repository.getActiveMembershipByUserAndLibrary(
          userId: testMembership.userId!,
          libraryId: testMembership.libraryId,
        );

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (l) => fail('Should not return failure'),
          (r) => expect(r, isNull),
        );
      });
    });

    group('getMembershipsByUserId', () {
      test('should_return_all_memberships_for_user', () async {
        // Arrange
        await repository.createMembership(testMembership);
        await repository.createMembership(
          testMembership.copyWith(id: 'mem-2', libraryId: 'lib-2'),
        );

        // Act
        final result = await repository.getMembershipsByUserId('user-1');

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (l) => fail('Should not return failure'),
          (r) => expect(r.length, 2),
        );
      });
    });

    group('getMembershipsByLibraryId', () {
      test('should_return_all_memberships_for_library', () async {
        // Arrange
        await repository.createMembership(testMembership);
        await repository.createMembership(
          testMembership.copyWith(id: 'mem-2', userId: 'user-2'),
        );

        // Act
        final result = await repository.getMembershipsByLibraryId('lib-1');

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (l) => fail('Should not return failure'),
          (r) => expect(r.length, 2),
        );
      });
    });

    group('updateMembership', () {
      test('should_update_membership_successfully', () async {
        // Arrange
        await repository.createMembership(testMembership);
        final updated = testMembership.copyWith(assignedSeatId: 'seat-1');

        // Act
        final result = await repository.updateMembership(updated);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (l) => fail('Should not return failure'),
          (r) => expect(r.assignedSeatId, 'seat-1'),
        );
      });
    });

    group('getExpiredMemberships', () {
      test('should_return_memberships_past_end_date', () async {
        // Arrange
        final expiredMembership = Membership(
          id: 'mem-expired',
          userId: 'user-1',
          libraryId: 'lib-1',
          plan: MembershipPlan.monthly,
          startDate: now.subtract(const Duration(days: 40)),
          endDate: now.subtract(const Duration(days: 10)),
          status: MembershipStatus.active,
          phoneNumber: '+919876543210',
        );
        await repository.createMembership(expiredMembership);
        await repository.createMembership(testMembership); // This is active

        // Act
        final result = await repository.getExpiredMemberships(now);

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not return failure'), (r) {
          expect(r.length, 1);
          expect(r[0].id, 'mem-expired');
        });
      });
    });

    group('batchUpdateMembershipStatus', () {
      test('should_batch_update_memberships', () async {
        // Arrange
        await repository.createMembership(testMembership);
        await repository.createMembership(testMembership.copyWith(id: 'mem-2'));

        final membershipsToUpdate = <Membership>[
          testMembership.expire(),
          testMembership.copyWith(id: 'mem-2').expire(),
        ];

        // Act
        final result = await repository.batchUpdateMembershipStatus(
          membershipsToUpdate,
        );

        // Assert
        expect(result.isRight(), true);

        // Verify updates
        final verifyResult = await repository.getMembershipById('mem-1');
        verifyResult.fold(
          (l) => fail('Should not return failure'),
          (r) => expect(r.status, MembershipStatus.expired),
        );
      });
    });
  });
}
