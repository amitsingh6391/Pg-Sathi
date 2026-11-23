import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/data/repositories/manager_repository_impl.dart';
import 'package:pg_manager/domain/entities/manager_access.dart';

void main() {
  const phone = '+919876543210';
  late FakeFirebaseFirestore firestore;
  late ManagerRepositoryImpl repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = ManagerRepositoryImpl(firestore: firestore);
  });

  Future<Map<String, dynamic>?> userData(String id) async =>
      (await firestore.collection('users').doc(id).get()).data();

  Future<Map<String, dynamic>?> inviteData() async =>
      (await firestore.collection('manager_invites').doc(phone).get()).data();

  Future<bool> invite(String libraryId, {String ownerId = 'owner-1'}) async {
    final result = await repository.inviteManager(
      phone: phone,
      ownerId: ownerId,
      libraryId: libraryId,
    );
    return result.isRight();
  }

  group('pending invites', () {
    test('should_invite_number_without_an_account', () async {
      expect(await invite('lib-1'), true);
      final data = await inviteData();
      expect(data?['libraryIds'], ['lib-1']);
      expect(data?['libraryId'], 'lib-1');
    });

    test('should_add_second_branch_to_same_invite', () async {
      await invite('lib-1');
      await invite('lib-2');
      expect((await inviteData())?['libraryIds'], ['lib-1', 'lib-2']);
    });

    test('should_refuse_invite_held_by_another_owner', () async {
      await invite('lib-1');
      expect(await invite('lib-9', ownerId: 'owner-2'), false);
    });

    test('should_delete_invite_after_last_branch_revoked', () async {
      await invite('lib-1');
      await invite('lib-2');
      await repository.revokeManager(
        const ManagerAccess(phone: phone, libraryId: 'lib-1'),
      );
      expect((await inviteData())?['libraryIds'], ['lib-2']);
      await repository.revokeManager(
        const ManagerAccess(phone: phone, libraryId: 'lib-2'),
      );
      expect(await inviteData(), null);
    });
  });

  group('existing accounts', () {
    test('should_convert_student_and_restore_on_revoke', () async {
      await firestore.collection('users').doc('student-1').set({
        'phone': phone,
        'role': 'student',
      });

      expect(await invite('lib-1'), true);
      final converted = await userData('student-1');
      expect(converted?['role'], 'owner');
      expect(converted?['managedByOwnerId'], 'owner-1');
      expect(converted?['managedLibraryIds'], ['lib-1']);

      await repository.revokeManager(
        const ManagerAccess(
          phone: phone,
          libraryId: 'lib-1',
          userId: 'student-1',
        ),
      );
      final restored = await userData('student-1');
      expect(restored?['role'], 'student');
      expect(restored?.containsKey('managedByOwnerId'), false);
    });

    test('should_add_branch_to_legacy_manager', () async {
      await firestore.collection('users').doc('manager-1').set({
        'phone': phone,
        'role': 'owner',
        'managedByOwnerId': 'owner-1',
        'managedLibraryId': 'lib-1',
      });

      expect(await invite('lib-2'), true);
      final data = await userData('manager-1');
      expect(data?['managedLibraryIds'], ['lib-1', 'lib-2']);
      expect(data?['managedLibraryId'], 'lib-1');
      expect(data?.containsKey('preManagerRole'), false);
    });

    test('should_keep_manager_when_one_of_two_branches_revoked', () async {
      await firestore.collection('users').doc('manager-1').set({
        'phone': phone,
        'role': 'owner',
        'managedByOwnerId': 'owner-1',
        'managedLibraryIds': ['lib-1', 'lib-2'],
      });

      await repository.revokeManager(
        const ManagerAccess(
          phone: phone,
          libraryId: 'lib-1',
          userId: 'manager-1',
        ),
      );
      final data = await userData('manager-1');
      expect(data?['managedByOwnerId'], 'owner-1');
      expect(data?['managedLibraryIds'], ['lib-2']);
    });

    test('should_refuse_manager_of_another_owner', () async {
      await firestore.collection('users').doc('manager-1').set({
        'phone': phone,
        'role': 'owner',
        'managedByOwnerId': 'owner-2',
        'managedLibraryIds': ['lib-9'],
      });
      expect(await invite('lib-1'), false);
    });

    test('should_refuse_owner_with_own_libraries', () async {
      await firestore.collection('users').doc('owner-2').set({
        'phone': phone,
        'role': 'owner',
      });
      await firestore.collection('libraries').doc('lib-9').set({
        'ownerId': 'owner-2',
      });
      expect(await invite('lib-1'), false);
    });

    test('should_allow_owner_account_without_libraries', () async {
      await firestore.collection('users').doc('owner-2').set({
        'phone': phone,
        'role': 'owner',
      });
      expect(await invite('lib-1'), true);
      expect((await userData('owner-2'))?['preManagerRole'], 'owner');
    });

    test('should_refuse_inviting_yourself', () async {
      await firestore.collection('users').doc('owner-1').set({
        'phone': phone,
        'role': 'owner',
      });
      expect(await invite('lib-1'), false);
    });
  });

  test('should_list_one_entry_per_branch', () async {
    await firestore.collection('users').doc('manager-1').set({
      'phone': phone,
      'role': 'owner',
      'managedByOwnerId': 'owner-1',
      'managedLibraryIds': ['lib-1', 'lib-2'],
    });

    final result = await repository.getManagers('owner-1');
    final ids = result.getOrElse(() => []).map((a) => a.libraryId);
    expect(ids, ['lib-1', 'lib-2']);
  });
}
