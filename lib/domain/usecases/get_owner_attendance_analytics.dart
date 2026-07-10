import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

import '../core/core.dart';
import '../entities/attendance.dart';
import '../entities/custom_slot.dart';
import '../entities/library.dart';
import '../entities/membership.dart';
import '../entities/owner_attendance_analytics.dart';
import '../entities/slot.dart';
import '../entities/user.dart';
import '../repositories/attendance_repository.dart';
import '../repositories/library_repository.dart';
import '../repositories/membership_repository.dart';
import '../repositories/slot_repository.dart';
import '../repositories/user_repository.dart';

/// Use case for getting owner attendance analytics.
/// Aggregates attendance data for a library dashboard.
class GetOwnerAttendanceAnalytics
    implements
        UseCase<OwnerAttendanceSummary, GetOwnerAttendanceAnalyticsParams> {
  const GetOwnerAttendanceAnalytics({
    required this.attendanceRepository,
    required this.membershipRepository,
    required this.libraryRepository,
    required this.userRepository,
    required this.slotRepository,
  });

  final AttendanceRepository attendanceRepository;
  final MembershipRepository membershipRepository;
  final LibraryRepository libraryRepository;
  final UserRepository userRepository;
  final SlotRepository slotRepository;

  @override
  Future<Either<Failure, OwnerAttendanceSummary>> call(
    GetOwnerAttendanceAnalyticsParams params,
  ) async {
    final today = DateTime.now();
    final todayStr = _formatDate(today);

    // Optimized: Load library, slots, and memberships in parallel
    final results = await Future.wait([
      libraryRepository.getLibraryById(params.libraryId),
      slotRepository.getActiveSlotsByLibraryId(params.libraryId),
      membershipRepository.getActiveMembershipsForLibrary(params.libraryId),
    ]);

    final libraryResult = results[0] as Either<Failure, Library?>;
    final slotsResult = results[1] as Either<Failure, List<CustomSlot>>;
    final membershipsResult = results[2] as Either<Failure, List<Membership>>;

    Library? library;
    libraryResult.fold((_) {}, (lib) => library = lib);

    List<CustomSlot> customSlots = [];
    slotsResult.fold((_) {}, (slots) => customSlots = slots);

    return membershipsResult.fold((failure) => Left(failure), (
      activeMemberships,
    ) async {
      final totalMembers = activeMemberships.length;

      // Optimized: Fetch today's attendance and period attendance in parallel
      final periodStart = today.subtract(
        Duration(days: params.periodDays - 1),
      );
      
      final attendanceResults = await Future.wait([
        attendanceRepository.getLibraryAttendanceByDate(
          libraryId: params.libraryId,
          date: todayStr,
        ),
        attendanceRepository.getLibraryAttendanceForPeriod(
          libraryId: params.libraryId,
          startDate: periodStart,
          endDate: today,
        ),
      ]);

      final todayAttendanceResult = attendanceResults[0];
      final periodAttendanceResult = attendanceResults[1];

      return todayAttendanceResult.fold((failure) => Left(failure), (
        todayAttendance,
      ) async {
        // 4. Calculate today's stats
        final presentToday = todayAttendance
            .where((a) => a.status != AttendanceStatus.none)
            .map((a) => a.userId)
            .toSet()
            .length;
        final absentToday = totalMembers - presentToday;

        return periodAttendanceResult.fold((failure) => Left(failure), (
          periodAttendance,
        ) async {
          // 6. Calculate slot-wise summaries
          final slotSummaries = _calculateSlotSummaries(
            todayAttendance,
            library,
          );

          // 7. Calculate daily trend
          final dailyTrend = _calculateDailyTrend(
            periodAttendance,
            periodStart,
            today,
            totalMembers,
          );

          // 8. Calculate average attendance percentage
          final avgAttendance = _calculateAverageAttendance(dailyTrend);

          // 9. Calculate average time spent
          final avgTimeSpent = _calculateAverageTimeSpent(periodAttendance);

          // 10. Build student records for today
          final studentRecords = await _buildStudentRecords(
            todayAttendance,
            activeMemberships,
            customSlots,
          );

          return Right(
            OwnerAttendanceSummary(
              libraryId: params.libraryId,
              date: todayStr,
              totalMembers: totalMembers,
              presentToday: presentToday,
              absentToday: absentToday,
              avgAttendancePercent: avgAttendance,
              avgTimeSpentMinutes: avgTimeSpent,
              slotSummaries: slotSummaries,
              dailyTrend: dailyTrend,
              studentRecords: studentRecords,
            ),
          );
        });
      });
    });
  }

  /// V2: Updated to handle multi-session attendance properly.
  List<SlotAttendanceSummary> _calculateSlotSummaries(
    List<Attendance> todayAttendance,
    Library? library,
  ) {
    final summaries = <SlotAttendanceSummary>[];

    for (final slot in Slot.values) {
      final slotAttendance = todayAttendance
          .where((a) => a.slot == slot)
          .toList();
      final presentCount = slotAttendance
          .where((a) => a.status != AttendanceStatus.none)
          .length;

      // Get total seats (same for all slots now)
      final totalSeats = library?.capacity ?? 0;

      // V2: Calculate average time using totalCompletedMinutes for multi-session
      final attendanceWithTime = slotAttendance
          .where(
            (a) =>
                a.isCheckedOut ||
                (a.isMultiSession && a.completedSessionCount > 0),
          )
          .toList();
      int avgTime = 0;
      if (attendanceWithTime.isNotEmpty) {
        final totalMinutes = attendanceWithTime
            .map((a) => a.totalCompletedMinutes)
            .reduce((a, b) => a + b);
        avgTime = totalMinutes ~/ attendanceWithTime.length;
      }

      summaries.add(
        SlotAttendanceSummary(
          slot: slot,
          presentCount: presentCount,
          totalSeats: totalSeats,
          avgTimeSpentMinutes: avgTime,
        ),
      );
    }

    return summaries;
  }

  List<AttendanceTrendPoint> _calculateDailyTrend(
    List<Attendance> periodAttendance,
    DateTime startDate,
    DateTime endDate,
    int totalMembers,
  ) {
    final trend = <AttendanceTrendPoint>[];
    final dateFormat = DateFormat('EEE');

    for (
      var date = startDate;
      !date.isAfter(endDate);
      date = date.add(const Duration(days: 1))
    ) {
      final dateStr = _formatDate(date);
      final dayLabel = dateFormat.format(date);

      // Count unique users present on this date
      final presentCount = periodAttendance
          .where((a) => a.date == dateStr && a.status != AttendanceStatus.none)
          .map((a) => a.userId)
          .toSet()
          .length;

      trend.add(
        AttendanceTrendPoint(
          date: dateStr,
          dayLabel: dayLabel,
          presentCount: presentCount,
          totalMembers: totalMembers,
        ),
      );
    }

    return trend;
  }

  double _calculateAverageAttendance(List<AttendanceTrendPoint> trend) {
    if (trend.isEmpty) return 0;
    final totalPercent = trend
        .map((t) => t.attendancePercent)
        .reduce((a, b) => a + b);
    return totalPercent / trend.length;
  }

  /// V2: Updated to use totalCompletedMinutes for multi-session attendance.
  int _calculateAverageTimeSpent(List<Attendance> attendance) {
    // Group by user+date to handle multi-session properly
    final completedAttendance = attendance
        .where(
          (a) =>
              a.isCheckedOut ||
              (a.isMultiSession && a.completedSessionCount > 0),
        )
        .toList();
    if (completedAttendance.isEmpty) return 0;

    // Use totalCompletedMinutes for accurate multi-session totals
    final totalMinutes = completedAttendance
        .map((a) => a.totalCompletedMinutes)
        .reduce((a, b) => a + b);
    return totalMinutes ~/ completedAttendance.length;
  }

  /// V2: Updated to support multi-session attendance records.
  /// Optimized: Batch fetches users to avoid N+1 query problem.
  Future<List<StudentAttendanceRecord>> _buildStudentRecords(
    List<Attendance> todayAttendance,
    List<Membership> activeMemberships,
    List<CustomSlot> customSlots,
  ) async {
    final records = <StudentAttendanceRecord>[];

    // Build a map from slotId to slot name for quick lookup
    final slotNameMap = <String, String>{};
    for (final slot in customSlots) {
      slotNameMap[slot.id] = slot.name;
    }

    // Collect all unique user IDs that need to be fetched
    final userIdsToFetch = <String>{};
    for (final attendance in todayAttendance) {
      userIdsToFetch.add(attendance.userId);
    }
    for (final membership in activeMemberships) {
      if (membership.userId != null) {
        userIdsToFetch.add(membership.userId!);
      }
    }

    // Batch fetch all users at once (optimized: single query instead of N queries)
    final userCache = <String, User>{};
    if (userIdsToFetch.isNotEmpty) {
      final usersResult = await userRepository.getUsersByIds(
        userIdsToFetch.toList(),
      );
      usersResult.fold(
        (_) {},
        (usersMap) => userCache.addAll(usersMap),
      );
    }

    // Helper to get user from cache
    User? getUser(String userId) => userCache[userId];

    // Helper to get slot name from membership
    String? getSlotName(Membership? membership) {
      if (membership == null) return null;
      if (membership.slotId != null &&
          slotNameMap.containsKey(membership.slotId)) {
        return slotNameMap[membership.slotId];
      }
      return null;
    }

    // Create membership lookup by userId
    final membershipByUserId = <String, Membership>{};
    for (final m in activeMemberships) {
      if (m.userId != null) {
        membershipByUserId[m.userId!] = m;
      }
    }

    // First, add records for students who have attendance today
    for (final attendance in todayAttendance) {
      final user = getUser(attendance.userId);
      final membership = membershipByUserId[attendance.userId];
      final slotName = getSlotName(membership);

      // V2: Build session records for multi-session attendance
      final sessionRecords = <StudentSessionRecord>[];
      if (attendance.isMultiSession) {
        for (final session in attendance.sessions) {
          sessionRecords.add(
            StudentSessionRecord(
              sessionId: session.sessionId,
              checkInAt: session.checkInAt,
              checkOutAt: session.checkOutAt,
              durationMinutes: session.durationMinutes,
            ),
          );
        }
      }

      records.add(
        StudentAttendanceRecord(
          userId: attendance.userId,
          studentName: user?.displayName ?? 'Unknown',
          seatNumber: attendance.seatId,
          slot: attendance.slot,
          slotName: slotName,
          status: attendance.status,
          checkInTime: attendance.firstCheckInTime,
          checkOutTime: attendance.lastCheckOutTime,
          durationMinutes: attendance.isMultiSession
              ? attendance.activeSession?.currentDurationMinutes
              : attendance.sessionDurationMinutes,
          sessionCount: attendance.isMultiSession ? attendance.sessionCount : 1,
          totalMinutes: attendance.totalCompletedMinutes,
          sessions: sessionRecords,
        ),
      );
    }

    // Add absent members (those with membership but no attendance today)
    final presentUserIds = todayAttendance.map((a) => a.userId).toSet();
    for (final membership in activeMemberships) {
      // Skip unregistered memberships (no userId)
      if (membership.userId == null) continue;

      // Skip if already present
      if (presentUserIds.contains(membership.userId)) continue;

      // Need either slot or slotId
      if (membership.slot == null && membership.slotId == null) continue;

      final user = getUser(membership.userId!);
      final slotName = getSlotName(membership);

      records.add(
        StudentAttendanceRecord(
          userId: membership.userId!,
          studentName: user?.displayName ?? membership.phoneNumber,
          seatNumber: membership.assignedSeatId ?? '-',
          slot: membership.slot ?? Slot.morning,
          slotName: slotName,
          status: AttendanceStatus.none,
        ),
      );
    }

    // Sort: active sessions first, then checked out, then absent
    records.sort((a, b) {
      // Active sessions first
      if (a.hasActiveSession && !b.hasActiveSession) return -1;
      if (!a.hasActiveSession && b.hasActiveSession) return 1;
      // Then present (checked out)
      if (a.isPresent && !b.isPresent) return -1;
      if (!a.isPresent && b.isPresent) return 1;
      // Finally by name
      return a.studentName.compareTo(b.studentName);
    });

    return records;
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }
}

/// Parameters for GetOwnerAttendanceAnalytics use case.
class GetOwnerAttendanceAnalyticsParams extends Equatable {
  const GetOwnerAttendanceAnalyticsParams({
    required this.libraryId,
    this.periodDays = 7,
  });

  final String libraryId;

  /// Number of days for trend calculation (default: 7).
  final int periodDays;

  @override
  List<Object?> get props => [libraryId, periodDays];
}
