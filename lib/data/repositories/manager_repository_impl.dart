import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../domain/core/failure.dart';
import '../../domain/entities/manager_access.dart';
import '../../domain/failures/user_failures.dart';
import '../../domain/repositories/manager_repository.dart';
import '../models/library_dto.dart';
import '../models/user_dto.dart';
import '../utils/firebase_error_handler.dart';

/// Firestore implementation of ManagerRepository.
/// Numbers without an account get a pending `manager_invites/{phone}` doc;
/// existing accounts are converted directly and keep their prior role.
class ManagerRepositoryImpl implements ManagerRepository {
  ManagerRepositoryImpl({required this.firestore});

  final FirebaseFirestore firestore;

  static const _inviteIds = 'libraryIds';
  static const _inviteLegacyId = 'libraryId';
  static const _preManagerRole = 'preManagerRole';

  CollectionReference<Map<String, dynamic>> get _invites =>
      firestore.collection('manager_invites');

  CollectionReference<Map<String, dynamic>> get _users =>
      firestore.collection(UserDto.collectionName);

  @override
  Future<Either<Failure, void>> inviteManager({
    required String phone,
    required String ownerId,
    required String libraryId,
  }) async {
    final result = await FirebaseErrorHandler.guard(
      () => _grantAccess(phone, ownerId, libraryId),
    );
    return result.flatMap(
      (reason) => reason == null
          ? const Right(null)
          : Left(ManagerNumberInUseFailure(message: reason)),
    );
  }

  /// Returns why access can't be granted, or null once it is.
  Future<String?> _grantAccess(
    String phone,
    String ownerId,
    String libraryId,
  ) async {
    final users = await _users.where('phone', isEqualTo: phone).get();
    if (users.docs.isEmpty) return _upsertInvite(phone, ownerId, libraryId);

    for (final doc in users.docs) {
      final reason = await _blockReason(doc, ownerId);
      if (reason != null) return reason;
    }

    final batch = firestore.batch();
    for (final doc in users.docs) {
      final data = doc.data();
      final ids = {...UserDto.readManagedLibraryIds(data), libraryId}.toList();
      batch.update(doc.reference, {
        'role': 'owner',
        'managedByOwnerId': ownerId,
        'managedLibraryIds': ids,
        'managedLibraryId': ids.first,
        if (data['managedByOwnerId'] == null)
          _preManagerRole: data['role'] ?? 'student',
      });
    }
    await batch.commit();
    return null;
  }

  Future<String?> _upsertInvite(
    String phone,
    String ownerId,
    String libraryId,
  ) async {
    final invite = await _invites.doc(phone).get();
    final data = invite.data();
    if (data != null && data['ownerId'] != ownerId) {
      return 'This number is already invited by another PG owner.';
    }
    final ids = {..._readInviteIds(data), libraryId}.toList();
    await _invites.doc(phone).set({
      'ownerId': ownerId,
      _inviteIds: ids,
      _inviteLegacyId: ids.first,
      'createdAt': data?['createdAt'] ?? FieldValue.serverTimestamp(),
    });
    return null;
  }

  /// Why [doc] can't become [ownerId]'s manager, or null when it can.
  Future<String?> _blockReason(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String ownerId,
  ) async {
    final data = doc.data();
    if (doc.id == ownerId) return "You can't add yourself as a manager.";

    final managedBy = data['managedByOwnerId'];
    if (managedBy == ownerId) return null;
    if (managedBy != null) {
      return "This number already manages another owner's PG.";
    }

    final role = data['role'];
    if (role == 'admin') return const ManagerNumberInUseFailure().message;
    if (role != 'owner') return null;

    final owned = await firestore
        .collection(LibraryDto.collectionName)
        .where('ownerId', isEqualTo: doc.id)
        .limit(1)
        .get();
    return owned.docs.isEmpty
        ? null
        : 'This number is a PG owner account and has its own PG.';
  }

  @override
  Future<Either<Failure, List<ManagerAccess>>> getManagers(
    String ownerId,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      final invites = await _invites.where('ownerId', isEqualTo: ownerId).get();
      final managers = await _users
          .where('managedByOwnerId', isEqualTo: ownerId)
          .get();

      return [
        for (final doc in invites.docs)
          for (final libraryId in _readInviteIds(doc.data()))
            ManagerAccess(phone: doc.id, libraryId: libraryId),
        for (final doc in managers.docs)
          for (final libraryId in UserDto.readManagedLibraryIds(doc.data()))
            ManagerAccess(
              phone: doc.data()['phone'] as String? ?? '',
              libraryId: libraryId,
              userId: doc.id,
              name: doc.data()['name'] as String?,
            ),
      ];
    });
  }

  @override
  Future<Either<Failure, void>> revokeManager(ManagerAccess access) async {
    return FirebaseErrorHandler.guard(() async {
      if (access.isPending) {
        final ref = _invites.doc(access.phone);
        final ids = _readInviteIds((await ref.get()).data())
          ..remove(access.libraryId);
        if (ids.isEmpty) {
          await ref.delete();
        } else {
          await ref.update({_inviteIds: ids, _inviteLegacyId: ids.first});
        }
        return;
      }

      final ref = _users.doc(access.userId);
      final data = (await ref.get()).data();
      final ids = UserDto.readManagedLibraryIds(data).toList()
        ..remove(access.libraryId);
      if (ids.isNotEmpty) {
        await ref.update({
          'managedLibraryIds': ids,
          'managedLibraryId': ids.first,
        });
        return;
      }
      final previousRole = data?[_preManagerRole];
      await ref.update({
        'managedByOwnerId': FieldValue.delete(),
        'managedLibraryIds': FieldValue.delete(),
        'managedLibraryId': FieldValue.delete(),
        _preManagerRole: FieldValue.delete(),
        'role': ?previousRole,
      });
    });
  }

  List<String> _readInviteIds(Map<String, dynamic>? data) =>
      UserDto.readManagedLibraryIds(
        data,
        listKey: _inviteIds,
        legacyKey: _inviteLegacyId,
      ).toList();
}
