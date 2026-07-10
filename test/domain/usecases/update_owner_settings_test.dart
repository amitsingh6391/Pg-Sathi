import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/user.dart';
import 'package:pg_manager/domain/failures/user_failures.dart';
import 'package:pg_manager/domain/repositories/user_repository.dart';
import 'package:pg_manager/domain/usecases/update_owner_settings.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'update_owner_settings_test.mocks.dart';

@GenerateMocks([UserRepository])
void main() {
  late UpdateOwnerSettings useCase;
  late MockUserRepository mockUserRepository;

  setUp(() {
    mockUserRepository = MockUserRepository();
    useCase = UpdateOwnerSettings(userRepository: mockUserRepository);
  });

  const testOwner = User(
    id: 'owner-1',
    name: 'Library Owner',
    phone: '+919876543210',
    role: UserRole.owner,
    showOtherLibraries: true,
    showMyLibraryInListing: true,
  );

  group('UpdateOwnerSettings', () {
    test('should_update_owner_settings_successfully', () async {
      // Arrange
      when(
        mockUserRepository.getUserById('owner-1'),
      ).thenAnswer((_) async => const Right(testOwner));

      final updatedOwner = testOwner.copyWith(
        showOtherLibraries: false,
        showMyLibraryInListing: false,
      );

      when(
        mockUserRepository.updateUser(any),
      ).thenAnswer((_) async => Right(updatedOwner));

      // Act
      final result = await useCase(
        const UpdateOwnerSettingsParams(
          ownerId: 'owner-1',
          showOtherLibraries: false,
          showMyLibraryInListing: false,
        ),
      );

      // Assert
      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.showOtherLibraries, false);
        expect(r.showMyLibraryInListing, false);
      });

      verify(mockUserRepository.getUserById('owner-1')).called(1);
      verify(mockUserRepository.updateUser(any)).called(1);
    });

    test('should_return_failure_when_owner_not_found', () async {
      // Arrange
      when(
        mockUserRepository.getUserById('owner-1'),
      ).thenAnswer((_) async => const Left(UserNotFoundFailure()));

      // Act
      final result = await useCase(
        const UpdateOwnerSettingsParams(
          ownerId: 'owner-1',
          showOtherLibraries: false,
          showMyLibraryInListing: false,
        ),
      );

      // Assert
      expect(result.isLeft(), true);
      verify(mockUserRepository.getUserById('owner-1')).called(1);
      verifyNever(mockUserRepository.updateUser(any));
    });

    test('should_update_only_specified_settings', () async {
      // Arrange
      when(
        mockUserRepository.getUserById('owner-1'),
      ).thenAnswer((_) async => const Right(testOwner));

      final updatedOwner = testOwner.copyWith(showOtherLibraries: false);

      when(
        mockUserRepository.updateUser(any),
      ).thenAnswer((_) async => Right(updatedOwner));

      // Act
      final result = await useCase(
        const UpdateOwnerSettingsParams(
          ownerId: 'owner-1',
          showOtherLibraries: false,
          showMyLibraryInListing: true, // Keep existing value
        ),
      );

      // Assert
      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.showOtherLibraries, false);
        expect(r.showMyLibraryInListing, true);
      });
    });

    test('should_update_whatsapp_automation_settings', () async {
      // Arrange
      when(
        mockUserRepository.getUserById('owner-1'),
      ).thenAnswer((_) async => const Right(testOwner));

      final updatedOwner = testOwner.copyWith(
        autoWhatsAppInvoicesEnabled: false,
        autoWhatsAppFeeRemindersEnabled: false,
      );

      when(
        mockUserRepository.updateUser(any),
      ).thenAnswer((_) async => Right(updatedOwner));

      // Act
      final result = await useCase(
        const UpdateOwnerSettingsParams(
          ownerId: 'owner-1',
          showOtherLibraries: true,
          showMyLibraryInListing: true,
          autoWhatsAppInvoicesEnabled: false,
          autoWhatsAppFeeRemindersEnabled: false,
        ),
      );

      // Assert
      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.autoWhatsAppInvoicesEnabled, false);
        expect(r.autoWhatsAppFeeRemindersEnabled, false);
      });
    });
  });

  group('UpdateOwnerSettingsParams', () {
    test('should_have_correct_props', () {
      const params = UpdateOwnerSettingsParams(
        ownerId: 'owner-1',
        showOtherLibraries: false,
        showMyLibraryInListing: true,
      );

      expect(params.props, ['owner-1', false, true, null, null]);
    });

    test('should_be_equal_with_same_values', () {
      const params1 = UpdateOwnerSettingsParams(
        ownerId: 'owner-1',
        showOtherLibraries: false,
        showMyLibraryInListing: true,
      );
      const params2 = UpdateOwnerSettingsParams(
        ownerId: 'owner-1',
        showOtherLibraries: false,
        showMyLibraryInListing: true,
      );

      expect(params1, params2);
    });
  });
}
