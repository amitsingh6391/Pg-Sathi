import 'package:cloud_firestore/cloud_firestore.dart';

/// Data Transfer Object for CustomSlot entity.
class SlotDto {
  const SlotDto({
    required this.id,
    required this.libraryId,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.price,
    required this.capacity,
    this.isActive = true,
    this.seatPrefix,
    this.seatStartNumber,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String libraryId;
  final String name;

  /// Start time in minutes since midnight (0-1440).
  final int startTime;

  /// End time in minutes since midnight (0-1440).
  final int endTime;

  /// Price in INR per month.
  final double price;

  /// Number of seats available for this slot.
  final int capacity;
  final bool isActive;

  /// Optional seat label prefix (e.g. "A").
  final String? seatPrefix;

  /// Optional seat start number (e.g. 20).
  final int? seatStartNumber;

  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory SlotDto.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return SlotDto(
      id: doc.id,
      libraryId: data['libraryId'] as String,
      name: data['name'] as String,
      startTime: data['startTime'] as int,
      endTime: data['endTime'] as int,
      price: (data['price'] as num).toDouble(),
      capacity: data['capacity'] as int? ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      seatPrefix: data['seatPrefix'] as String?,
      seatStartNumber: data['seatStartNumber'] as int?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'libraryId': libraryId,
      'name': name,
      'startTime': startTime,
      'endTime': endTime,
      'price': price,
      'capacity': capacity,
      'isActive': isActive,
      if (seatPrefix != null && seatPrefix!.isNotEmpty)
        'seatPrefix': seatPrefix,
      if (seatStartNumber != null && seatStartNumber! > 0)
        'seatStartNumber': seatStartNumber,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static const String collectionName = 'slots';
}
