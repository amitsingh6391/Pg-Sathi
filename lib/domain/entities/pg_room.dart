import 'package:equatable/equatable.dart';

/// Represents a room inside a PG property.
class PgRoom extends Equatable {
  const PgRoom({
    required this.id,
    required this.pgPropertyId,
    required this.roomNumber,
    required this.bedCount,
    this.floor,
    this.roomType = PgRoomType.shared,
    this.monthlyRentPerBed,
    this.isActive = true,
  });

  final String id;
  final String pgPropertyId;
  final String roomNumber;
  final int bedCount;
  final String? floor;
  final PgRoomType roomType;
  final double? monthlyRentPerBed;
  final bool isActive;

  bool get hasValidBedCount => bedCount > 0;

  PgRoom copyWith({
    String? id,
    String? pgPropertyId,
    String? roomNumber,
    int? bedCount,
    String? floor,
    PgRoomType? roomType,
    double? monthlyRentPerBed,
    bool? isActive,
  }) {
    return PgRoom(
      id: id ?? this.id,
      pgPropertyId: pgPropertyId ?? this.pgPropertyId,
      roomNumber: roomNumber ?? this.roomNumber,
      bedCount: bedCount ?? this.bedCount,
      floor: floor ?? this.floor,
      roomType: roomType ?? this.roomType,
      monthlyRentPerBed: monthlyRentPerBed ?? this.monthlyRentPerBed,
      isActive: isActive ?? this.isActive,
    );
  }

  PgRoom deactivate() => copyWith(isActive: false);
  PgRoom activate() => copyWith(isActive: true);

  @override
  List<Object?> get props => [
    id,
    pgPropertyId,
    roomNumber,
    bedCount,
    floor,
    roomType,
    monthlyRentPerBed,
    isActive,
  ];
}

enum PgRoomType { single, double, triple, fourSharing, shared }

extension PgRoomTypeExtension on PgRoomType {
  String get displayName {
    switch (this) {
      case PgRoomType.single:
        return 'Single';
      case PgRoomType.double:
        return 'Double Sharing';
      case PgRoomType.triple:
        return 'Triple Sharing';
      case PgRoomType.fourSharing:
        return 'Four Sharing';
      case PgRoomType.shared:
        return 'Shared';
    }
  }
}
