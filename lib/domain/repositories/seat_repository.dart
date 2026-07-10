import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/seat.dart';

/// Repository interface for Seat aggregate.
/// Occupancy is tracked via memberships, not on seats directly.
abstract class SeatRepository {
  /// Creates seats for a library.
  Future<Either<Failure, List<Seat>>> createSeats({
    required String libraryId,
    required int count,
  });

  /// Retrieves a seat by ID.
  Future<Either<Failure, Seat>> getSeatById(String seatId);

  /// Retrieves all seats for a library.
  Future<Either<Failure, List<Seat>>> getSeatsByLibraryId(String libraryId);

  /// Retrieves active seats for a library.
  Future<Either<Failure, List<Seat>>> getActiveSeatsByLibraryId(
    String libraryId,
  );

  /// Updates seat information.
  Future<Either<Failure, Seat>> updateSeat(Seat seat);

  /// Deletes seats for a library (used when reducing capacity).
  Future<Either<Failure, void>> deleteSeatsForLibrary(
    String libraryId, {
    int? keepCount,
  });
}
