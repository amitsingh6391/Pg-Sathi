import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/attendance.dart';
import '../repositories/attendance_repository.dart';

/// Use case for getting attendance history for a student.
class GetAttendanceHistory
    implements UseCase<List<Attendance>, GetAttendanceHistoryParams> {
  const GetAttendanceHistory({required this.attendanceRepository});

  final AttendanceRepository attendanceRepository;

  @override
  Future<Either<Failure, List<Attendance>>> call(
    GetAttendanceHistoryParams params,
  ) async {
    return attendanceRepository.getAttendanceHistory(
      userId: params.userId,
      libraryId: params.libraryId,
      startDate: params.startDate,
      endDate: params.endDate,
    );
  }
}

/// Parameters for GetAttendanceHistory use case.
class GetAttendanceHistoryParams extends Equatable {
  const GetAttendanceHistoryParams({
    required this.userId,
    required this.libraryId,
    required this.startDate,
    required this.endDate,
  });

  final String userId;
  final String libraryId;
  final DateTime startDate;
  final DateTime endDate;

  /// Get history for last N days.
  factory GetAttendanceHistoryParams.lastDays({
    required String userId,
    required String libraryId,
    required int days,
  }) {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days));
    return GetAttendanceHistoryParams(
      userId: userId,
      libraryId: libraryId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Get history for current month.
  factory GetAttendanceHistoryParams.currentMonth({
    required String userId,
    required String libraryId,
  }) {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, 1);
    return GetAttendanceHistoryParams(
      userId: userId,
      libraryId: libraryId,
      startDate: startDate,
      endDate: now,
    );
  }

  @override
  List<Object?> get props => [userId, libraryId, startDate, endDate];
}
