import '../core/failure.dart';

// Re-export NotCheckedInFailure from presence_failures.dart for convenience.
export 'presence_failures.dart' show NotCheckedInFailure;

/// Failure when user is already checked in for the slot today.
class AlreadyCheckedInForSlotFailure extends Failure {
  const AlreadyCheckedInForSlotFailure({String? message})
    : super(message: message ?? 'Already checked in for this slot today');
}

/// Failure when check-in/check-out is attempted outside the time window.
class TimeWindowViolationFailure extends Failure {
  const TimeWindowViolationFailure({
    String? message,
    this.isTooEarly = false,
    this.isTooLate = false,
    this.minutesRemaining,
  }) : super(message: message ?? 'Action not allowed at this time');

  final bool isTooEarly;
  final bool isTooLate;
  final int? minutesRemaining;
}

/// Failure when user is outside the allowed distance from library.
class OutOfRangeFailure extends Failure {
  OutOfRangeFailure({
    required this.distanceInMeters,
    required this.maxAllowedDistance,
    String? message,
  }) : super(
         message:
             message ??
             'You are ${distanceInMeters.toStringAsFixed(0)}m away. Please be within ${maxAllowedDistance.toStringAsFixed(0)}m of the library.',
       );

  final double distanceInMeters;
  final double maxAllowedDistance;
}

/// Failure when location permission is denied.
class LocationPermissionDeniedFailure extends Failure {
  const LocationPermissionDeniedFailure({String? message})
    : super(
        message:
            message ??
            'Location permission denied. Please enable location access.',
      );
}

/// Failure when location services are disabled.
class LocationServiceDisabledFailure extends Failure {
  const LocationServiceDisabledFailure({String? message})
    : super(
        message:
            message ?? 'Location services are disabled. Please enable GPS.',
      );
}

/// Failure when library location is not configured.
class LibraryLocationNotConfiguredFailure extends Failure {
  const LibraryLocationNotConfiguredFailure({String? message})
    : super(
        message: message ?? 'Library location not configured. Contact owner.',
      );
}

/// Failure when attendance record is not found.
class AttendanceNotFoundFailure extends Failure {
  const AttendanceNotFoundFailure({String? message})
    : super(message: message ?? 'Attendance record not found');
}

/// Failure when no active membership exists.
class NoActiveMembershipForAttendanceFailure extends Failure {
  const NoActiveMembershipForAttendanceFailure({String? message})
    : super(message: message ?? 'You need an active membership to check in');
}
