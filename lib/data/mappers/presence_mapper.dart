import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/presence.dart';
import '../models/presence_dto.dart';

/// Mapper for Presence entity <-> PresenceDto conversion.
class PresenceMapper {
  const PresenceMapper._();

  static Presence toEntity(PresenceDto dto) {
    return Presence(
      id: dto.id,
      userId: dto.userId,
      libraryId: dto.libraryId,
      date: dto.date.toDate(),
      checkInTime: dto.checkInTime.toDate(),
      checkOutTime: dto.checkOutTime?.toDate(),
      seatId: dto.seatId,
      status: _parseStatus(dto.status),
    );
  }

  static PresenceDto toDto(Presence entity) {
    return PresenceDto(
      id: entity.id,
      userId: entity.userId,
      libraryId: entity.libraryId,
      date: Timestamp.fromDate(entity.date),
      checkInTime: Timestamp.fromDate(entity.checkInTime),
      checkOutTime: entity.checkOutTime != null
          ? Timestamp.fromDate(entity.checkOutTime!)
          : null,
      seatId: entity.seatId,
      status: entity.status.name,
    );
  }

  static PresenceStatus _parseStatus(String status) {
    return PresenceStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => PresenceStatus.checkedIn,
    );
  }
}
