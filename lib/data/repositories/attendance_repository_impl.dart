import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../domain/core/failure.dart';
import '../../domain/entities/attendance.dart';
import '../../domain/entities/slot.dart';
import '../../domain/failures/attendance_failures.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../failures/data_failures.dart';
import '../mappers/attendance_mapper.dart';
import '../models/attendance_dto.dart';

/// Firestore implementation of AttendanceRepository.
/// V2 Update: Supports multi-session check-in/check-out.
class AttendanceRepositoryImpl implements AttendanceRepository {
  AttendanceRepositoryImpl({
    required FirebaseFirestore firestore,
    AttendanceMapper? mapper,
  }) : _firestore = firestore,
       _mapper = mapper ?? const AttendanceMapper();

  final FirebaseFirestore _firestore;
  final AttendanceMapper _mapper;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(AttendanceDto.collectionName);

  @override
  Future<Either<Failure, Attendance>> checkIn(Attendance attendance) async {
    try {
      final dto = _mapper.toDto(attendance);
      await _collection.doc(attendance.id).set(dto.toFirestore());
      return Right(attendance);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Attendance>> checkOut({
    required String attendanceId,
    required double distanceFromLibrary,
  }) async {
    try {
      final doc = await _collection.doc(attendanceId).get();
      if (!doc.exists) {
        return const Left(AttendanceNotFoundFailure());
      }

      final dto = AttendanceDto.fromFirestore(doc);
      final attendance = _mapper.toEntity(dto);
      final updatedAttendance = attendance.checkOut(
        distanceFromLibrary: distanceFromLibrary,
      );

      // V2: Handle multi-session or legacy single-session checkout
      if (updatedAttendance.isMultiSession) {
        // Update with full sessions array for V2 records
        final updatedDto = _mapper.toDto(updatedAttendance);
        await _collection.doc(attendanceId).update({
          'status': updatedAttendance.status.name,
          'sessions': updatedDto.sessions.map((s) => s.toMap()).toList(),
        });
      } else {
        // Legacy single-session update
        await _collection.doc(attendanceId).update({
          'status': updatedAttendance.status.name,
          'checkOutTime': Timestamp.fromDate(updatedAttendance.checkOutTime!),
          'checkOutDistance': distanceFromLibrary,
        });
      }

      return Right(updatedAttendance);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Attendance>> addSession({
    required String attendanceId,
    required String sessionId,
    required double distanceFromLibrary,
  }) async {
    try {
      final doc = await _collection.doc(attendanceId).get();
      if (!doc.exists) {
        return const Left(AttendanceNotFoundFailure());
      }

      final dto = AttendanceDto.fromFirestore(doc);
      final attendance = _mapper.toEntity(dto);

      // Add new session
      final updatedAttendance = attendance.addSession(
        sessionId: sessionId,
        distanceFromLibrary: distanceFromLibrary,
      );

      // Update Firestore with new sessions array
      final updatedDto = _mapper.toDto(updatedAttendance);
      await _collection.doc(attendanceId).update({
        'status': updatedAttendance.status.name,
        'sessions': updatedDto.sessions.map((s) => s.toMap()).toList(),
      });

      return Right(updatedAttendance);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Attendance?>> getTodayAttendance({
    required String userId,
    required String libraryId,
    required Slot slot,
    required String date,
  }) async {
    try {
      final query = await _collection
          .where('userId', isEqualTo: userId)
          .where('libraryId', isEqualTo: libraryId)
          .where('slot', isEqualTo: slot.name)
          .where('date', isEqualTo: date)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return const Right(null);
      }

      final dto = AttendanceDto.fromFirestore(query.docs.first);
      return Right(_mapper.toEntity(dto));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Attendance>>> getUserAttendanceByDate({
    required String userId,
    required String date,
  }) async {
    try {
      final query = await _collection
          .where('userId', isEqualTo: userId)
          .where('date', isEqualTo: date)
          .get();

      final attendances = query.docs
          .map((doc) => _mapper.toEntity(AttendanceDto.fromFirestore(doc)))
          .toList();

      return Right(attendances);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Attendance>>> getLibraryAttendanceByDate({
    required String libraryId,
    required String date,
  }) async {
    try {
      final query = await _collection
          .where('libraryId', isEqualTo: libraryId)
          .where('date', isEqualTo: date)
          .get();

      final attendances = query.docs
          .map((doc) => _mapper.toEntity(AttendanceDto.fromFirestore(doc)))
          .toList();

      return Right(attendances);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Attendance>>> getLibraryAttendanceBySlot({
    required String libraryId,
    required String date,
    required Slot slot,
  }) async {
    try {
      final query = await _collection
          .where('libraryId', isEqualTo: libraryId)
          .where('date', isEqualTo: date)
          .where('slot', isEqualTo: slot.name)
          .get();

      final attendances = query.docs
          .map((doc) => _mapper.toEntity(AttendanceDto.fromFirestore(doc)))
          .toList();

      return Right(attendances);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Stream<Either<Failure, List<Attendance>>> watchLibraryAttendance({
    required String libraryId,
    required String date,
  }) {
    return _collection
        .where('libraryId', isEqualTo: libraryId)
        .where('date', isEqualTo: date)
        .snapshots()
        .map((snapshot) {
          try {
            final attendances = snapshot.docs
                .map(
                  (doc) => _mapper.toEntity(AttendanceDto.fromFirestore(doc)),
                )
                .toList();
            return Right<Failure, List<Attendance>>(attendances);
          } catch (e) {
            return Left<Failure, List<Attendance>>(
              ServerFailure(message: e.toString()),
            );
          }
        });
  }

  @override
  Future<Either<Failure, Attendance?>> getAttendanceById(
    String attendanceId,
  ) async {
    try {
      final doc = await _collection.doc(attendanceId).get();
      if (!doc.exists) {
        return const Right(null);
      }

      final dto = AttendanceDto.fromFirestore(doc);
      return Right(_mapper.toEntity(dto));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Attendance>>> getAttendanceHistory({
    required String userId,
    required String libraryId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final startDateStr = _formatDate(startDate);
      final endDateStr = _formatDate(endDate);

      // V2 Update: Removed status filter to include ALL attendance records
      // (both checked-in and checked-out) for multi-session support.
      // This ensures today's active attendance and multi-session records are included.
      // Requires composite index: userId (asc), libraryId (asc), date (desc)
      final query = await _collection
          .where('userId', isEqualTo: userId)
          .where('libraryId', isEqualTo: libraryId)
          .where('date', isGreaterThanOrEqualTo: startDateStr)
          .where('date', isLessThanOrEqualTo: endDateStr)
          .orderBy('date', descending: true)
          .get();

      final attendances = query.docs
          .map((doc) => _mapper.toEntity(AttendanceDto.fromFirestore(doc)))
          .toList();

      return Right(attendances);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Attendance>>> getAttendanceForPeriod({
    required String userId,
    required String libraryId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final startDateStr = _formatDate(startDate);
      final endDateStr = _formatDate(endDate);

      // Optimized query using composite index:
      // userId (asc), libraryId (asc), date (desc)
      final query = await _collection
          .where('userId', isEqualTo: userId)
          .where('libraryId', isEqualTo: libraryId)
          .where('date', isGreaterThanOrEqualTo: startDateStr)
          .where('date', isLessThanOrEqualTo: endDateStr)
          .orderBy('date', descending: true)
          .get();

      final attendances = query.docs
          .map((doc) => _mapper.toEntity(AttendanceDto.fromFirestore(doc)))
          .toList();

      return Right(attendances);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Attendance>>> getLibraryAttendanceForPeriod({
    required String libraryId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final startDateStr = _formatDate(startDate);
      final endDateStr = _formatDate(endDate);

      // Query by libraryId and date range
      // Requires composite index: libraryId (asc), date (desc)
      final query = await _collection
          .where('libraryId', isEqualTo: libraryId)
          .where('date', isGreaterThanOrEqualTo: startDateStr)
          .where('date', isLessThanOrEqualTo: endDateStr)
          .orderBy('date', descending: true)
          .get();

      final attendances = query.docs
          .map((doc) => _mapper.toEntity(AttendanceDto.fromFirestore(doc)))
          .toList();

      return Right(attendances);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Future<Either<Failure, void>> deleteAttendance({
    required String attendanceId,
  }) async {
    try {
      await _collection.doc(attendanceId).delete();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Attendance>>> bulkMarkAttendance({
    required String libraryId,
    required String date,
    required List<BulkAttendanceEntry> entries,
  }) async {
    try {
      final batch = _firestore.batch();
      final results = <Attendance>[];

      for (final entry in entries) {
        final attendanceId = '${entry.studentId}_${date}_${entry.slotId}';

        if (entry.isPresent) {
          // Create/update attendance record
          final attendance = Attendance(
            id: attendanceId,
            userId: entry.studentId,
            libraryId: libraryId,
            seatId: entry.seatId,
            slot: Slot.morning, // Default, actual slot is tracked via slotId
            date: date,
            status: AttendanceStatus.checkedOut,
            checkInTime: DateTime.now(),
            checkOutTime: DateTime.now(),
            checkInDistance: 0,
            checkOutDistance: 0,
            createdAt: DateTime.now(),
          );

          final dto = _mapper.toDto(attendance);
          batch.set(_collection.doc(attendanceId), dto.toFirestore());
          results.add(attendance);
        } else {
          // Delete attendance record if marking absent
          batch.delete(_collection.doc(attendanceId));
        }
      }

      await batch.commit();
      return Right(results);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
