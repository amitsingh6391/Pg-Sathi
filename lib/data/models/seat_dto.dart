import 'package:cloud_firestore/cloud_firestore.dart';

/// Data Transfer Object for Seat entity.
/// Simplified - occupancy is tracked via memberships, not on seat itself.
class SeatDto {
  const SeatDto({
    required this.id,
    required this.libraryId,
    required this.seatNumber,
    this.isActive = true,
  });

  final String id;
  final String libraryId;
  final String seatNumber;
  final bool isActive;

  factory SeatDto.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return SeatDto(
      id: doc.id,
      libraryId: data['libraryId'] as String,
      seatNumber: data['seatNumber'] as String,
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'libraryId': libraryId,
      'seatNumber': seatNumber,
      'isActive': isActive,
    };
  }

  static const String collectionName = 'seats';
}
