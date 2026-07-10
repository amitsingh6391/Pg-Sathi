import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/failures/auth_failures.dart';
import 'package:pg_manager/domain/repositories/auth_repository.dart';
import 'package:pg_manager/domain/usecases/send_otp.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'send_otp_test.mocks.dart';

@GenerateMocks([AuthRepository])
void main() {
  late SendOtp useCase;
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    useCase = SendOtp(authRepository: mockAuthRepository);
  });

  const validPhoneNumber = '+919876543210';
  const invalidPhoneNumber = '9876543210';
  const verificationId = 'verification-123';

  group('SendOtp', () {
    test('should_return_failure_when_phone_number_is_invalid', () async {
      // Act
      final result = await useCase(
        const SendOtpParams(phoneNumber: invalidPhoneNumber),
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (l) => expect(l, isA<InvalidPhoneNumberFailure>()),
        (r) => fail('Should return failure'),
      );

      verifyNever(mockAuthRepository.sendOtp(any));
    });

    test('should_return_failure_when_phone_number_is_empty', () async {
      // Act
      final result = await useCase(const SendOtpParams(phoneNumber: ''));

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (l) => expect(l, isA<InvalidPhoneNumberFailure>()),
        (r) => fail('Should return failure'),
      );
    });

    test(
      'should_return_failure_when_phone_number_has_no_country_code',
      () async {
        // Act
        final result = await useCase(
          const SendOtpParams(phoneNumber: '9876543210'),
        );

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (l) => expect(l, isA<InvalidPhoneNumberFailure>()),
          (r) => fail('Should return failure'),
        );
      },
    );

    test('should_send_otp_when_phone_number_is_valid', () async {
      // Arrange
      when(
        mockAuthRepository.sendOtp(any),
      ).thenAnswer((_) async => const Right(verificationId));

      // Act
      final result = await useCase(
        const SendOtpParams(phoneNumber: validPhoneNumber),
      );

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (l) => fail('Should not return failure'),
        (r) => expect(r, verificationId),
      );

      verify(mockAuthRepository.sendOtp(validPhoneNumber)).called(1);
    });

    test('should_return_failure_when_repository_fails', () async {
      // Arrange
      when(
        mockAuthRepository.sendOtp(any),
      ).thenAnswer((_) async => const Left(OtpSendFailure()));

      // Act
      final result = await useCase(
        const SendOtpParams(phoneNumber: validPhoneNumber),
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (l) => expect(l, isA<OtpSendFailure>()),
        (r) => fail('Should return failure'),
      );
    });

    test('should_return_too_many_requests_failure', () async {
      // Arrange
      when(
        mockAuthRepository.sendOtp(any),
      ).thenAnswer((_) async => const Left(TooManyRequestsFailure()));

      // Act
      final result = await useCase(
        const SendOtpParams(phoneNumber: validPhoneNumber),
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (l) => expect(l, isA<TooManyRequestsFailure>()),
        (r) => fail('Should return failure'),
      );
    });
  });

  group('SendOtpParams', () {
    test('should_have_correct_props', () {
      const params = SendOtpParams(phoneNumber: validPhoneNumber);
      expect(params.props, [validPhoneNumber]);
    });

    test('should_be_equal_with_same_phone_number', () {
      const params1 = SendOtpParams(phoneNumber: validPhoneNumber);
      const params2 = SendOtpParams(phoneNumber: validPhoneNumber);
      expect(params1, params2);
    });
  });
}
