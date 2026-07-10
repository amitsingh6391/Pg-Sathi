import 'package:dartz/dartz.dart';

import '../core/failure.dart';

/// Domain interface for location services.
/// Implementation will be in data layer using geolocator package.
abstract class LocationService {
  /// Gets the current device location.
  /// Returns latitude, longitude pair or failure.
  Future<Either<Failure, UserLocation>> getCurrentLocation();

  /// Calculates distance between two points in meters.
  /// Uses Haversine formula.
  double calculateDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  });

  /// Validates if user is within allowed distance from library.
  Future<Either<Failure, LocationValidation>> validateUserLocation({
    required double libraryLat,
    required double libraryLon,
    required double maxDistanceMeters,
  });
}

/// Represents user's current location.
class UserLocation {
  const UserLocation({
    required this.latitude,
    required this.longitude,
    this.accuracy,
  });

  final double latitude;
  final double longitude;
  final double? accuracy;
}

/// Result of location validation.
class LocationValidation {
  const LocationValidation({
    required this.isWithinRange,
    required this.distanceInMeters,
    required this.userLocation,
  });

  final bool isWithinRange;
  final double distanceInMeters;
  final UserLocation userLocation;
}
