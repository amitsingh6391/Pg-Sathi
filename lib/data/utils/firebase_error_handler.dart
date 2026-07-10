import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:get_it/get_it.dart';

import '../../domain/core/failure.dart';
import '../failures/data_failures.dart';
import '../services/crashlytics_service.dart';

/// Utility to handle Firebase errors and convert them to domain failures.
class FirebaseErrorHandler {
  const FirebaseErrorHandler._();

  /// Wraps a Firebase operation and handles errors.
  static Future<Either<Failure, T>> guard<T>(
    Future<T> Function() operation,
  ) async {
    try {
      final result = await operation();
      return Right(result);
    } on FirebaseException catch (e) {
      // Log to Crashlytics
      _logError(e, e.stackTrace);
      return Left(_mapFirebaseException(e));
    } catch (e, stackTrace) {
      // Log to Crashlytics
      _logError(e, stackTrace);
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  /// Logs error to Crashlytics if service is available.
  static void _logError(Object error, StackTrace? stackTrace) {
    try {
      if (GetIt.instance.isRegistered<CrashlyticsService>()) {
        final crashlytics = GetIt.instance<CrashlyticsService>();
        crashlytics.recordError(error, stackTrace, fatal: false);
      }
    } catch (_) {
      // Silently fail if Crashlytics not available
    }
  }

  static Failure _mapFirebaseException(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return PermissionDeniedFailure(message: e.message);
      case 'not-found':
        return DocumentNotFoundFailure(message: e.message);
      case 'unavailable':
        return NetworkFailure(message: e.message);
      case 'invalid-argument':
        return InvalidDataFailure(message: e.message);
      default:
        return ServerFailure(message: e.message ?? 'Firebase error: ${e.code}');
    }
  }
}
