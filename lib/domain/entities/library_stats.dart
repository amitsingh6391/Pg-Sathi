import 'package:equatable/equatable.dart';

/// Statistics for a library showing seat occupancy.
/// Simplified to work with custom slots only (no legacy morning/evening).
class LibraryStats extends Equatable {
  const LibraryStats({
    required this.totalSeats,
    this.occupiedSeats = 0,
    this.reservedSeats = 0,
  });

  /// Empty stats (all zeros).
  const LibraryStats.empty()
    : totalSeats = 0,
      occupiedSeats = 0,
      reservedSeats = 0;

  final int totalSeats;
  final int occupiedSeats;
  final int reservedSeats;

  /// Active membership count (occupied + reserved).
  /// Use this for subscription pricing - charges based on students managed.
  int get activeMembershipCount => occupiedSeats + reservedSeats;

  /// Available seats (total - occupied - reserved).
  int get availableSeats => totalSeats - occupiedSeats - reservedSeats;

  /// Occupancy percentage (0-100).
  double get occupancyPercentage {
    if (totalSeats == 0) return 0.0;
    return ((occupiedSeats + reservedSeats) / totalSeats) * 100;
  }

  @override
  List<Object?> get props => [totalSeats, occupiedSeats, reservedSeats];
}
