import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/user.dart';
import 'package:pg_manager/domain/failures/auth_failures.dart';
import 'package:pg_manager/domain/repositories/auth_repository.dart';
import 'package:pg_manager/domain/usecases/check_auth_status.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'check_auth_status_test.mocks.dart';

@GenerateMocks([AuthRepository])
void main() {
  late CheckAuthStatus useCase;
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    useCase = CheckAuthStatus(authRepository: mockAuthRepository);
  });

  const params = CheckAuthStatusParams();

  const authenticatedUser = User(
    id: 'user-1',
    name: 'John Doe',
    phone: '+919876543210',
    role: UserRole.student,
    isPhoneVerified: true,
  );

  group('CheckAuthStatus', () {
    test('should_return_not_authenticated_when_no_user', () async {
      // Arrange
      when(
        mockAuthRepository.getCurrentUser(),
      ).thenAnswer((_) async => const Right(null));

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.isAuthenticated, false);
        expect(r.user, isNull);
      });
    });

    test('should_return_authenticated_when_user_exists', () async {
      // Arrange
      when(
        mockAuthRepository.getCurrentUser(),
      ).thenAnswer((_) async => const Right(authenticatedUser));

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.isAuthenticated, true);
        expect(r.user, authenticatedUser);
      });
    });

    test('should_return_failure_when_repository_fails', () async {
      // Arrange
      when(
        mockAuthRepository.getCurrentUser(),
      ).thenAnswer((_) async => const Left(NotAuthenticatedFailure()));

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (l) => expect(l, isA<NotAuthenticatedFailure>()),
        (r) => fail('Should return failure'),
      );
    });
  });

  group('AuthStatus', () {
    test('should_have_correct_props_when_authenticated', () {
      final status = AuthStatus.authenticated(authenticatedUser);

      expect(status.isAuthenticated, true);
      expect(status.user, authenticatedUser);
    });

    test('should_have_correct_props_when_not_authenticated', () {
      const status = AuthStatus.notAuthenticated();

      expect(status.isAuthenticated, false);
      expect(status.user, isNull);
    });
  });

  group('CheckAuthStatusParams', () {
    test('should_have_empty_props', () {
      const params = CheckAuthStatusParams();
      expect(params.props, isEmpty);
    });
  });
}
