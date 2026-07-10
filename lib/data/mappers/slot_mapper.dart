import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/custom_slot.dart';
import '../models/slot_dto.dart';

/// Mapper for CustomSlot entity <-> SlotDto conversion.
class SlotMapper {
  const SlotMapper._();

  static CustomSlot toEntity(SlotDto dto) {
    return CustomSlot(
      id: dto.id,
      libraryId: dto.libraryId,
      name: dto.name,
      startTime: dto.startTime,
      endTime: dto.endTime,
      price: dto.price,
      capacity: dto.capacity,
      isActive: dto.isActive,
      seatPrefix: dto.seatPrefix,
      seatStartNumber: dto.seatStartNumber,
      createdAt: dto.createdAt?.toDate(),
      updatedAt: dto.updatedAt?.toDate(),
    );
  }

  static SlotDto toDto(CustomSlot entity) {
    return SlotDto(
      id: entity.id,
      libraryId: entity.libraryId,
      name: entity.name,
      startTime: entity.startTime,
      endTime: entity.endTime,
      price: entity.price,
      capacity: entity.capacity,
      isActive: entity.isActive,
      seatPrefix: entity.seatPrefix,
      seatStartNumber: entity.seatStartNumber,
      createdAt: entity.createdAt != null
          ? Timestamp.fromDate(entity.createdAt!)
          : null,
      updatedAt: entity.updatedAt != null
          ? Timestamp.fromDate(entity.updatedAt!)
          : null,
    );
  }
}
