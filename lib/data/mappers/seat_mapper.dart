import '../../domain/entities/seat.dart';
import '../models/seat_dto.dart';

/// Mapper for Seat entity <-> SeatDto conversion.
/// Simplified - occupancy is tracked via memberships.
class SeatMapper {
  const SeatMapper._();

  static Seat toEntity(SeatDto dto) {
    return Seat(
      id: dto.id,
      libraryId: dto.libraryId,
      seatNumber: dto.seatNumber,
      isActive: dto.isActive,
    );
  }

  static SeatDto toDto(Seat entity) {
    return SeatDto(
      id: entity.id,
      libraryId: entity.libraryId,
      seatNumber: entity.seatNumber,
      isActive: entity.isActive,
    );
  }
}
