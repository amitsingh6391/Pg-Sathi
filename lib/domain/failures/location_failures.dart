import '../core/failure.dart';

/// Failure when the user denies location permission.
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
