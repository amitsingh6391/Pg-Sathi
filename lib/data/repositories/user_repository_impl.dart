import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../domain/core/failure.dart';
import '../../domain/entities/user.dart';
import '../../domain/failures/user_failures.dart';
import '../../domain/repositories/user_repository.dart';
import '../mappers/user_mapper.dart';
import '../models/user_dto.dart';
import '../utils/firebase_error_handler.dart';

/// Firebase implementation of UserRepository.
class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl({required this.firestore});

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      firestore.collection(UserDto.collectionName);

  @override
  Future<Either<Failure, User>> createUser(User user) async {
    return FirebaseErrorHandler.guard(() async {
      final dto = UserMapper.toDto(user);
      await _collection.doc(user.id).set(dto.toFirestore());
      return user;
    });
  }

  @override
  Future<Either<Failure, User>> getUserById(String userId) async {
    return FirebaseErrorHandler.guard(() async {
      final doc = await _collection.doc(userId).get();
      if (!doc.exists) {
        throw const UserNotFoundFailure();
      }
      final dto = UserDto.fromFirestore(doc);
      return UserMapper.toEntity(dto);
    });
  }

  @override
  Future<Either<Failure, User?>> getUserByEmail(String email) async {
    return FirebaseErrorHandler.guard(() async {
      final query = await _collection.where('email', isEqualTo: email).get();
      if (query.docs.isEmpty) {
        return null;
      }
      final dto = UserDto.fromFirestore(query.docs.first);
      return UserMapper.toEntity(dto);
    });
  }

  @override
  Future<Either<Failure, User?>> getUserByPhone(String phone) async {
    return FirebaseErrorHandler.guard(() async {
      final query = await _collection.where('phone', isEqualTo: phone).get();
      if (query.docs.isEmpty) {
        return null;
      }
      final dto = UserDto.fromFirestore(query.docs.first);
      return UserMapper.toEntity(dto);
    });
  }

  @override
  Future<Either<Failure, User>> updateUser(User user) async {
    return FirebaseErrorHandler.guard(() async {
      final dto = UserMapper.toDto(user);
      await _collection.doc(user.id).update(dto.toFirestore());
      return user;
    });
  }

  @override
  Future<Either<Failure, Map<String, User>>> getUsersByIds(
    List<String> userIds,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      if (userIds.isEmpty) {
        return <String, User>{};
      }

      // OPTIMIZED: Use whereIn queries instead of individual doc().get() calls
      // This reduces the number of round trips and is more efficient
      // Firestore has a limit of 10 items per 'in' query
      final batchSize = 10;
      final Map<String, User> usersMap = {};

      // Process batches in parallel for maximum performance
      final futures = <Future<void>>[];
      for (var i = 0; i < userIds.length; i += batchSize) {
        final batch = userIds.skip(i).take(batchSize).toList();
        futures.add(
          _collection.where(FieldPath.documentId, whereIn: batch).get().then((
            snapshot,
          ) {
            for (final doc in snapshot.docs) {
              final dto = UserDto.fromFirestore(doc);
              final user = UserMapper.toEntity(dto);
              usersMap[user.id] = user;
            }
          }),
        );
      }

      await Future.wait(futures);
      return usersMap;
    });
  }

  @override
  Future<Either<Failure, bool>> userExists(String userId) async {
    return FirebaseErrorHandler.guard(() async {
      final doc = await _collection.doc(userId).get();
      return doc.exists;
    });
  }

  @override
  Future<Either<Failure, List<User>>> getUsersByRole(UserRole role) async {
    return FirebaseErrorHandler.guard(() async {
      final roleStr = role.name;
      final query = await _collection.where('role', isEqualTo: roleStr).get();

      return query.docs.map((doc) {
        final dto = UserDto.fromFirestore(doc);
        return UserMapper.toEntity(dto);
      }).toList();
    });
  }

  @override
  Future<Either<Failure, void>> deleteUser(String userId) async {
    return FirebaseErrorHandler.guard(() async {
      await _collection.doc(userId).delete();
    });
  }
}
