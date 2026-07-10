import 'package:cloud_firestore/cloud_firestore.dart';

import 'attendance_session_dto.dart';

/// Data Transfer Object for Attendance entity.
/// V2 Update: Added sessions list for multi-session support.
class AttendanceDto {
  const AttendanceDto({
    required this.id,
    required this.userId,
    required this.libraryId,
    required this.seatId,
    required this.slot,
    required this.date,
    required this.status,
    this.checkInTime,
    this.checkOutTime,
    this.checkInDistance,
    this.checkOutDistance,
    this.createdAt,
    this.sessions = const [],
  });

  final String id;
  final String userId;
  final String libraryId;
  final String seatId;
  final String slot;
  final String date;
  final String status;

  /// Legacy single-session fields (backward compatible).
  final Timestamp? checkInTime;
  final Timestamp? checkOutTime;
  final double? checkInDistance;
  final double? checkOutDistance;

  final Timestamp? createdAt;

  /// V2: List of sessions for multi-session attendance.
  final List<AttendanceSessionDto> sessions;

  factory AttendanceDto.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    // Parse sessions array if present (V2)
    final sessionsRaw = data['sessions'] as List<dynamic>?;
    final sessions =
        sessionsRaw
            ?.map(
              (s) => AttendanceSessionDto.fromMap(s as Map<String, dynamic>),
            )
            .toList() ??
        const [];

    return AttendanceDto(
      id: doc.id,
      userId: data['userId'] as String,
      libraryId: data['libraryId'] as String,
      seatId: data['seatId'] as String? ?? '',
      slot: data['slot'] as String,
      date: data['date'] as String,
      status: data['status'] as String,
      checkInTime: data['checkInTime'] as Timestamp?,
      checkOutTime: data['checkOutTime'] as Timestamp?,
      checkInDistance: (data['checkInDistance'] as num?)?.toDouble(),
      checkOutDistance: (data['checkOutDistance'] as num?)?.toDouble(),
      createdAt: data['createdAt'] as Timestamp?,
      sessions: sessions,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'libraryId': libraryId,
      'seatId': seatId,
      'slot': slot,
      'date': date,
      'status': status,
      if (checkInTime != null) 'checkInTime': checkInTime,
      if (checkOutTime != null) 'checkOutTime': checkOutTime,
      if (checkInDistance != null) 'checkInDistance': checkInDistance,
      if (checkOutDistance != null) 'checkOutDistance': checkOutDistance,
      if (createdAt != null) 'createdAt': createdAt,
      // V2: Include sessions if not empty
      if (sessions.isNotEmpty)
        'sessions': sessions.map((s) => s.toMap()).toList(),
    };
  }

  static const String collectionName = 'attendance';
}
