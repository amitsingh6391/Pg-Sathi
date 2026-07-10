import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/presence.dart';

/// Repository interface for Presence aggregate.
abstract class PresenceRepository {
  /// Records a check-in.
  Future<Either<Failure, Presence>> checkIn(Presence presence);

  /// Records a check-out.
  Future<Either<Failure, Presence>> checkOut({
    required String presenceId,
    required DateTime checkOutTime,
  });

  /// Retrieves presence by ID.
  Future<Either<Failure, Presence>> getPresenceById(String presenceId);

  /// Retrieves today's presence for a user in a library.
  Future<Either<Failure, Presence?>> getTodayPresenceByUserAndLibrary({
    required String userId,
    required String libraryId,
    required DateTime date,
  });

  /// Retrieves presence history for a user.
  Future<Either<Failure, List<Presence>>> getPresenceHistoryByUserId({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Retrieves all presence records for a library on a date.
  Future<Either<Failure, List<Presence>>> getPresenceByLibraryAndDate({
    required String libraryId,
    required DateTime date,
  });

  /// Checks if user has active presence (checked in but not out).
  Future<Either<Failure, bool>> hasActivePresence({
    required String userId,
    required String libraryId,
    required DateTime date,
  });
}
