import 'dart:async';
import 'dart:math';

import 'package:dartz/dartz.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/core/failure.dart';
import '../../domain/failures/attendance_failures.dart';
import '../../domain/services/location_service.dart';

/// Implementation of LocationService using Geolocator package.
class LocationServiceImpl implements LocationService {
  const LocationServiceImpl();

  @override
  Future<Either<Failure, UserLocation>> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const Left(LocationServiceDisabledFailure());
      }

      // Check permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const Left(LocationPermissionDeniedFailure());
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return const Left(
          LocationPermissionDeniedFailure(
            message:
                'Location permission permanently denied. Please enable in settings.',
          ),
        );
      }

      // Get current position with timeout
      final position =
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          ).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException(
                'Location request timed out. Please check your GPS settings.',
                const Duration(seconds: 15),
              );
            },
          );

      return Right(
        UserLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
        ),
      );
    } on TimeoutException catch (e) {
      return Left(
        LocationServiceDisabledFailure(
          message: e.message ?? 'Location request timed out',
        ),
      );
    } on PlatformException catch (e) {
      // Handle Google Play Services errors
      if (e.code == 'ERROR_GOOGLE_PLAY_SERVICES_NOT_AVAILABLE' ||
          e.message?.contains('GoogleApiManager') == true ||
          e.message?.contains('SecurityException') == true) {
        return const Left(
          LocationServiceDisabledFailure(
            message:
                'Google Play Services error. Please ensure Google Play Services is up to date and try again.',
          ),
        );
      }
      return Left(
        LocationServiceDisabledFailure(
          message: 'Location error: ${e.message ?? e.code}',
        ),
      );
    } catch (e) {
      return Left(
        LocationServiceDisabledFailure(
          message: 'Failed to get location: ${e.toString()}',
        ),
      );
    }
  }

  @override
  double calculateDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    // Haversine formula
    const earthRadius = 6371000.0; // Earth's radius in meters

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  @override
  Future<Either<Failure, LocationValidation>> validateUserLocation({
    required double libraryLat,
    required double libraryLon,
    required double maxDistanceMeters,
  }) async {
    final locationResult = await getCurrentLocation();

    return locationResult.fold((failure) => Left(failure), (userLocation) {
      final distance = calculateDistance(
        lat1: userLocation.latitude,
        lon1: userLocation.longitude,
        lat2: libraryLat,
        lon2: libraryLon,
      );

      return Right(
        LocationValidation(
          isWithinRange: distance <= maxDistanceMeters,
          distanceInMeters: distance,
          userLocation: userLocation,
        ),
      );
    });
  }
}
