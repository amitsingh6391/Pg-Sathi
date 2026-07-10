import 'package:equatable/equatable.dart';

// Sentinel value for copyWith to distinguish between null and undefined
const _undefined = Object();

/// Represents a study library owned by an owner.
/// Enhanced with full profile: facilities, pricing, timings.
class Library extends Equatable {
  const Library({
    required this.id,
    required this.ownerId,
    required this.name,
    this.fullAddress,
    this.area,
    this.latitude,
    this.longitude,
    this.location = '',
    required this.capacity,
    this.hasWifi = false,
    this.hasAC = false,
    this.hasPowerBackup = false,
    this.hasWashroom = false,
    this.hasDrinkingWater = false,
    this.hasCCTV = false,
    this.isProfileComplete = false,
    this.ownerPhone,
    this.ownerUpiId,
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
  final String? fullAddress;
  final String? area;
  final double? latitude;
  final double? longitude;
  final String location; // Legacy field
  final int capacity;
  final bool hasWifi;
  final bool hasAC;
  final bool hasPowerBackup;
  final bool hasWashroom;
  final bool hasDrinkingWater;
  final bool hasCCTV;
  final bool isProfileComplete;
  final String? ownerPhone;
  final String? ownerUpiId; // Owner's UPI ID for direct payments
  final double? customMonthlyPrice;
  final CustomDiscount? customDiscount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<String> photos;
  final int? totalSeatCapacity;

  /// Whether UPI payments are enabled for this library.
  bool get isUpiEnabled => ownerUpiId != null && ownerUpiId!.trim().isNotEmpty;

  /// Whether the library has an active admin discount.
  bool get hasActiveDiscount =>
      customDiscount != null && customDiscount!.isValid(DateTime.now());

  /// Active discount percentage (0 if no valid discount).
  double get activeDiscountPercent =>
      hasActiveDiscount ? customDiscount!.percent : 0.0;

  /// List of enabled facilities for display.
  List<LibraryFacility> get enabledFacilities {
    final facilities = <LibraryFacility>[];
    if (hasWifi) facilities.add(LibraryFacility.wifi);
    if (hasAC) facilities.add(LibraryFacility.ac);
    if (hasPowerBackup) facilities.add(LibraryFacility.powerBackup);
    if (hasWashroom) facilities.add(LibraryFacility.washroom);
    if (hasDrinkingWater) facilities.add(LibraryFacility.drinkingWater);
    if (hasCCTV) facilities.add(LibraryFacility.cctv);
    return facilities;
  }

  /// Validates if the library profile is complete.
  /// All mandatory fields must be filled for profile to be complete.
  LibraryValidationResult validate() {
    final errors = <String>[];

    if (name.trim().isEmpty) {
      errors.add('Library name is required');
    }
    if (name.trim().length < 3) {
      errors.add('Library name must be at least 3 characters');
    }
    if (fullAddress == null || fullAddress!.trim().isEmpty) {
      errors.add('Full address is required');
    }
    if (area == null || area!.trim().isEmpty) {
      errors.add('Area is required');
    }
    return LibraryValidationResult(isValid: errors.isEmpty, errors: errors);
  }

  /// Checks if profile should be marked complete based on validation.
  bool get shouldBeProfileComplete => validate().isValid;

  @override
  List<Object?> get props => [
    id,
    ownerId,
    name,
    fullAddress,
    area,
    latitude,
    longitude,
    location,
    capacity,
    hasWifi,
    hasAC,
    hasPowerBackup,
    hasWashroom,
    hasDrinkingWater,
    hasCCTV,
    isProfileComplete,
    ownerPhone,
    ownerUpiId,
    customMonthlyPrice,
    customDiscount,
    createdAt,
    updatedAt,
    photos,
    totalSeatCapacity,
  ];

  Library copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? fullAddress,
    String? area,
    double? latitude,
    double? longitude,
    String? location,
    int? capacity,
    bool? hasWifi,
    bool? hasAC,
    bool? hasPowerBackup,
    bool? hasWashroom,
    Object? customMonthlyPrice = _undefined,
    Object? customDiscount = _undefined,
    bool? hasDrinkingWater,
    bool? hasCCTV,
    bool? isProfileComplete,
    String? ownerPhone,
    String? ownerUpiId,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? photos,
    Object? totalSeatCapacity = _undefined,
  }) {
    return Library(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      fullAddress: fullAddress ?? this.fullAddress,
      area: area ?? this.area,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      location: location ?? this.location,
      capacity: capacity ?? this.capacity,
      hasWifi: hasWifi ?? this.hasWifi,
      hasAC: hasAC ?? this.hasAC,
      hasPowerBackup: hasPowerBackup ?? this.hasPowerBackup,
      hasWashroom: hasWashroom ?? this.hasWashroom,
      hasDrinkingWater: hasDrinkingWater ?? this.hasDrinkingWater,
      hasCCTV: hasCCTV ?? this.hasCCTV,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      ownerUpiId: ownerUpiId ?? this.ownerUpiId,
      customMonthlyPrice: customMonthlyPrice == _undefined
          ? this.customMonthlyPrice
          : customMonthlyPrice as double?,
      customDiscount: customDiscount == _undefined
          ? this.customDiscount
          : customDiscount as CustomDiscount?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      photos: photos ?? this.photos,
      totalSeatCapacity: totalSeatCapacity == _undefined
          ? this.totalSeatCapacity
          : totalSeatCapacity as int?,
    );
  }

  /// Marks profile as complete after validation.
  Library markProfileComplete() {
    return copyWith(
      isProfileComplete: shouldBeProfileComplete,
      updatedAt: DateTime.now(),
    );
  }
}

/// Validation result for Library entity.
class LibraryValidationResult extends Equatable {
  const LibraryValidationResult({required this.isValid, required this.errors});

  final bool isValid;
  final List<String> errors;

  @override
  List<Object?> get props => [isValid, errors];
}

/// Admin-applied custom discount with validity period.
class CustomDiscount extends Equatable {
  const CustomDiscount({
    required this.percent,
    required this.validUntil,
    this.appliedBy,
    this.appliedAt,
  });

  final double percent;
  final DateTime validUntil;
  final String? appliedBy;
  final DateTime? appliedAt;

  /// Whether the discount is currently valid.
  bool isValid(DateTime now) {
    return now.isBefore(validUntil) && percent > 0;
  }

  @override
  List<Object?> get props => [percent, validUntil, appliedBy, appliedAt];
}

/// Facility types shown on the PG profile.
enum LibraryFacility {
  wifi('WiFi', 'wifi'),
  ac('AC', 'ac_unit'),
  powerBackup('Power Backup', 'power'),
  washroom('Attached Washroom', 'wc'),
  drinkingWater('RO Drinking Water', 'water_drop'),
  cctv('CCTV Security', 'videocam');

  const LibraryFacility(this.displayName, this.iconName);

  final String displayName;
  final String iconName;
}
