import 'package:dartz/dartz.dart';
import 'package:pg_manager/domain/core/failure.dart';
import 'package:pg_manager/domain/entities/user.dart';
import 'package:pg_manager/domain/entities/user_session.dart';

/// Repository for tracking user app sessions.
/// Tracks actual app usage independent of attendance records.
abstract class UserSessionRepository {
  /// Starts a new session when user opens the app.
  Future<Either<Failure, UserSession>> startSession({
    required String userId,
    required UserRole role,
    String? deviceId,
  });

  /// Updates the last active time for current session.
  Future<Either<Failure, void>> updateLastActive(String sessionId);

  /// Ends a session when user closes the app.
  Future<Either<Failure, void>> endSession(String sessionId);

  /// Gets all sessions for a user in a date range.
  Future<Either<Failure, List<UserSession>>> getUserSessions({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Gets all student sessions in a date range (for analytics).
  Future<Either<Failure, List<UserSession>>> getStudentSessions({
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Gets all owner sessions in a date range (for analytics).
  Future<Either<Failure, List<UserSession>>> getOwnerSessions({
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Gets active session for a user (if any).
  Future<Either<Failure, UserSession?>> getActiveSession(String userId);
}
