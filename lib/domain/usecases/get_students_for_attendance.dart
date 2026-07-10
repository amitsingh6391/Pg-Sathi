import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

import '../core/core.dart';
import '../entities/attendance.dart';
import '../entities/membership.dart';
import '../entities/user.dart';
import '../repositories/attendance_repository.dart';
import '../repositories/membership_repository.dart';
import '../repositories/user_repository.dart';

/// Use case for getting all students with their attendance status for a date.
/// Used by owner to view and manage attendance.
class GetStudentsForAttendance
    implements
        UseCase<List<StudentAttendanceInfo>, GetStudentsForAttendanceParams> {
  const GetStudentsForAttendance({
    required this.membershipRepository,
    required this.attendanceRepository,
    required this.userRepository,
  });

  final MembershipRepository membershipRepository;
  final AttendanceRepository attendanceRepository;
  final UserRepository userRepository;

  @override
  Future<Either<Failure, List<StudentAttendanceInfo>>> call(
    GetStudentsForAttendanceParams params,
  ) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(params.date);

    // Load memberships and attendance in parallel (they don't depend on each other)
    final results = await Future.wait([
      membershipRepository.getActiveMembershipsForLibrary(params.libraryId),
      attendanceRepository.getLibraryAttendanceByDate(
        libraryId: params.libraryId,
        date: dateStr,
      ),
    ]);

    final membershipResult = results[0] as Either<Failure, List<Membership>>;
    final attendanceResult = results[1] as Either<Failure, List<Attendance>>;

    return membershipResult.fold((failure) => Left(failure), (
      memberships,
    ) async {
      if (memberships.isEmpty) {
        return const Right([]);
      }

      final attendances = attendanceResult.fold(
        (_) => <Attendance>[],
        (list) => list,
      );

      // Create attendance map for O(1) lookup
      final attendanceMap = <String, Attendance>{};
      for (final att in attendances) {
        attendanceMap[att.userId] = att;
      }

      // Collect all userIds for batch fetch (much faster than N individual queries!)
      final userIds = memberships
          .where((m) => m.userId != null)
          .map((m) => m.userId!)
          .toSet()
          .toList();

      // Batch fetch all users at once
      final Map<String, User> userCache = {};
      if (userIds.isNotEmpty) {
        final usersResult = await userRepository.getUsersByIds(userIds);
        usersResult.fold(
          (_) {
            // Failed to fetch users, continue with empty map
          },
          (users) {
            userCache.addAll(users);
          },
        );
      }

      // Build student info list using the pre-fetched users map
      final List<StudentAttendanceInfo> result = [];
      for (final membership in memberships) {
        final userId = membership.userId;
        if (userId == null) continue;

        final user = userCache[userId];
        final attendance = attendanceMap[userId];
        final isPresent =
            attendance != null && attendance.status != AttendanceStatus.none;

        result.add(
          StudentAttendanceInfo(
            studentId: userId,
            studentName:
                user?.displayName ?? membership.studentName ?? 'Unknown',
            studentPhone: user?.phone ?? membership.phoneNumber,
            seatId: membership.assignedSeatId ?? '',
            slotId: membership.slotId,
            attendance: attendance,
            isPresent: isPresent,
            membership: membership,
          ),
        );
      }

      // Sort by name
      result.sort(
        (a, b) =>
            a.studentName.toLowerCase().compareTo(b.studentName.toLowerCase()),
      );

      return Right(result);
    });
  }
}

/// Parameters for GetStudentsForAttendance.
class GetStudentsForAttendanceParams extends Equatable {
  const GetStudentsForAttendanceParams({
    required this.libraryId,
    required this.date,
    this.slotId,
  });

  final String libraryId;
  final DateTime date;
  final String? slotId;

  @override
  List<Object?> get props => [libraryId, date, slotId];
}

/// Student attendance information for owner view.
class StudentAttendanceInfo extends Equatable {
  const StudentAttendanceInfo({
    required this.studentId,
    required this.studentName,
    required this.studentPhone,
    required this.seatId,
    required this.isPresent,
    required this.membership,
    this.slotId,
    this.attendance,
  });

  final String studentId;
  final String studentName;
  final String studentPhone;
  final String seatId;
  final String? slotId;
  final Attendance? attendance;
  final bool isPresent;
  final Membership membership;

  @override
  List<Object?> get props => [
    studentId,
    studentName,
    studentPhone,
    seatId,
    slotId,
    attendance,
    isPresent,
    membership,
  ];
}
