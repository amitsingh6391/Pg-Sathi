import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

import '../core/core.dart';
import '../entities/attendance.dart';
import '../entities/slot.dart';
import '../failures/attendance_failures.dart';
import '../repositories/attendance_repository.dart';
import '../repositories/library_repository.dart';
import '../services/location_service.dart';

/// Use case for checking out a student with location validation.
///
/// V2 Update: Supports multiple check-in/check-out sessions per day.
/// - For V2 records: Completes the active session.
/// - For legacy records: Updates checkOutTime and status.
///
/// Validates:
/// - Student has an active session (is checked in)
/// - Student is within 100m of library
class CheckOut implements UseCase<Attendance, CheckOutParams> {
  const CheckOut({
    required this.attendanceRepository,
    required this.libraryRepository,
    required this.locationService,
  });

  final AttendanceRepository attendanceRepository;
  final LibraryRepository libraryRepository;
  final LocationService locationService;

  /// Maximum allowed distance from library in meters.
  static const double maxAllowedDistance = 100.0;

  @override
  Future<Either<Failure, Attendance>> call(CheckOutParams params) async {
    // Step 1: Get today's attendance for this slot
    final todayDate = _formatDate(params.checkOutTime);
    final attendanceResult = await attendanceRepository.getTodayAttendance(
      userId: params.userId,
      libraryId: params.libraryId,
      slot: params.slot,
      date: todayDate,
    );

    return attendanceResult.fold((failure) => Left(failure), (
      attendance,
    ) async {
      // No attendance record exists
      if (attendance == null) {
        return const Left(NotCheckedInFailure());
      }

      // V2: Check for active session
      if (attendance.isMultiSession) {
        if (!attendance.hasActiveSession) {
          return Left(
            NotCheckedInFailure(
              message:
                  'No active session. Check in first to start a new session.',
            ),
          );
        }
      } else {
        // Legacy: Check status
        if (attendance.isCheckedOut) {
          return Left(
            NotCheckedInFailure(
              message:
                  'You have already checked out from ${params.slot.displayName} slot today',
            ),
          );
        }

        if (!attendance.isCheckedIn) {
          return const Left(NotCheckedInFailure());
        }
      }

      // Step 2: Get library location
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

        // Step 3: Validate user location
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

          // Step 4: Check out (works for both V2 and legacy)
          return attendanceRepository.checkOut(
            attendanceId: attendance.id,
            distanceFromLibrary: validation.distanceInMeters,
          );
        });
      });
    });
  }

  String _formatDate(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }
}

/// Parameters for CheckOut use case.
class CheckOutParams extends Equatable {
  const CheckOutParams({
    required this.userId,
    required this.libraryId,
    required this.slot,
    required this.checkOutTime,
  });

  final String userId;
  final String libraryId;
  final Slot slot;
  final DateTime checkOutTime;

  @override
  List<Object?> get props => [userId, libraryId, slot, checkOutTime];
}
