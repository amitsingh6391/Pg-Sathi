import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/library.dart';
import '../models/library_dto.dart';

/// Mapper for Library entity <-> LibraryDto conversion.
class LibraryMapper {
  const LibraryMapper._();

  static Library toEntity(LibraryDto dto) {
    return Library(
      id: dto.id,
      ownerId: dto.ownerId,
      name: dto.name,
      // Location
      fullAddress: dto.fullAddress,
      area: dto.area,
      latitude: dto.latitude,
      longitude: dto.longitude,
      location: dto.location,
      // Seats
      capacity: dto.capacity,
      // Facilities
      hasWifi: dto.hasWifi,
      hasAC: dto.hasAC,
      hasPowerBackup: dto.hasPowerBackup,
      hasWashroom: dto.hasWashroom,
      hasDrinkingWater: dto.hasDrinkingWater,
      hasCCTV: dto.hasCCTV,
      // Status
      isProfileComplete: dto.isProfileComplete,
      ownerPhone: dto.ownerPhone,
      ownerUpiId: dto.ownerUpiId,
      // Custom Pricing
      customMonthlyPrice: dto.customMonthlyPrice,
      customDiscount: dto.customDiscount != null
          ? CustomDiscount(
              percent: dto.customDiscount!.percent,
              validUntil: dto.customDiscount!.validUntil.toDate(),
              appliedBy: dto.customDiscount!.appliedBy,
              appliedAt: dto.customDiscount!.appliedAt?.toDate(),
            )
          : null,
      // Timestamps
      createdAt: dto.createdAt?.toDate(),
      updatedAt: dto.updatedAt?.toDate(),
      // Photos
      photos: dto.photos,
      totalSeatCapacity: dto.totalSeatCapacity,
    );
  }

  static LibraryDto toDto(Library entity) {
    return LibraryDto(
      id: entity.id,
      ownerId: entity.ownerId,
      name: entity.name,
      // Location
      fullAddress: entity.fullAddress,
      area: entity.area,
      latitude: entity.latitude,
      longitude: entity.longitude,
      location: entity.location,
      // Seats
      capacity: entity.capacity,
      // Facilities
      hasWifi: entity.hasWifi,
      hasAC: entity.hasAC,
      hasPowerBackup: entity.hasPowerBackup,
      hasWashroom: entity.hasWashroom,
      hasDrinkingWater: entity.hasDrinkingWater,
      hasCCTV: entity.hasCCTV,
      // Status
      isProfileComplete: entity.isProfileComplete,
      ownerPhone: entity.ownerPhone,
      ownerUpiId: entity.ownerUpiId,
      // Custom Pricing
      customMonthlyPrice: entity.customMonthlyPrice,
      customDiscount: entity.customDiscount != null
          ? CustomDiscountDto(
              percent: entity.customDiscount!.percent,
              validUntil: Timestamp.fromDate(entity.customDiscount!.validUntil),
              appliedBy: entity.customDiscount!.appliedBy,
              appliedAt: entity.customDiscount!.appliedAt != null
                  ? Timestamp.fromDate(entity.customDiscount!.appliedAt!)
                  : null,
            )
          : null,
      // Timestamps
      createdAt: entity.createdAt != null
          ? Timestamp.fromDate(entity.createdAt!)
          : null,
      updatedAt: entity.updatedAt != null
          ? Timestamp.fromDate(entity.updatedAt!)
          : null,
      // Photos
      photos: entity.photos,
      totalSeatCapacity: entity.totalSeatCapacity,
    );
  }
}
