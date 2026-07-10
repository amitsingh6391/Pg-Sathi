import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/core/usecase.dart';
import 'package:pg_manager/domain/failures/auth_failures.dart';
import 'package:pg_manager/domain/repositories/auth_repository.dart';
import 'package:pg_manager/domain/usecases/sign_out.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'sign_out_test.mocks.dart';

@GenerateMocks([AuthRepository])
void main() {
  late SignOut useCase;
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    useCase = SignOut(authRepository: mockAuthRepository);
  });

  group('SignOut', () {
    test('should_call_repository_signOut_and_return_success', () async {
      // Arrange
      when(
        mockAuthRepository.signOut(),
      ).thenAnswer((_) async => const Right(null));

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result.isRight(), true);
      verify(mockAuthRepository.signOut()).called(1);
      verifyNoMoreInteractions(mockAuthRepository);
    });

    test('should_return_failure_when_repository_fails', () async {
      // Arrange
      const failure = NotAuthenticatedFailure(message: 'Not signed in');
      when(
        mockAuthRepository.signOut(),
      ).thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (l) => expect(l, isA<NotAuthenticatedFailure>()),
        (r) => fail('Should return failure'),
      );
      verify(mockAuthRepository.signOut()).called(1);
    });

    test('should_return_failure_on_server_error', () async {
      // Arrange
      const failure = OtpSendFailure(message: 'Server error');
      when(
        mockAuthRepository.signOut(),
      ).thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (l) => expect(l.message, 'Server error'),
        (r) => fail('Should return failure'),
      );
    });
  });
}
