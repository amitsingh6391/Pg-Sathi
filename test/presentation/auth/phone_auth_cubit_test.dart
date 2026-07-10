import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/core/services/analytics_service.dart';
import 'package:pg_manager/domain/core/usecase.dart';
import 'package:pg_manager/domain/entities/user.dart';
import 'package:pg_manager/domain/failures/auth_failures.dart';
import 'package:pg_manager/domain/repositories/auth_repository.dart';
import 'package:pg_manager/domain/usecases/check_auth_status.dart'
    show CheckAuthStatus, AuthStatus;
import 'package:pg_manager/domain/usecases/delete_account.dart';
import 'package:pg_manager/domain/usecases/send_otp.dart';
import 'package:pg_manager/domain/usecases/sign_out.dart';
import 'package:pg_manager/domain/usecases/verify_otp.dart';
import 'package:pg_manager/presentation/auth/cubit/phone_auth_cubit.dart';
import 'package:pg_manager/presentation/auth/cubit/phone_auth_state.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'phone_auth_cubit_test.mocks.dart';

@GenerateMocks([
  SendOtp,
  VerifyOtp,
  CheckAuthStatus,
  SignOut,
  DeleteAccount,
  AuthRepository,
  AnalyticsService,
])
void main() {
  late PhoneAuthCubit cubit;
  late MockSendOtp mockSendOtp;
  late MockVerifyOtp mockVerifyOtp;
  late MockCheckAuthStatus mockCheckAuthStatus;
  late MockSignOut mockSignOut;
  late MockDeleteAccount mockDeleteAccount;
  late MockAuthRepository mockAuthRepository;
  late MockAnalyticsService mockAnalyticsService;

  setUp(() {
    mockSendOtp = MockSendOtp();
    mockVerifyOtp = MockVerifyOtp();
    mockCheckAuthStatus = MockCheckAuthStatus();
    mockSignOut = MockSignOut();
    mockDeleteAccount = MockDeleteAccount();
    mockAuthRepository = MockAuthRepository();
    mockAnalyticsService = MockAnalyticsService();

    cubit = PhoneAuthCubit(
      sendOtpUseCase: mockSendOtp,
      verifyOtpUseCase: mockVerifyOtp,
      checkAuthStatusUseCase: mockCheckAuthStatus,
      signOutUseCase: mockSignOut,
      deleteAccountUseCase: mockDeleteAccount,
      authRepository: mockAuthRepository,
      analyticsService: mockAnalyticsService,
    );
  });

  tearDown(() {
    cubit.close();
  });

  const testUser = User(
    id: 'user-1',
    name: 'Test User',
    phone: '+919876543210',
    role: UserRole.student,
    deviceId: 'device-1',
    isPhoneVerified: true,
  );

  const verificationId = 'verification-123';
  const phoneNumber = '+919876543210';
  const otp = '123456';

  group('PhoneAuthCubit', () {
    test('initial_state_is_PhoneAuthInitial', () {
      expect(cubit.state, isA<PhoneAuthInitial>());
      expect(cubit.state.isAuthenticated, false);
    });

    group('sendOtp', () {
      blocTest<PhoneAuthCubit, PhoneAuthState>(
        'emits_sendingOtp_then_otpSent_on_success',
        build: () {
          when(
            mockSendOtp(any),
          ).thenAnswer((_) async => const Right(verificationId));
          return cubit;
        },
        act: (cubit) => cubit.sendOtp(phoneNumber),
        expect: () => [
          isA<PhoneAuthSendingOtp>().having(
            (s) => s.phoneNumber,
            'phoneNumber',
            phoneNumber,
          ),
          isA<PhoneAuthOtpSent>()
              .having((s) => s.phoneNumber, 'phoneNumber', phoneNumber)
              .having(
                (s) => s.verificationId,
                'verificationId',
                verificationId,
              ),
        ],
      );

      blocTest<PhoneAuthCubit, PhoneAuthState>(
        'emits_sendingOtp_then_error_on_failure',
        build: () {
          when(
            mockSendOtp(any),
          ).thenAnswer((_) async => const Left(InvalidPhoneNumberFailure()));
          return cubit;
        },
        act: (cubit) => cubit.sendOtp(phoneNumber),
        expect: () => [
          isA<PhoneAuthSendingOtp>(),
          isA<PhoneAuthError>().having(
            (s) => s.failure,
            'failure',
            isA<InvalidPhoneNumberFailure>(),
          ),
        ],
      );
    });

    group('verifyOtp', () {
      blocTest<PhoneAuthCubit, PhoneAuthState>(
        'emits_verifyingOtp_then_authenticated_on_success',
        build: () {
          when(
            mockSendOtp(any),
          ).thenAnswer((_) async => const Right(verificationId));
          when(
            mockVerifyOtp(any),
          ).thenAnswer((_) async => const Right(testUser));
          return cubit;
        },
        act: (cubit) async {
          await cubit.sendOtp(phoneNumber);
          await cubit.verifyOtp(otp);
        },
        expect: () => [
          isA<PhoneAuthSendingOtp>(),
          isA<PhoneAuthOtpSent>(),
          isA<PhoneAuthVerifyingOtp>(),
          isA<PhoneAuthAuthenticated>().having((s) => s.user, 'user', testUser),
        ],
      );

      blocTest<PhoneAuthCubit, PhoneAuthState>(
        'emits_error_on_invalid_otp',
        build: () {
          when(
            mockSendOtp(any),
          ).thenAnswer((_) async => const Right(verificationId));
          when(
            mockVerifyOtp(any),
          ).thenAnswer((_) async => const Left(InvalidOtpFailure()));
          return cubit;
        },
        act: (cubit) async {
          await cubit.sendOtp(phoneNumber);
          await cubit.verifyOtp(otp);
        },
        expect: () => [
          isA<PhoneAuthSendingOtp>(),
          isA<PhoneAuthOtpSent>(),
          isA<PhoneAuthVerifyingOtp>(),
          isA<PhoneAuthError>().having(
            (s) => s.failure,
            'failure',
            isA<InvalidOtpFailure>(),
          ),
        ],
      );

      blocTest<PhoneAuthCubit, PhoneAuthState>(
        'does_nothing_when_no_verification_id',
        build: () => cubit,
        act: (cubit) => cubit.verifyOtp(otp),
        expect: () => [],
      );
    });

    group('checkAuthStatus', () {
      blocTest<PhoneAuthCubit, PhoneAuthState>(
        'emits_checkingAuth_then_authenticated_when_user_exists',
        build: () {
          when(
            mockCheckAuthStatus(any),
          ).thenAnswer((_) async => Right(AuthStatus.authenticated(testUser)));
          return cubit;
        },
        act: (cubit) => cubit.checkAuthStatus(),
        expect: () => [
          isA<PhoneAuthCheckingAuth>(),
          isA<PhoneAuthAuthenticated>().having((s) => s.user, 'user', testUser),
        ],
      );

      blocTest<PhoneAuthCubit, PhoneAuthState>(
        'emits_checkingAuth_then_initial_when_not_authenticated',
        build: () {
          when(
            mockCheckAuthStatus(any),
          ).thenAnswer((_) async => Right(AuthStatus.notAuthenticated()));
          return cubit;
        },
        act: (cubit) => cubit.checkAuthStatus(),
        expect: () => [isA<PhoneAuthCheckingAuth>(), isA<PhoneAuthInitial>()],
      );

      blocTest<PhoneAuthCubit, PhoneAuthState>(
        'emits_error_when_check_fails',
        build: () {
          when(
            mockCheckAuthStatus(any),
          ).thenAnswer((_) async => const Left(NotAuthenticatedFailure()));
          return cubit;
        },
        act: (cubit) => cubit.checkAuthStatus(),
        expect: () => [isA<PhoneAuthCheckingAuth>(), isA<PhoneAuthError>()],
      );
    });

    group('signOut', () {
      blocTest<PhoneAuthCubit, PhoneAuthState>(
        'emits_signingOut_then_signedOut_on_success',
        build: () {
          when(mockSignOut(any)).thenAnswer((_) async => const Right(null));
          return cubit;
        },
        act: (cubit) => cubit.signOut(),
        expect: () => [isA<PhoneAuthSigningOut>(), isA<PhoneAuthSignedOut>()],
        verify: (_) {
          verify(mockSignOut(const NoParams())).called(1);
        },
      );

      blocTest<PhoneAuthCubit, PhoneAuthState>(
        'emits_signingOut_then_error_on_failure',
        build: () {
          when(
            mockSignOut(any),
          ).thenAnswer((_) async => const Left(NotAuthenticatedFailure()));
          return cubit;
        },
        act: (cubit) => cubit.signOut(),
        expect: () => [
          isA<PhoneAuthSigningOut>(),
          isA<PhoneAuthError>().having(
            (s) => s.failure,
            'failure',
            isA<NotAuthenticatedFailure>(),
          ),
        ],
      );

      blocTest<PhoneAuthCubit, PhoneAuthState>(
        'clears_cached_state_on_successful_signOut',
        build: () {
          when(mockSignOut(any)).thenAnswer((_) async => const Right(null));
          when(
            mockSendOtp(any),
          ).thenAnswer((_) async => const Right(verificationId));
          return cubit;
        },
        act: (cubit) async {
          // Set some state first
          await cubit.sendOtp(phoneNumber);
          // Then sign out
          await cubit.signOut();
        },
        expect: () => [
          isA<PhoneAuthSendingOtp>(),
          isA<PhoneAuthOtpSent>(),
          isA<PhoneAuthSigningOut>(),
          isA<PhoneAuthSignedOut>(),
        ],
      );
    });

    group('setRole', () {
      blocTest<PhoneAuthCubit, PhoneAuthState>(
        'updates_selected_role',
        build: () => cubit,
        act: (cubit) => cubit.setRole(UserRole.owner),
        expect: () => [
          isA<PhoneAuthInitial>().having(
            (s) => s.selectedRole,
            'selectedRole',
            UserRole.owner,
          ),
        ],
      );
    });

    group('reset', () {
      blocTest<PhoneAuthCubit, PhoneAuthState>(
        'resets_to_initial_state',
        build: () {
          when(
            mockSendOtp(any),
          ).thenAnswer((_) async => const Right(verificationId));
          return cubit;
        },
        act: (cubit) async {
          await cubit.sendOtp(phoneNumber);
          cubit.reset();
        },
        expect: () => [
          isA<PhoneAuthSendingOtp>(),
          isA<PhoneAuthOtpSent>(),
          isA<PhoneAuthInitial>(),
        ],
      );
    });

    group('goBackToPhoneInput', () {
      blocTest<PhoneAuthCubit, PhoneAuthState>(
        'clears_verification_id_and_returns_to_initial',
        build: () {
          when(
            mockSendOtp(any),
          ).thenAnswer((_) async => const Right(verificationId));
          return cubit;
        },
        act: (cubit) async {
          await cubit.sendOtp(phoneNumber);
          cubit.goBackToPhoneInput();
        },
        expect: () => [
          isA<PhoneAuthSendingOtp>(),
          isA<PhoneAuthOtpSent>(),
          isA<PhoneAuthInitial>(),
        ],
      );
    });

    group('isAuthenticated', () {
      test('returns_true_for_authenticated_state', () {
        final state = const PhoneAuthState.authenticated(user: testUser);
        expect(state.isAuthenticated, true);
      });

      test('returns_false_for_other_states', () {
        expect(const PhoneAuthState.initial().isAuthenticated, false);
        expect(const PhoneAuthState.signingOut().isAuthenticated, false);
        expect(const PhoneAuthState.signedOut().isAuthenticated, false);
      });
    });

    group('currentUser', () {
      test('returns_user_for_authenticated_state', () {
        final state = const PhoneAuthState.authenticated(user: testUser);
        expect(state.currentUser, testUser);
      });

      test('returns_null_for_other_states', () {
        expect(const PhoneAuthState.initial().currentUser, null);
        expect(const PhoneAuthState.signingOut().currentUser, null);
      });
    });
  });
}
