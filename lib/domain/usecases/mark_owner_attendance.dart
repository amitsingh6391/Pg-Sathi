import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../core/core.dart';
import '../entities/attendance.dart';
import '../entities/slot.dart';
import '../repositories/attendance_repository.dart';

/// Use case for owner to manually mark student attendance.
/// Supports multi-session check-in/check-out flow similar to student self-service.
/// Limited to editing attendance within the last 7 days.
class MarkOwnerAttendance
    implements UseCase<Attendance, MarkOwnerAttendanceParams> {
  const MarkOwnerAttendance({required this.attendanceRepository});

  final AttendanceRepository attendanceRepository;

  /// Maximum days in the past that attendance can be edited.
  static const int maxEditDaysInPast = 7;

  @override
  Future<Either<Failure, Attendance>> call(
    MarkOwnerAttendanceParams params,
  ) async {
    // Validate date is within allowed range
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(
      params.date.year,
      params.date.month,
      params.date.day,
    );
    final daysDiff = today.difference(targetDate).inDays;

    if (daysDiff < 0) {
      return const Left(
        ValidationFailure('Cannot mark attendance for future dates'),
      );
    }

    if (daysDiff > maxEditDaysInPast) {
      return Left(
        ValidationFailure(
          'Cannot edit attendance older than $maxEditDaysInPast days',
        ),
      );
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(params.date);
    final isToday = daysDiff == 0;

    switch (params.action) {
      case AttendanceAction.checkIn:
        return _doCheckIn(params, dateStr, isToday, now);
      case AttendanceAction.checkOut:
        return _doCheckOut(params, dateStr);
      case AttendanceAction.markAbsent:
        return _markAbsent(params, dateStr);
    }
  }

  Future<Either<Failure, Attendance>> _doCheckIn(
    MarkOwnerAttendanceParams params,
    String dateStr,
    bool isToday,
    DateTime now,
  ) async {
    // Check if attendance already exists for this date
    final existingResult = await attendanceRepository.getTodayAttendance(
      userId: params.studentId,
      libraryId: params.libraryId,
      slot: params.slot,
      date: dateStr,
    );

    return existingResult.fold((failure) => Left(failure), (existing) async {
      final sessionId = const Uuid().v4();

      if (existing != null) {
        // Check if there's already an active session
        if (existing.isMultiSession && existing.hasActiveSession) {
          return const Left(ValidationFailure('Student is already checked in'));
        }
        if (!existing.isMultiSession && existing.isCheckedIn) {
          return const Left(ValidationFailure('Student is already checked in'));
        }

        // V2: Add new session to existing attendance
        return attendanceRepository.addSession(
          attendanceId: existing.id,
          sessionId: sessionId,
          distanceFromLibrary: 0, // Owner marking doesn't validate location
        );
      } else {
        // Create new V2 attendance with first session
        final attendanceId =
            '${params.studentId}_${dateStr}_${params.slot.name}';
        final attendance = Attendance.checkInV2(
          id: attendanceId,
          userId: params.studentId,
          libraryId: params.libraryId,
          seatId: params.seatId,
          slot: params.slot,
          date: dateStr,
          sessionId: sessionId,
          distanceFromLibrary: 0, // Owner marking doesn't validate location
        );

        return attendanceRepository.checkIn(attendance);
      }
    });
  }

  Future<Either<Failure, Attendance>> _doCheckOut(
    MarkOwnerAttendanceParams params,
    String dateStr,
  ) async {
    // Get existing attendance
    final existingResult = await attendanceRepository.getTodayAttendance(
      userId: params.studentId,
      libraryId: params.libraryId,
      slot: params.slot,
      date: dateStr,
    );

    return existingResult.fold((failure) => Left(failure), (existing) async {
      if (existing == null) {
        return const Left(ValidationFailure('Student has not checked in yet'));
      }

      // V2: Check for active session
      if (existing.isMultiSession) {
        if (!existing.hasActiveSession) {
          return const Left(
            ValidationFailure('Student has no active session. Check in first.'),
          );
        }
      } else {
        // Legacy: Check status
        if (existing.isCheckedOut) {
          return const Left(
            ValidationFailure('Student has already checked out'),
          );
        }
        if (!existing.isCheckedIn) {
          return const Left(
            ValidationFailure('Student has not checked in yet'),
          );
        }
      }

      // Use repository's checkOut method (handles both V2 and legacy)
      return attendanceRepository.checkOut(
        attendanceId: existing.id,
        distanceFromLibrary: 0, // Owner marking doesn't validate location
      );
    });
  }

  Future<Either<Failure, Attendance>> _markAbsent(
    MarkOwnerAttendanceParams params,
    String dateStr,
  ) async {
    final existingResult = await attendanceRepository.getTodayAttendance(
      userId: params.studentId,
      libraryId: params.libraryId,
      slot: params.slot,
      date: dateStr,
    );

    return existingResult.fold((failure) => Left(failure), (existing) async {
      if (existing == null) {
        // No attendance exists - already absent
        return Right(
          Attendance(
            id: '${params.studentId}_${dateStr}_absent',
            userId: params.studentId,
            libraryId: params.libraryId,
            seatId: params.seatId,
            slot: params.slot,
            date: dateStr,
            status: AttendanceStatus.none,
          ),
        );
      }

      // Delete existing attendance record
      final deleteResult = await attendanceRepository.deleteAttendance(
        attendanceId: existing.id,
      );

      return deleteResult.fold(
        (failure) => Left(failure),
        (_) => Right(
          Attendance(
            id: existing.id,
            userId: params.studentId,
            libraryId: params.libraryId,
            seatId: params.seatId,
            slot: params.slot,
            date: dateStr,
            status: AttendanceStatus.none,
          ),
        ),
      );
    });
  }
}

/// Actions that owner can perform for attendance.
enum AttendanceAction {
  /// Check-in a student (start a new session with current time).
  checkIn,

  /// Check-out a student (complete the active session with current time).
  checkOut,

  /// Mark student as absent (delete all attendance records for the day).
  markAbsent,
}

/// Parameters for MarkOwnerAttendance use case.
class MarkOwnerAttendanceParams extends Equatable {
  const MarkOwnerAttendanceParams({
    required this.libraryId,
    required this.studentId,
    required this.seatId,
    required this.slot,
    required this.date,
    required this.action,
    this.notes,
  });

  final String libraryId;
  final String studentId;
  final String seatId;
  final Slot slot;
  final DateTime date;
  final AttendanceAction action;
  final String? notes;

  @override
  List<Object?> get props => [
    libraryId,
    studentId,
    seatId,
    slot,
    date,
    action,
    notes,
  ];
}

/// Validation failure for attendance operations.
class ValidationFailure extends Failure {
  const ValidationFailure(String message) : super(message: message);
}
