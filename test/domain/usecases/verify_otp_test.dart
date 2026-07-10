import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/user.dart';
import 'package:pg_manager/domain/failures/auth_failures.dart';
import 'package:pg_manager/domain/repositories/auth_repository.dart';
import 'package:pg_manager/domain/usecases/verify_otp.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'verify_otp_test.mocks.dart';

@GenerateMocks([AuthRepository])
void main() {
  late VerifyOtp useCase;
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    useCase = VerifyOtp(authRepository: mockAuthRepository);
  });

  const verificationId = 'verification-123';
  const validOtp = '123456';
  const invalidOtp = '12345'; // Too short
  const deviceId = 'device-123';

  const testUser = User(
    id: 'user-1',
    name: 'John Doe',
    phone: '+919876543210',
    role: UserRole.student,
    deviceId: deviceId,
    isPhoneVerified: true,
  );

  group('VerifyOtp', () {
    test('should_return_failure_when_otp_is_invalid_format', () async {
      // Act
      final result = await useCase(
        const VerifyOtpParams(
          verificationId: verificationId,
          otp: invalidOtp,
          role: UserRole.student,
        ),
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold((l) {
        expect(l, isA<InvalidOtpFailure>());
        expect(l.message, 'OTP must be 6 digits');
      }, (r) => fail('Should return failure'));

      verifyNever(
        mockAuthRepository.verifyOtp(
          verificationId: anyNamed('verificationId'),
          otp: anyNamed('otp'),
          deviceId: anyNamed('deviceId'),
          role: anyNamed('role'),
          name: anyNamed('name'),
        ),
      );
    });

    test('should_return_failure_when_otp_contains_non_digits', () async {
      // Act
      final result = await useCase(
        const VerifyOtpParams(
          verificationId: verificationId,
          otp: '12345a',
          role: UserRole.student,
        ),
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (l) => expect(l, isA<InvalidOtpFailure>()),
        (r) => fail('Should return failure'),
      );
    });

    test('should_verify_otp_and_return_user_on_success', () async {
      // Arrange
      when(
        mockAuthRepository.getDeviceId(),
      ).thenAnswer((_) async => const Right(deviceId));
      when(
        mockAuthRepository.verifyOtp(
          verificationId: anyNamed('verificationId'),
          otp: anyNamed('otp'),
          deviceId: anyNamed('deviceId'),
          role: anyNamed('role'),
          name: anyNamed('name'),
        ),
      ).thenAnswer((_) async => const Right(testUser));

      // Act
      final result = await useCase(
        const VerifyOtpParams(
          verificationId: verificationId,
          otp: validOtp,
          role: UserRole.student,
          name: 'John Doe',
        ),
      );

      // Assert
      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.id, testUser.id);
        expect(r.phone, testUser.phone);
        expect(r.isPhoneVerified, true);
      });

      verify(
        mockAuthRepository.verifyOtp(
          verificationId: verificationId,
          otp: validOtp,
          deviceId: deviceId,
          role: UserRole.student,
          name: 'John Doe',
        ),
      ).called(1);
    });

    test('should_return_failure_when_verification_fails', () async {
      // Arrange
      when(
        mockAuthRepository.getDeviceId(),
      ).thenAnswer((_) async => const Right(deviceId));
      when(
        mockAuthRepository.verifyOtp(
          verificationId: anyNamed('verificationId'),
          otp: anyNamed('otp'),
          deviceId: anyNamed('deviceId'),
          role: anyNamed('role'),
          name: anyNamed('name'),
        ),
      ).thenAnswer((_) async => const Left(InvalidOtpFailure()));

      // Act
      final result = await useCase(
        const VerifyOtpParams(
          verificationId: verificationId,
          otp: validOtp,
          role: UserRole.student,
        ),
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (l) => expect(l, isA<InvalidOtpFailure>()),
        (r) => fail('Should return failure'),
      );
    });
  });

  group('VerifyOtpParams', () {
    test('should_have_correct_props', () {
      const params = VerifyOtpParams(
        verificationId: verificationId,
        otp: validOtp,
        role: UserRole.owner,
        name: 'Test User',
      );

      expect(params.props, [
        verificationId,
        validOtp,
        UserRole.owner,
        'Test User',
      ]);
    });
  });
}
