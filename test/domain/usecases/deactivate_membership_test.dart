import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/membership.dart';
import 'package:pg_manager/domain/failures/membership_failures.dart';
import 'package:pg_manager/domain/repositories/membership_repository.dart';
import 'package:pg_manager/domain/usecases/deactivate_membership.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'deactivate_membership_test.mocks.dart';

@GenerateMocks([MembershipRepository])
void main() {
  late DeactivateMembership useCase;
  late MockMembershipRepository mockRepo;

  setUp(() {
    mockRepo = MockMembershipRepository();
    useCase = DeactivateMembership(membershipRepository: mockRepo);
  });

  final activeMembership = Membership(
    id: 'mem-1',
    userId: 'user-1',
    libraryId: 'lib-1',
    assignedSeatId: 'S01',
    plan: MembershipPlan.monthly,
    startDate: DateTime.now(),
    endDate: DateTime.now().add(const Duration(days: 30)),
    status: MembershipStatus.active,
    phoneNumber: '+919876543210',
  );

  group('DeactivateMembership', () {
    test('should return failure for empty membershipId', () async {
      // Arrange
      const params = DeactivateMembershipParams(membershipId: '');

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (l) => expect(l, isA<InvalidMembershipDataFailure>()),
        (r) => fail('Should not return success'),
      );
      verifyZeroInteractions(mockRepo);
    });

    test('should return failure when membership is already inactive', () async {
      // Arrange
      const params = DeactivateMembershipParams(membershipId: 'mem-1');
      final inactiveMembership = activeMembership.copyWith(
        status: MembershipStatus.cancelled,
      );
      when(
        mockRepo.getMembershipById(any),
      ).thenAnswer((_) async => Right(inactiveMembership));

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (l) => expect(l, isA<MembershipNotActiveFailure>()),
        (r) => fail('Should not return success'),
      );
    });

    test('should return failure when membership is expired', () async {
      // Arrange
      const params = DeactivateMembershipParams(membershipId: 'mem-1');
      final expiredMembership = activeMembership.copyWith(
        status: MembershipStatus.expired,
      );
      when(
        mockRepo.getMembershipById(any),
      ).thenAnswer((_) async => Right(expiredMembership));

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (l) => expect(l, isA<MembershipNotActiveFailure>()),
        (r) => fail('Should not return success'),
      );
    });

    test('should deactivate membership successfully', () async {
      // Arrange
      const params = DeactivateMembershipParams(membershipId: 'mem-1');
      when(
        mockRepo.getMembershipById(any),
      ).thenAnswer((_) async => Right(activeMembership));
      when(mockRepo.updateMembership(any)).thenAnswer((invocation) async {
        final m = invocation.positionalArguments[0] as Membership;
        return Right(m);
      });

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.status, MembershipStatus.cancelled);
        expect(r.assignedSeatId, null); // Seat cleared
      });
      verify(mockRepo.updateMembership(any)).called(1);
    });

    test('should propagate repository failure', () async {
      // Arrange
      const params = DeactivateMembershipParams(membershipId: 'mem-1');
      when(
        mockRepo.getMembershipById(any),
      ).thenAnswer((_) async => const Left(MembershipNotFoundFailure()));

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (l) => expect(l, isA<MembershipNotFoundFailure>()),
        (r) => fail('Should not return success'),
      );
    });
  });
}
