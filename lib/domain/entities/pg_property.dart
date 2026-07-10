import 'package:equatable/equatable.dart';

/// Represents a paying guest property owned by a PG owner.
class PgProperty extends Equatable {
  const PgProperty({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.capacity,
    this.fullAddress,
    this.area,
    this.latitude,
    this.longitude,
    this.ownerPhone,
    this.ownerUpiId,
    this.monthlyRentFrom,
    this.defaultSecurityDeposit,
    this.hasWifi = false,
    this.hasAC = false,
    this.hasPowerBackup = false,
    this.hasFood = false,
    this.hasLaundry = false,
    this.hasCCTV = false,
    this.hasParking = false,
    this.isProfileComplete = false,
    this.photos = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final int capacity;
  final String? fullAddress;
  final String? area;
  final double? latitude;
  final double? longitude;
  final String? ownerPhone;
  final String? ownerUpiId;
  final double? monthlyRentFrom;
  final double? defaultSecurityDeposit;
  final bool hasWifi;
  final bool hasAC;
  final bool hasPowerBackup;
  final bool hasFood;
  final bool hasLaundry;
  final bool hasCCTV;
  final bool hasParking;
  final bool isProfileComplete;
  final List<String> photos;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isUpiEnabled => ownerUpiId != null && ownerUpiId!.trim().isNotEmpty;

  List<PgFacility> get enabledFacilities {
    final facilities = <PgFacility>[];
    if (hasWifi) facilities.add(PgFacility.wifi);
    if (hasAC) facilities.add(PgFacility.ac);
    if (hasPowerBackup) facilities.add(PgFacility.powerBackup);
    if (hasFood) facilities.add(PgFacility.food);
    if (hasLaundry) facilities.add(PgFacility.laundry);
    if (hasCCTV) facilities.add(PgFacility.cctv);
    if (hasParking) facilities.add(PgFacility.parking);
    return facilities;
  }

  PgPropertyValidationResult validate() {
    final errors = <String>[];

    if (name.trim().isEmpty) {
      errors.add('PG name is required');
    }
    if (name.trim().length < 3) {
      errors.add('PG name must be at least 3 characters');
    }
    if (fullAddress == null || fullAddress!.trim().isEmpty) {
      errors.add('Full address is required');
    }
    if (area == null || area!.trim().isEmpty) {
      errors.add('Area is required');
    }
    if (capacity <= 0) {
      errors.add('Total beds must be greater than 0');
    }
    if (monthlyRentFrom != null && monthlyRentFrom! < 0) {
      errors.add('Monthly rent cannot be negative');
    }
    if (defaultSecurityDeposit != null && defaultSecurityDeposit! < 0) {
      errors.add('Security deposit cannot be negative');
    }

    return PgPropertyValidationResult(isValid: errors.isEmpty, errors: errors);
  }

  bool get shouldBeProfileComplete => validate().isValid;

  PgProperty copyWith({
    String? id,
    String? ownerId,
    String? name,
    int? capacity,
    String? fullAddress,
    String? area,
    double? latitude,
    double? longitude,
    String? ownerPhone,
    String? ownerUpiId,
    double? monthlyRentFrom,
    double? defaultSecurityDeposit,
    bool? hasWifi,
    bool? hasAC,
    bool? hasPowerBackup,
    bool? hasFood,
    bool? hasLaundry,
    bool? hasCCTV,
    bool? hasParking,
    bool? isProfileComplete,
    List<String>? photos,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PgProperty(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      capacity: capacity ?? this.capacity,
      fullAddress: fullAddress ?? this.fullAddress,
      area: area ?? this.area,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      ownerUpiId: ownerUpiId ?? this.ownerUpiId,
      monthlyRentFrom: monthlyRentFrom ?? this.monthlyRentFrom,
      defaultSecurityDeposit:
          defaultSecurityDeposit ?? this.defaultSecurityDeposit,
      hasWifi: hasWifi ?? this.hasWifi,
      hasAC: hasAC ?? this.hasAC,
      hasPowerBackup: hasPowerBackup ?? this.hasPowerBackup,
      hasFood: hasFood ?? this.hasFood,
      hasLaundry: hasLaundry ?? this.hasLaundry,
      hasCCTV: hasCCTV ?? this.hasCCTV,
      hasParking: hasParking ?? this.hasParking,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      photos: photos ?? this.photos,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  PgProperty markProfileComplete() {
    return copyWith(
      isProfileComplete: shouldBeProfileComplete,
      updatedAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    ownerId,
    name,
    capacity,
    fullAddress,
    area,
    latitude,
    longitude,
    ownerPhone,
    ownerUpiId,
    monthlyRentFrom,
    defaultSecurityDeposit,
    hasWifi,
    hasAC,
    hasPowerBackup,
    hasFood,
    hasLaundry,
    hasCCTV,
    hasParking,
    isProfileComplete,
    photos,
    createdAt,
    updatedAt,
  ];
}

class PgPropertyValidationResult extends Equatable {
  const PgPropertyValidationResult({
    required this.isValid,
    required this.errors,
  });

  final bool isValid;
  final List<String> errors;

  @override
  List<Object?> get props => [isValid, errors];
}

enum PgFacility { wifi, ac, powerBackup, food, laundry, cctv, parking }

extension PgFacilityExtension on PgFacility {
  String get displayName {
    switch (this) {
      case PgFacility.wifi:
        return 'WiFi';
      case PgFacility.ac:
        return 'AC';
      case PgFacility.powerBackup:
        return 'Power Backup';
      case PgFacility.food:
        return 'Food';
      case PgFacility.laundry:
        return 'Laundry';
      case PgFacility.cctv:
        return 'CCTV';
      case PgFacility.parking:
        return 'Parking';
    }
  }
}
