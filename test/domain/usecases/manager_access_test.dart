import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/manager_access.dart';
import 'package:pg_manager/domain/entities/user.dart';
import 'package:pg_manager/domain/repositories/manager_repository.dart';
import 'package:pg_manager/domain/usecases/manager_usecases.dart';
import 'package:mocktail/mocktail.dart';

class _MockManagerRepository extends Mock implements ManagerRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const ManagerAccess(phone: '', libraryId: ''));
  });

  group('InviteManager', () {
    late _MockManagerRepository repository;
    late InviteManager useCase;

    setUp(() {
      repository = _MockManagerRepository();
      useCase = InviteManager(managerRepository: repository);
    });

    test('should_store_mobile_as_e164_number', () async {
      when(
        () => repository.inviteManager(
          phone: any(named: 'phone'),
          ownerId: any(named: 'ownerId'),
          libraryId: any(named: 'libraryId'),
        ),
      ).thenAnswer((_) async => const Right(null));

      await useCase(
        const InviteManagerParams(
          ownerId: 'owner-1',
          libraryId: 'lib-1',
          mobile: '98765 43210',
        ),
      );

      verify(
        () => repository.inviteManager(
          phone: '+919876543210',
          ownerId: 'owner-1',
          libraryId: 'lib-1',
        ),
      ).called(1);
    });

    test('should_reject_number_that_is_not_ten_digits', () async {
      final result = await useCase(
        const InviteManagerParams(
          ownerId: 'owner-1',
          libraryId: 'lib-1',
          mobile: '12345',
        ),
      );

      expect(result.isLeft(), true);
      verifyNever(
        () => repository.inviteManager(
          phone: any(named: 'phone'),
          ownerId: any(named: 'ownerId'),
          libraryId: any(named: 'libraryId'),
        ),
      );
    });
  });

  group('User manager access', () {
    const owner = User(
      id: 'owner-1',
      name: 'Owner',
      phone: '+911',
      role: UserRole.owner,
    );
    const manager = User(
      id: 'manager-1',
      name: 'Manager',
      phone: '+912',
      role: UserRole.owner,
      managedByOwnerId: 'owner-1',
      managedLibraryIds: ['lib-2'],
    );

    test('should_use_owner_account_for_manager', () {
      expect(manager.isManager, true);
      expect(manager.ownerAccountId, 'owner-1');
    });

    test('should_use_own_id_for_owner', () {
      expect(owner.isManager, false);
      expect(owner.ownerAccountId, 'owner-1');
    });

    test('should_clear_manager_fields_when_requested', () {
      final revoked = manager.copyWith(clearManagedAccess: true);

      expect(revoked.isManager, false);
      expect(revoked.managedLibraryIds, isEmpty);
    });
  });
}
