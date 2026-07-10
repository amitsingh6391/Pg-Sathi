import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/membership.dart';
import 'package:pg_manager/domain/entities/presence.dart';
import 'package:pg_manager/domain/entities/slot.dart';
import 'package:pg_manager/domain/entities/user.dart';
import 'package:pg_manager/domain/failures/membership_failures.dart';
import 'package:pg_manager/domain/repositories/auth_repository.dart';
import 'package:pg_manager/domain/repositories/membership_repository.dart';
import 'package:pg_manager/domain/repositories/user_repository.dart';
import 'package:pg_manager/domain/usecases/get_student_documents.dart';
import 'package:pg_manager/domain/usecases/get_student_memberships.dart';
import 'package:pg_manager/domain/usecases/sync_memberships_on_login.dart';
import 'package:pg_manager/domain/usecases/validate_daily_presence.dart';
import 'package:pg_manager/presentation/student/cubit/student_home_cubit.dart';
import 'package:pg_manager/presentation/student/cubit/student_home_state.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'student_home_cubit_test.mocks.dart';

@GenerateMocks([
  GetStudentMemberships,
  ValidateDailyPresence,
  SyncMembershipsOnLogin,
  AuthRepository,
  MembershipRepository,
  UserRepository,
  GetStudentDocuments,
])
void main() {
  late StudentHomeCubit cubit;
  late MockGetStudentMemberships mockGetStudentMemberships;
  late MockValidateDailyPresence mockValidateDailyPresence;
  late MockSyncMembershipsOnLogin mockSyncMembershipsOnLogin;
  late MockAuthRepository mockAuthRepository;
  late MockMembershipRepository mockMembershipRepository;
  late MockUserRepository mockUserRepository;
  late MockGetStudentDocuments mockGetStudentDocuments;

  const testUser = User(
    id: 'user-1',
    name: 'Test User',
    phone: '+919876543210',
    role: UserRole.student,
    isProfileComplete: true,
  );

  setUp(() {
    mockGetStudentMemberships = MockGetStudentMemberships();
    mockValidateDailyPresence = MockValidateDailyPresence();
    mockSyncMembershipsOnLogin = MockSyncMembershipsOnLogin();
    mockAuthRepository = MockAuthRepository();
    mockMembershipRepository = MockMembershipRepository();
    mockUserRepository = MockUserRepository();
    mockGetStudentDocuments = MockGetStudentDocuments();

    // Default stub for getCurrentUser
    when(
      mockAuthRepository.getCurrentUser(),
    ).thenAnswer((_) async => const Right(testUser));

    // Default stub for getStudentDocuments
    when(mockGetStudentDocuments(any)).thenAnswer((_) async => const Right([]));

    // Default stub for getUnregisteredMembershipsByPhone
    when(
      mockMembershipRepository.getUnregisteredMembershipsByPhone(any),
    ).thenAnswer((_) async => const Right([]));

    cubit = StudentHomeCubit(
      getStudentMemberships: mockGetStudentMemberships,
      validateDailyPresence: mockValidateDailyPresence,
      syncMembershipsOnLogin: mockSyncMembershipsOnLogin,
      membershipRepository: mockMembershipRepository,
      authRepository: mockAuthRepository,
      userRepository: mockUserRepository,
      getStudentDocuments: mockGetStudentDocuments,
    );
  });

  tearDown(() {
    cubit.close();
  });

  final testMembership = Membership(
    id: 'membership-1',
    userId: 'user-1',
    libraryId: 'library-1',
    plan: MembershipPlan.monthly,
    startDate: DateTime.now().subtract(const Duration(days: 10)),
    endDate: DateTime.now().add(const Duration(days: 20)),
    status: MembershipStatus.active,
    phoneNumber: '+919876543210',
    slot: Slot.morning,
    assignedSeatId: 'seat-1',
  );

  final testMembershipInfo = StudentMembershipInfo(
    membership: testMembership,
    daysRemaining: 20,
    isPendingPayment: false,
    isActive: true,
    isExpired: false,
  );

  final testPresence = Presence(
    id: 'presence-1',
    userId: 'user-1',
    libraryId: 'library-1',
    date: DateTime.now(),
    checkInTime: DateTime.now(),
  );

  group('StudentHomeCubit', () {
    test('initial_state_is_correct', () {
      expect(cubit.state, const StudentHomeState());
      expect(cubit.state.status, StudentHomeStatus.initial);
    });

    group('loadDashboard', () {
      blocTest<StudentHomeCubit, StudentHomeState>(
        'emits_loading_then_success_with_memberships',
        build: () {
          when(
            mockGetStudentMemberships(any),
          ).thenAnswer((_) async => Right([testMembershipInfo]));
          return cubit;
        },
        act: (cubit) => cubit.loadDashboard(userId: 'user-1'),
        expect: () => [
          const StudentHomeState(status: StudentHomeStatus.loading),
          StudentHomeState(
            status: StudentHomeStatus.success,
            user: testUser,
            memberships: [testMembershipInfo],
          ),
        ],
      );

      blocTest<StudentHomeCubit, StudentHomeState>(
        'emits_loading_then_failure_on_error',
        build: () {
          when(
            mockGetStudentMemberships(any),
          ).thenAnswer((_) async => const Left(MembershipNotFoundFailure()));
          return cubit;
        },
        act: (cubit) => cubit.loadDashboard(userId: 'user-1'),
        expect: () => [
          const StudentHomeState(status: StudentHomeStatus.loading),
          const StudentHomeState(
            status: StudentHomeStatus.failure,
            failure: MembershipNotFoundFailure(),
            user: testUser,
          ),
        ],
      );

      blocTest<StudentHomeCubit, StudentHomeState>(
        'emits_success_with_empty_list_when_no_memberships',
        build: () {
          when(
            mockGetStudentMemberships(any),
          ).thenAnswer((_) async => const Right([]));
          return cubit;
        },
        act: (cubit) => cubit.loadDashboard(userId: 'user-1'),
        expect: () => [
          const StudentHomeState(status: StudentHomeStatus.loading),
          const StudentHomeState(
            status: StudentHomeStatus.success,
            user: testUser,
            memberships: [],
          ),
        ],
      );
    });

    group('checkIn', () {
      blocTest<StudentHomeCubit, StudentHomeState>(
        'emits_loading_then_success_with_presence',
        build: () {
          when(
            mockValidateDailyPresence(any),
          ).thenAnswer((_) async => Right(testPresence));
          return cubit;
        },
        act: (cubit) => cubit.checkIn(
          presenceId: 'presence-1',
          userId: 'user-1',
          libraryId: 'library-1',
        ),
        expect: () => [
          const StudentHomeState(status: StudentHomeStatus.loading),
          StudentHomeState(
            status: StudentHomeStatus.success,
            todayPresence: testPresence,
            isCheckedIn: true,
          ),
        ],
      );

      blocTest<StudentHomeCubit, StudentHomeState>(
        'emits_loading_then_failure_on_error',
        build: () {
          when(
            mockValidateDailyPresence(any),
          ).thenAnswer((_) async => const Left(MembershipExpiredFailure()));
          return cubit;
        },
        act: (cubit) => cubit.checkIn(
          presenceId: 'presence-1',
          userId: 'user-1',
          libraryId: 'library-1',
        ),
        expect: () => [
          const StudentHomeState(status: StudentHomeStatus.loading),
          const StudentHomeState(
            status: StudentHomeStatus.failure,
            failure: MembershipExpiredFailure(),
          ),
        ],
      );
    });
  });
}
