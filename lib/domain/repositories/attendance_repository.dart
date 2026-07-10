import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/attendance.dart';
import '../entities/slot.dart';

/// Repository interface for Attendance operations.
/// V2 Update: Added multi-session support.
abstract class AttendanceRepository {
  /// Records a check-in for a student.
  /// For V2 multi-session, creates attendance with first session.
  Future<Either<Failure, Attendance>> checkIn(Attendance attendance);

  /// Records a check-out for a student.
  /// For V2 multi-session, completes the active session.
  Future<Either<Failure, Attendance>> checkOut({
    required String attendanceId,
    required double distanceFromLibrary,
  });

  /// V2: Adds a new session to an existing attendance record.
  /// Use this when a student checks in again after checking out.
  Future<Either<Failure, Attendance>> addSession({
    required String attendanceId,
    required String sessionId,
    required double distanceFromLibrary,
  });

  /// Gets today's attendance for a user in a specific library and slot.
  Future<Either<Failure, Attendance?>> getTodayAttendance({
    required String userId,
    required String libraryId,
    required Slot slot,
    required String date,
  });

  /// Gets all attendance records for a user on a specific date.
  Future<Either<Failure, List<Attendance>>> getUserAttendanceByDate({
    required String userId,
    required String date,
  });

  /// Gets all attendance records for a library on a specific date.
  /// Used by owner to view today's attendance.
  Future<Either<Failure, List<Attendance>>> getLibraryAttendanceByDate({
    required String libraryId,
    required String date,
  });

  /// Gets attendance records for a library filtered by slot.
  Future<Either<Failure, List<Attendance>>> getLibraryAttendanceBySlot({
    required String libraryId,
    required String date,
    required Slot slot,
  });

  /// Stream of today's attendance for a library (real-time updates for owner).
  Stream<Either<Failure, List<Attendance>>> watchLibraryAttendance({
    required String libraryId,
    required String date,
  });

  /// Gets attendance by ID.
  Future<Either<Failure, Attendance?>> getAttendanceById(String attendanceId);

  /// Gets attendance history for a user in a library within a date range.
  /// Returns completed attendance records (checked in and out).
  Future<Either<Failure, List<Attendance>>> getAttendanceHistory({
    required String userId,
    required String libraryId,
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Gets attendance for a user in a library for a specific date range.
  /// Used for calculating stats.
  Future<Either<Failure, List<Attendance>>> getAttendanceForPeriod({
    required String userId,
    required String libraryId,
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Gets all attendance records for a library within a date range.
  /// Used for owner analytics.
  Future<Either<Failure, List<Attendance>>> getLibraryAttendanceForPeriod({
    required String libraryId,
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Deletes an attendance record.
  /// Used by owner to mark a student as absent (remove attendance).
  Future<Either<Failure, void>> deleteAttendance({
    required String attendanceId,
  });

  /// Bulk marks attendance for multiple students.
  /// Used by owner to efficiently mark present/absent for a group.
  Future<Either<Failure, List<Attendance>>> bulkMarkAttendance({
    required String libraryId,
    required String date,
    required List<BulkAttendanceEntry> entries,
  });
}

/// Entry for bulk attendance marking.
class BulkAttendanceEntry {
  const BulkAttendanceEntry({
    required this.studentId,
    required this.seatId,
    required this.slotId,
    required this.isPresent,
  });

  final String studentId;
  final String seatId;
  final String slotId;
  final bool isPresent;
}
