import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../domain/core/failure.dart';
import '../../domain/entities/seat.dart';
import '../../domain/failures/seat_failures.dart';
import '../../domain/repositories/seat_repository.dart';
import '../mappers/seat_mapper.dart';
import '../models/seat_dto.dart';
import '../utils/firebase_error_handler.dart';

class SeatRepositoryImpl implements SeatRepository {
  SeatRepositoryImpl({required this.firestore});

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      firestore.collection(SeatDto.collectionName);

  @override
  Future<Either<Failure, List<Seat>>> createSeats({
    required String libraryId,
    required int count,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      final batch = firestore.batch();
      final seats = <Seat>[];

      for (int i = 1; i <= count; i++) {
        final seatId = _collection.doc().id;
        final seat = Seat(
          id: seatId,
          libraryId: libraryId,
          seatNumber: 'B$i',
          isActive: true,
        );
        seats.add(seat);

        final dto = SeatMapper.toDto(seat);
        batch.set(_collection.doc(seatId), dto.toFirestore());
      }

      await batch.commit();
      return seats;
    });
  }

  @override
  Future<Either<Failure, Seat>> getSeatById(String seatId) async {
    return FirebaseErrorHandler.guard(() async {
      final doc = await _collection.doc(seatId).get();
      if (!doc.exists) {
        throw const SeatNotFoundFailure();
      }
      final dto = SeatDto.fromFirestore(doc);
      return SeatMapper.toEntity(dto);
    });
  }

  @override
  Future<Either<Failure, List<Seat>>> getSeatsByLibraryId(
    String libraryId,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      // Single where clause - no composite index needed
      final query = await _collection
          .where('libraryId', isEqualTo: libraryId)
          .get();

      // Sort in memory to avoid composite index
      final seats = query.docs
          .map((doc) => SeatMapper.toEntity(SeatDto.fromFirestore(doc)))
          .toList();

      seats.sort((a, b) => a.seatNumber.compareTo(b.seatNumber));
      return seats;
    });
  }

  @override
  Future<Either<Failure, List<Seat>>> getActiveSeatsByLibraryId(
    String libraryId,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      // Single where clause - no composite index needed
      final query = await _collection
          .where('libraryId', isEqualTo: libraryId)
          .get();

      // Filter and sort in memory to avoid composite index
      final seats = query.docs
          .map((doc) => SeatMapper.toEntity(SeatDto.fromFirestore(doc)))
          .where((seat) => seat.isActive)
          .toList();

      seats.sort((a, b) => a.seatNumber.compareTo(b.seatNumber));
      return seats;
    });
  }

  @override
  Future<Either<Failure, Seat>> updateSeat(Seat seat) async {
    return FirebaseErrorHandler.guard(() async {
      final dto = SeatMapper.toDto(seat);
      await _collection.doc(seat.id).update(dto.toFirestore());
      return seat;
    });
  }

  @override
  Future<Either<Failure, void>> deleteSeatsForLibrary(
    String libraryId, {
    int? keepCount,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      // Single where clause - no composite index needed
      final query = await _collection
          .where('libraryId', isEqualTo: libraryId)
          .get();

      // Sort in memory
      final docs = query.docs.toList();
      docs.sort((a, b) {
        final seatA = a.data()['seatNumber'] as String? ?? '';
        final seatB = b.data()['seatNumber'] as String? ?? '';
        return seatA.compareTo(seatB);
      });

      if (keepCount == null || keepCount <= 0) {
        // Delete all seats
        final batch = firestore.batch();
        for (final doc in docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      } else {
        // Keep first N seats, delete rest
        final toDelete = docs.skip(keepCount).toList();
        if (toDelete.isNotEmpty) {
          final batch = firestore.batch();
          for (final doc in toDelete) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
      }
    });
  }
}
