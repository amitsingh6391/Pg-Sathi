import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

import '../core/core.dart';
import '../entities/attendance.dart';
import '../entities/slot.dart';
import '../entities/user.dart';
import '../repositories/attendance_repository.dart';
import '../repositories/user_repository.dart';

/// Use case for getting library attendance (for owner).
/// Returns attendance records with student details.
class GetLibraryAttendance
    implements
        UseCase<List<AttendanceWithStudent>, GetLibraryAttendanceParams> {
  const GetLibraryAttendance({
    required this.attendanceRepository,
    required this.userRepository,
  });

  final AttendanceRepository attendanceRepository;
  final UserRepository userRepository;

  @override
  Future<Either<Failure, List<AttendanceWithStudent>>> call(
    GetLibraryAttendanceParams params,
  ) async {
    final todayDate = _formatDate(params.date);

    // Get attendance records
    final Either<Failure, List<Attendance>> attendanceResult;
    if (params.slot != null) {
      attendanceResult = await attendanceRepository.getLibraryAttendanceBySlot(
        libraryId: params.libraryId,
        date: todayDate,
        slot: params.slot!,
      );
    } else {
      attendanceResult = await attendanceRepository.getLibraryAttendanceByDate(
        libraryId: params.libraryId,
        date: todayDate,
      );
    }

    return attendanceResult.fold((failure) => Left(failure), (
      attendances,
    ) async {
      // Optimized: Batch fetch all users at once instead of N individual queries
      final userIds = attendances.map((a) => a.userId).toSet().toList();
      final usersResult = await userRepository.getUsersByIds(userIds);
      
      final userCache = <String, User>{};
      usersResult.fold(
        (_) {},
        (usersMap) => userCache.addAll(usersMap),
      );

      // Build result with cached users
      final List<AttendanceWithStudent> result = [];
      for (final attendance in attendances) {
        final user = userCache[attendance.userId];
        result.add(
          AttendanceWithStudent(
            attendance: attendance,
            studentName: user?.displayName ?? 'Unknown',
            studentPhone: user?.phone ?? '',
          ),
        );
      }

      // Sort by check-in time (most recent first)
      result.sort((a, b) {
        final aTime = a.attendance.checkInTime ?? DateTime(1970);
        final bTime = b.attendance.checkInTime ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });

      return Right(result);
    });
  }

  String _formatDate(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }
}

/// Parameters for GetLibraryAttendance use case.
class GetLibraryAttendanceParams extends Equatable {
  const GetLibraryAttendanceParams({
    required this.libraryId,
    required this.date,
    this.slot,
  });

  final String libraryId;
  final DateTime date;
  final Slot? slot;

  @override
  List<Object?> get props => [libraryId, date, slot];
}

/// Attendance record with student details.
class AttendanceWithStudent extends Equatable {
  const AttendanceWithStudent({
    required this.attendance,
    required this.studentName,
    required this.studentPhone,
  });

  final Attendance attendance;
  final String studentName;
  final String studentPhone;

  @override
  List<Object?> get props => [attendance, studentName, studentPhone];
}
