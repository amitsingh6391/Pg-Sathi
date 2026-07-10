import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../core/core.dart';
import '../entities/attendance.dart';
import '../entities/membership.dart';
import '../entities/slot.dart';
import '../failures/attendance_failures.dart';
import '../repositories/attendance_repository.dart';
import '../repositories/library_repository.dart';
import '../repositories/membership_repository.dart';
import '../services/location_service.dart';

/// Use case for checking in a student with location validation.
///
/// V2 Update: Supports multiple check-in/check-out sessions per day.
/// - If no attendance exists for today, creates new attendance with first session.
/// - If attendance exists and no active session, adds a new session.
/// - If attendance exists with active session, returns error.
///
/// Validates:
/// - Student has active membership
/// - Student is within 100m of library
/// - No active session currently running
class CheckIn implements UseCase<Attendance, CheckInParams> {
  const CheckIn({
    required this.attendanceRepository,
    required this.membershipRepository,
    required this.libraryRepository,
    required this.locationService,
  });

  final AttendanceRepository attendanceRepository;
  final MembershipRepository membershipRepository;
  final LibraryRepository libraryRepository;
  final LocationService locationService;

  /// Maximum allowed distance from library in meters.
  static const double maxAllowedDistance = 100.0;

  @override
  Future<Either<Failure, Attendance>> call(CheckInParams params) async {
    // Step 1: Get active membership for the user and library
    final membershipResult = await membershipRepository
        .getActiveMembershipByUserLibraryAndSlot(
          userId: params.userId,
          libraryId: params.libraryId,
          slot: params.slot,
        );

    return membershipResult.fold((failure) => Left(failure), (
      membership,
    ) async {
      // If not found by slot enum, try getting all active memberships
      Membership? activeMembership = membership;
      if (activeMembership == null) {
        final allMembershipsResult = await membershipRepository
            .getActiveMembershipByUserAndLibrary(
              userId: params.userId,
              libraryId: params.libraryId,
            );

        final allMembershipsEither = allMembershipsResult.fold(
          (failure) => Left<Failure, Membership?>(failure),
          (m) => Right<Failure, Membership?>(m),
        );

        if (allMembershipsEither.isRight()) {
          final allMembership = allMembershipsEither.getOrElse(() => null);
          if (allMembership != null) {
            if (allMembership.slot == params.slot) {
              activeMembership = allMembership;
            } else if (allMembership.slotId != null &&
                allMembership.slotId!.isNotEmpty) {
              activeMembership = allMembership;
            }
          }
        }
      }

      if (activeMembership == null) {
        return Left(
          NoActiveMembershipForAttendanceFailure(
            message: 'No active membership found',
          ),
        );
      }

      // Step 2: Check existing attendance for today
      final todayDate = _formatDate(params.checkInTime);
      final existingResult = await attendanceRepository.getTodayAttendance(
        userId: params.userId,
        libraryId: params.libraryId,
        slot: params.slot,
        date: todayDate,
      );

      return existingResult.fold((failure) => Left(failure), (existing) async {
        // V2: Check for active session (both legacy and multi-session)
        if (existing != null) {
          // For V2 multi-session: check if there's an active session
          if (existing.isMultiSession && existing.hasActiveSession) {
            return const Left(AlreadyCheckedInForSlotFailure());
          }
          // For legacy: check if status is checkedIn
          if (!existing.isMultiSession && existing.isCheckedIn) {
            return const Left(AlreadyCheckedInForSlotFailure());
          }
        }

        // Step 3: Get library location
        final libraryResult = await libraryRepository.getLibraryById(
          params.libraryId,
        );

        return libraryResult.fold((failure) => Left(failure), (library) async {
          if (library == null) {
            return const Left(
              LibraryLocationNotConfiguredFailure(message: 'Library not found'),
            );
          }

          if (library.latitude == null || library.longitude == null) {
            return const Left(LibraryLocationNotConfiguredFailure());
          }

          // Step 4: Validate user location
          final locationResult = await locationService.validateUserLocation(
            libraryLat: library.latitude!,
            libraryLon: library.longitude!,
            maxDistanceMeters: maxAllowedDistance,
          );

          return locationResult.fold((failure) => Left(failure), (
            validation,
          ) async {
            if (!validation.isWithinRange) {
              return Left(
                OutOfRangeFailure(
                  distanceInMeters: validation.distanceInMeters,
                  maxAllowedDistance: maxAllowedDistance,
                ),
              );
            }

            // Step 5: Handle V2 multi-session or create new attendance
            final sessionId = const Uuid().v4();

            if (existing != null) {
              // V2: Add new session to existing attendance
              return attendanceRepository.addSession(
                attendanceId: existing.id,
                sessionId: sessionId,
                distanceFromLibrary: validation.distanceInMeters,
              );
            } else {
              // Create new V2 attendance with first session
              final attendance = Attendance.checkInV2(
                id: params.attendanceId,
                userId: params.userId,
                libraryId: params.libraryId,
                seatId: activeMembership!.assignedSeatId ?? '',
                slot: params.slot,
                date: todayDate,
                sessionId: sessionId,
                distanceFromLibrary: validation.distanceInMeters,
              );

              return attendanceRepository.checkIn(attendance);
            }
          });
        });
      });
    });
  }

  String _formatDate(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }
}

/// Parameters for CheckIn use case.
class CheckInParams extends Equatable {
  const CheckInParams({
    required this.attendanceId,
    required this.userId,
    required this.libraryId,
    required this.slot,
    required this.checkInTime,
  });

  final String attendanceId;
  final String userId;
  final String libraryId;
  final Slot slot;
  final DateTime checkInTime;

  @override
  List<Object?> get props => [
    attendanceId,
    userId,
    libraryId,
    slot,
    checkInTime,
  ];
}
