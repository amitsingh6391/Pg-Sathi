import 'package:cloud_firestore/cloud_firestore.dart';

/// Data Transfer Object for Library entity.
/// Enhanced with full profile: facilities, pricing, timings.
class LibraryDto {
  const LibraryDto({
    required this.id,
    required this.ownerId,
    required this.name,
    // Location
    this.fullAddress,
    this.area,
    this.latitude,
    this.longitude,
    this.location = '',
    // Seats
    required this.capacity,
    // Facilities
    this.hasWifi = false,
    this.hasAC = false,
    this.hasPowerBackup = false,
    this.hasWashroom = false,
    this.hasDrinkingWater = false,
    this.hasCCTV = false,
    // Status
    this.isProfileComplete = false,
    this.ownerPhone,
    this.ownerUpiId,
    // Custom Pricing
    this.customMonthlyPrice,
    this.customDiscount,
    this.createdAt,
    this.updatedAt,
    this.photos = const [],
    this.totalSeatCapacity,
  });

  final String id;
  final String ownerId;
  final String name;

  // Location
  final String? fullAddress;
  final String? area;
  final double? latitude;
  final double? longitude;
  final String location;

  // Seats
  final int capacity;

  // Facilities
  final bool hasWifi;
  final bool hasAC;
  final bool hasPowerBackup;
  final bool hasWashroom;
  final bool hasDrinkingWater;
  final bool hasCCTV;

  // Status
  final bool isProfileComplete;
  final String? ownerPhone;
  final String? ownerUpiId;

  // Custom Pricing
  final double? customMonthlyPrice;

  // Admin-applied discount
  final CustomDiscountDto? customDiscount;

  // Timestamps
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  // Photos
  final List<String> photos;

  final int? totalSeatCapacity;

  factory LibraryDto.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return LibraryDto(
      id: doc.id,
      ownerId: data['ownerId'] as String,
      name: data['name'] as String,
      // Location
      fullAddress: data['fullAddress'] as String?,
      area: data['area'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      location: data['location'] as String? ?? '',
      // Seats
      capacity: data['capacity'] as int? ?? 0,
      // Facilities
      hasWifi: data['hasWifi'] as bool? ?? false,
      hasAC: data['hasAC'] as bool? ?? false,
      hasPowerBackup: data['hasPowerBackup'] as bool? ?? false,
      hasWashroom: data['hasWashroom'] as bool? ?? false,
      hasDrinkingWater: data['hasDrinkingWater'] as bool? ?? false,
      hasCCTV: data['hasCCTV'] as bool? ?? false,
      // Status
      isProfileComplete: data['isProfileComplete'] as bool? ?? false,
      ownerPhone: data['ownerPhone'] as String?,
      ownerUpiId: data['ownerUpiId'] as String?,
      // Custom Pricing
      customMonthlyPrice: (data['customMonthlyPrice'] as num?)?.toDouble(),
      customDiscount: data['customDiscount'] != null
          ? CustomDiscountDto.fromMap(data['customDiscount'] as Map<String, dynamic>)
          : null,
      // Timestamps
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
      // Photos
      photos:
          (data['photos'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      totalSeatCapacity: data['totalSeatCapacity'] as int?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'name': name,
      // Location
      if (fullAddress != null) 'fullAddress': fullAddress,
      if (area != null) 'area': area,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'location': location,
      // Seats
      'capacity': capacity,
      // Facilities
      'hasWifi': hasWifi,
      'hasAC': hasAC,
      'hasPowerBackup': hasPowerBackup,
      'hasWashroom': hasWashroom,
      'hasDrinkingWater': hasDrinkingWater,
      'hasCCTV': hasCCTV,
      // Status
      'isProfileComplete': isProfileComplete,
      if (ownerPhone != null) 'ownerPhone': ownerPhone,
      if (ownerUpiId != null) 'ownerUpiId': ownerUpiId,
      // Custom Pricing
      if (customMonthlyPrice != null) 'customMonthlyPrice': customMonthlyPrice,
      if (customDiscount != null) 'customDiscount': customDiscount!.toMap(),
      // Timestamps
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      // Photos
      'photos': photos,
      if (totalSeatCapacity != null) 'totalSeatCapacity': totalSeatCapacity,
    };
  }

  static const String collectionName = 'libraries';
}

/// DTO for admin-applied custom discount.
class CustomDiscountDto {
  const CustomDiscountDto({
    required this.percent,
    required this.validUntil,
    this.appliedBy,
    this.appliedAt,
  });

  final double percent;
  final Timestamp validUntil;
  final String? appliedBy;
  final Timestamp? appliedAt;

  factory CustomDiscountDto.fromMap(Map<String, dynamic> map) {
    return CustomDiscountDto(
      percent: (map['percent'] as num).toDouble(),
      validUntil: map['validUntil'] as Timestamp,
      appliedBy: map['appliedBy'] as String?,
      appliedAt: map['appliedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'percent': percent,
      'validUntil': validUntil,
      if (appliedBy != null) 'appliedBy': appliedBy,
      if (appliedAt != null) 'appliedAt': appliedAt,
    };
  }
}
