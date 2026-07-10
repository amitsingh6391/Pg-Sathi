import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

import '../core/core.dart';
import '../entities/attendance.dart';
import '../entities/slot.dart';
import '../repositories/attendance_repository.dart';

/// Use case for getting today's attendance for a user.
class GetTodayAttendance
    implements UseCase<Attendance?, GetTodayAttendanceParams> {
  const GetTodayAttendance({required this.attendanceRepository});

  final AttendanceRepository attendanceRepository;

  @override
  Future<Either<Failure, Attendance?>> call(
    GetTodayAttendanceParams params,
  ) async {
    final todayDate = _formatDate(params.date);

    return attendanceRepository.getTodayAttendance(
      userId: params.userId,
      libraryId: params.libraryId,
      slot: params.slot,
      date: todayDate,
    );
  }

  String _formatDate(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }
}

/// Parameters for GetTodayAttendance use case.
class GetTodayAttendanceParams extends Equatable {
  const GetTodayAttendanceParams({
    required this.userId,
    required this.libraryId,
    required this.slot,
    required this.date,
  });

  final String userId;
  final String libraryId;
  final Slot slot;
  final DateTime date;

  @override
  List<Object?> get props => [userId, libraryId, slot, date];
}
