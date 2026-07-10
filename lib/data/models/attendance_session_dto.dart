import 'package:cloud_firestore/cloud_firestore.dart';

/// Data Transfer Object for AttendanceSession entity.
class AttendanceSessionDto {
  const AttendanceSessionDto({
    required this.sessionId,
    required this.checkInAt,
    this.checkOutAt,
    this.checkInDistance,
    this.checkOutDistance,
  });

  final String sessionId;
  final Timestamp checkInAt;
  final Timestamp? checkOutAt;
  final double? checkInDistance;
  final double? checkOutDistance;

  factory AttendanceSessionDto.fromMap(Map<String, dynamic> map) {
    return AttendanceSessionDto(
      sessionId: map['sessionId'] as String? ?? '',
      checkInAt: map['checkInAt'] as Timestamp,
      checkOutAt: map['checkOutAt'] as Timestamp?,
      checkInDistance: (map['checkInDistance'] as num?)?.toDouble(),
      checkOutDistance: (map['checkOutDistance'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'checkInAt': checkInAt,
      if (checkOutAt != null) 'checkOutAt': checkOutAt,
      if (checkInDistance != null) 'checkInDistance': checkInDistance,
      if (checkOutDistance != null) 'checkOutDistance': checkOutDistance,
    };
  }
}
