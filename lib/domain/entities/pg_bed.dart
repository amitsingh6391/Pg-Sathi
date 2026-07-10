import 'package:equatable/equatable.dart';

/// Represents a bed inside a PG room.
class PgBed extends Equatable {
  const PgBed({
    required this.id,
    required this.pgPropertyId,
    required this.roomId,
    required this.bedNumber,
    this.isActive = true,
  });

  final String id;
  final String pgPropertyId;
  final String roomId;
  final String bedNumber;
  final bool isActive;

  PgBed copyWith({
    String? id,
    String? pgPropertyId,
    String? roomId,
    String? bedNumber,
    bool? isActive,
  }) {
    return PgBed(
      id: id ?? this.id,
      pgPropertyId: pgPropertyId ?? this.pgPropertyId,
      roomId: roomId ?? this.roomId,
      bedNumber: bedNumber ?? this.bedNumber,
      isActive: isActive ?? this.isActive,
    );
  }

  PgBed deactivate() => copyWith(isActive: false);
  PgBed activate() => copyWith(isActive: true);

  @override
  List<Object?> get props => [id, pgPropertyId, roomId, bedNumber, isActive];
}
