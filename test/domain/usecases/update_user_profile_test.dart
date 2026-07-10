import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/user.dart';
import 'package:pg_manager/domain/repositories/auth_repository.dart';
import 'package:pg_manager/domain/usecases/update_user_profile.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'update_user_profile_test.mocks.dart';

@GenerateMocks([AuthRepository])
void main() {
  late UpdateUserProfile useCase;
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    useCase = UpdateUserProfile(authRepository: mockAuthRepository);
  });

  const testUser = User(
    id: 'user-1',
    name: 'John Doe',
    phone: '+919876543210',
    role: UserRole.student,
    isProfileComplete: true,
  );

  group('UpdateUserProfile', () {
    test('should_return_failure_when_name_is_empty', () async {
      // Act
      final result = await useCase(
        const UpdateUserProfileParams(userId: 'user-1', name: ''),
      );

      // Assert
      expect(result.isLeft(), true);
      verifyNever(
        mockAuthRepository.updateUserProfile(
          userId: anyNamed('userId'),
          name: anyNamed('name'),
          avatarUrl: anyNamed('avatarUrl'),
        ),
      );
    });

    test('should_return_failure_when_name_is_whitespace_only', () async {
      // Act
      final result = await useCase(
        const UpdateUserProfileParams(userId: 'user-1', name: '   '),
      );

      // Assert
      expect(result.isLeft(), true);
    });

    test('should_return_failure_when_name_is_too_short', () async {
      // Act
      final result = await useCase(
        const UpdateUserProfileParams(userId: 'user-1', name: 'A'),
      );

      // Assert
      expect(result.isLeft(), true);
    });

    test('should_update_profile_when_name_is_valid', () async {
      // Arrange
      when(
        mockAuthRepository.updateUserProfile(
          userId: anyNamed('userId'),
          name: anyNamed('name'),
          avatarUrl: anyNamed('avatarUrl'),
        ),
      ).thenAnswer((_) async => const Right(testUser));

      // Act
      final result = await useCase(
        const UpdateUserProfileParams(userId: 'user-1', name: 'John Doe'),
      );

      // Assert
      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.name, 'John Doe');
        expect(r.isProfileComplete, true);
      });

      verify(
        mockAuthRepository.updateUserProfile(
          userId: 'user-1',
          name: 'John Doe',
          avatarUrl: null,
        ),
      ).called(1);
    });

    test('should_trim_name_before_updating', () async {
      // Arrange
      when(
        mockAuthRepository.updateUserProfile(
          userId: anyNamed('userId'),
          name: anyNamed('name'),
          avatarUrl: anyNamed('avatarUrl'),
        ),
      ).thenAnswer((_) async => const Right(testUser));

      // Act
      await useCase(
        const UpdateUserProfileParams(userId: 'user-1', name: '  John Doe  '),
      );

      // Assert
      verify(
        mockAuthRepository.updateUserProfile(
          userId: 'user-1',
          name: 'John Doe',
          avatarUrl: null,
        ),
      ).called(1);
    });

    test('should_pass_avatar_url_when_provided', () async {
      // Arrange
      when(
        mockAuthRepository.updateUserProfile(
          userId: anyNamed('userId'),
          name: anyNamed('name'),
          avatarUrl: anyNamed('avatarUrl'),
        ),
      ).thenAnswer((_) async => const Right(testUser));

      // Act
      await useCase(
        const UpdateUserProfileParams(
          userId: 'user-1',
          name: 'John Doe',
          avatarUrl: 'https://example.com/avatar.png',
        ),
      );

      // Assert
      verify(
        mockAuthRepository.updateUserProfile(
          userId: 'user-1',
          name: 'John Doe',
          avatarUrl: 'https://example.com/avatar.png',
        ),
      ).called(1);
    });
  });

  group('UpdateUserProfileParams', () {
    test('should_have_correct_props', () {
      const params = UpdateUserProfileParams(
        userId: 'user-1',
        name: 'John Doe',
        avatarUrl: 'https://example.com/avatar.png',
        examPreparingFor: 'UPSC',
        isAccessCardIssued: true,
        address: '123 Main St',
        gender: 'Male',
      );

      expect(params.props, [
        'user-1',
        'John Doe',
        'https://example.com/avatar.png',
        'UPSC',
        true,
        '123 Main St',
        'Male',
      ]);
    });

    test('should_be_equal_with_same_values', () {
      const params1 = UpdateUserProfileParams(
        userId: 'user-1',
        name: 'John Doe',
      );
      const params2 = UpdateUserProfileParams(
        userId: 'user-1',
        name: 'John Doe',
      );

      expect(params1, params2);
    });
  });

  group('User entity profile helpers', () {
    test('displayName_should_return_name_when_profile_complete', () {
      const user = User(
        id: 'user-1',
        name: 'John Doe',
        phone: '+919876543210',
        role: UserRole.student,
        isProfileComplete: true,
      );

      expect(user.displayName, 'John Doe');
    });

    test(
      'displayName_should_return_random_username_when_profile_incomplete',
      () {
        const user = User(
          id: 'user-1',
          name: '',
          phone: '+919876543210',
          role: UserRole.student,
          isProfileComplete: false,
        );

        expect(user.displayName, startsWith('Reader_'));
      },
    );

    test('initials_should_return_first_letter_of_name', () {
      const user = User(
        id: 'user-1',
        name: 'John Doe',
        phone: '+919876543210',
        role: UserRole.student,
        isProfileComplete: true,
      );

      expect(user.initials, 'JD');
    });

    test('initials_should_return_R_when_profile_incomplete', () {
      const user = User(
        id: 'user-1',
        name: '',
        phone: '+919876543210',
        role: UserRole.student,
        isProfileComplete: false,
      );

      expect(user.initials, 'R');
    });

    test('markProfileComplete_should_update_fields', () {
      const user = User(
        id: 'user-1',
        name: '',
        phone: '+919876543210',
        role: UserRole.student,
        isProfileComplete: false,
      );

      final updatedUser = user.markProfileComplete(
        name: 'John Doe',
        avatarUrl: 'https://example.com/avatar.png',
      );

      expect(updatedUser.name, 'John Doe');
      expect(updatedUser.avatarUrl, 'https://example.com/avatar.png');
      expect(updatedUser.isProfileComplete, true);
    });
  });
}
