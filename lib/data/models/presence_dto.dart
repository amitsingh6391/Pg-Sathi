import 'package:cloud_firestore/cloud_firestore.dart';

/// Data Transfer Object for Presence entity.
class PresenceDto {
  const PresenceDto({
    required this.id,
    required this.userId,
    required this.libraryId,
    required this.date,
    required this.checkInTime,
    required this.status,
    this.checkOutTime,
    this.seatId,
  });

  final String id;
  final String userId;
  final String libraryId;
  final Timestamp date;
  final Timestamp checkInTime;
  final Timestamp? checkOutTime;
  final String? seatId;
  final String status;

  factory PresenceDto.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return PresenceDto(
      id: doc.id,
      userId: data['userId'] as String,
      libraryId: data['libraryId'] as String,
      date: data['date'] as Timestamp,
      checkInTime: data['checkInTime'] as Timestamp,
      checkOutTime: data['checkOutTime'] as Timestamp?,
      seatId: data['seatId'] as String?,
      status: data['status'] as String,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'libraryId': libraryId,
      'date': date,
      'checkInTime': checkInTime,
      'checkOutTime': checkOutTime,
      'seatId': seatId,
      'status': status,
    };
  }

  static const String collectionName = 'presences';
}
