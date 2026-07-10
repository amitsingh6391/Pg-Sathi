import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../domain/core/failure.dart';
import '../../domain/entities/presence.dart';
import '../../domain/failures/presence_failures.dart';
import '../../domain/repositories/presence_repository.dart';
import '../mappers/presence_mapper.dart';
import '../models/presence_dto.dart';
import '../utils/firebase_error_handler.dart';

/// Firebase implementation of PresenceRepository.
class PresenceRepositoryImpl implements PresenceRepository {
  PresenceRepositoryImpl({required this.firestore});

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      firestore.collection(PresenceDto.collectionName);

  @override
  Future<Either<Failure, Presence>> checkIn(Presence presence) async {
    return FirebaseErrorHandler.guard(() async {
      final dto = PresenceMapper.toDto(presence);
      await _collection.doc(presence.id).set(dto.toFirestore());
      return presence;
    });
  }

  @override
  Future<Either<Failure, Presence>> checkOut({
    required String presenceId,
    required DateTime checkOutTime,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      final doc = await _collection.doc(presenceId).get();
      final presence = PresenceMapper.toEntity(PresenceDto.fromFirestore(doc));

      await _collection.doc(presenceId).update({
        'checkOutTime': Timestamp.fromDate(checkOutTime),
        'status': PresenceStatus.checkedOut.name,
      });

      // Return locally-updated entity — no second read needed
      return presence.checkOut(checkOutTime);
    });
  }

  @override
  Future<Either<Failure, Presence>> getPresenceById(String presenceId) async {
    return FirebaseErrorHandler.guard(() async {
      final doc = await _collection.doc(presenceId).get();
      if (!doc.exists) {
        throw const PresenceNotFoundFailure();
      }
      final dto = PresenceDto.fromFirestore(doc);
      return PresenceMapper.toEntity(dto);
    });
  }

  @override
  Future<Either<Failure, Presence?>> getTodayPresenceByUserAndLibrary({
    required String userId,
    required String libraryId,
    required DateTime date,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final query = await _collection
          .where('userId', isEqualTo: userId)
          .where('libraryId', isEqualTo: libraryId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return null;
      }

      final dto = PresenceDto.fromFirestore(query.docs.first);
      return PresenceMapper.toEntity(dto);
    });
  }

  @override
  Future<Either<Failure, List<Presence>>> getPresenceHistoryByUserId({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      final query = await _collection
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('date', descending: true)
          .get();

      return query.docs
          .map((doc) => PresenceMapper.toEntity(PresenceDto.fromFirestore(doc)))
          .toList();
    });
  }

  @override
  Future<Either<Failure, List<Presence>>> getPresenceByLibraryAndDate({
    required String libraryId,
    required DateTime date,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final query = await _collection
          .where('libraryId', isEqualTo: libraryId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      return query.docs
          .map((doc) => PresenceMapper.toEntity(PresenceDto.fromFirestore(doc)))
          .toList();
    });
  }

  @override
  Future<Either<Failure, bool>> hasActivePresence({
    required String userId,
    required String libraryId,
    required DateTime date,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final query = await _collection
          .where('userId', isEqualTo: userId)
          .where('libraryId', isEqualTo: libraryId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .where('status', isEqualTo: PresenceStatus.checkedIn.name)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    });
  }
}
