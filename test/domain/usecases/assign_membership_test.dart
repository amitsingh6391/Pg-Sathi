import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/membership.dart';
import 'package:pg_manager/domain/entities/slot.dart';
import 'package:pg_manager/domain/entities/user.dart';
import 'package:pg_manager/domain/failures/membership_failures.dart';
import 'package:pg_manager/domain/failures/seat_failures.dart';
import 'package:pg_manager/domain/repositories/membership_repository.dart';
import 'package:pg_manager/domain/repositories/user_repository.dart';
import 'package:pg_manager/domain/usecases/assign_membership.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'assign_membership_test.mocks.dart';

@GenerateMocks([MembershipRepository, UserRepository])
void main() {
  late AssignMembership useCase;
  late MockMembershipRepository mockMembershipRepo;
  late MockUserRepository mockUserRepo;

  setUp(() {
    mockMembershipRepo = MockMembershipRepository();
    mockUserRepo = MockUserRepository();
    useCase = AssignMembership(
      membershipRepository: mockMembershipRepo,
      userRepository: mockUserRepo,
    );
  });

  const testStudent = User(
    id: 'student-1',
    name: 'Test Student',
    phone: '+1234567890',
    role: UserRole.student,
  );

  final testParams = AssignMembershipParams(
    membershipId: 'mem-1',
    libraryId: 'lib-1',
    studentPhone: '+1234567890',
    seatId: 'seat-1',
    slot: Slot.morning,
    expiryDate: DateTime.now().add(const Duration(days: 30)),
    plan: MembershipPlan.monthly,
  );

  group('AssignMembership', () {
    test(
      'should return InvalidMembershipDataFailure when phone is empty',
      () async {
        final params = AssignMembershipParams(
          membershipId: 'mem-1',
          libraryId: 'lib-1',
          studentPhone: '',
          seatId: 'seat-1',
          slot: Slot.morning,
          expiryDate: DateTime.now().add(const Duration(days: 30)),
          plan: MembershipPlan.monthly,
        );

        final result = await useCase(params);

        expect(result.isLeft(), true);
        result.fold(
          (l) => expect(l, isA<InvalidMembershipDataFailure>()),
          (r) => fail('Should not return success'),
        );
      },
    );

    // Test removed: assign_membership allows unregistered students (userId = null)
    // so it doesn't fail when student is not found

    test(
      'should return SeatAlreadyOccupiedFailure when seat+slot is occupied',
      () async {
        when(
          mockUserRepo.getUserByPhone(any),
        ).thenAnswer((_) async => const Right(testStudent));
        when(
          mockMembershipRepo.getMembershipsByPhoneNumber(any),
        ).thenAnswer((_) async => const Right([]));
        when(
          mockMembershipRepo.isSeatSlotOccupied(
            libraryId: anyNamed('libraryId'),
            seatId: anyNamed('seatId'),
            slot: anyNamed('slot'),
          ),
        ).thenAnswer((_) async => const Right(true));

        final result = await useCase(testParams);

        expect(result.isLeft(), true);
        result.fold(
          (l) => expect(l, isA<SeatAlreadyOccupiedFailure>()),
          (r) => fail('Should not return success'),
        );
      },
    );

    test(
      'should create membership with pendingPayment status when valid',
      () async {
        when(
          mockUserRepo.getUserByPhone(any),
        ).thenAnswer((_) async => const Right(testStudent));
        when(
          mockMembershipRepo.getMembershipsByPhoneNumber(any),
        ).thenAnswer((_) async => const Right([]));
        when(
          mockMembershipRepo.isSeatSlotOccupied(
            libraryId: anyNamed('libraryId'),
            seatId: anyNamed('seatId'),
            slot: anyNamed('slot'),
          ),
        ).thenAnswer((_) async => const Right(false));
        when(mockMembershipRepo.createMembership(any)).thenAnswer(
          (invocation) async => Right(invocation.positionalArguments[0]),
        );

        final result = await useCase(testParams);

        expect(result.isRight(), true);
        result.fold((l) => fail('Should not return failure'), (r) {
          expect(r.userId, testStudent.id);
          expect(r.assignedSeatId, testParams.seatId);
          expect(r.slot, Slot.morning);
          // Membership starts with pendingPayment until payment is completed
          expect(r.status, MembershipStatus.pendingPayment);
        });
      },
    );
  });
}
