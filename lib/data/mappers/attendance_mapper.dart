import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/attendance.dart';
import '../../domain/entities/attendance_session.dart';
import '../../domain/entities/slot.dart';
import '../models/attendance_dto.dart';
import '../models/attendance_session_dto.dart';

/// Mapper for converting between Attendance entity and AttendanceDto.
/// V2 Update: Added support for multi-session attendance.
class AttendanceMapper {
  const AttendanceMapper();

  /// Converts AttendanceDto to Attendance entity.
  Attendance toEntity(AttendanceDto dto) {
    return Attendance(
      id: dto.id,
      userId: dto.userId,
      libraryId: dto.libraryId,
      seatId: dto.seatId,
      slot: Slot.fromString(dto.slot) ?? Slot.morning,
      date: dto.date,
      status: AttendanceStatus.fromString(dto.status),
      checkInTime: dto.checkInTime?.toDate(),
      checkOutTime: dto.checkOutTime?.toDate(),
      checkInDistance: dto.checkInDistance,
      checkOutDistance: dto.checkOutDistance,
      createdAt: dto.createdAt?.toDate(),
      sessions: dto.sessions.map(_sessionToEntity).toList(),
    );
  }

  /// Converts Attendance entity to AttendanceDto.
  AttendanceDto toDto(Attendance entity) {
    return AttendanceDto(
      id: entity.id,
      userId: entity.userId,
      libraryId: entity.libraryId,
      seatId: entity.seatId,
      slot: entity.slot.name,
      date: entity.date,
      status: entity.status.name,
      checkInTime: entity.checkInTime != null
          ? Timestamp.fromDate(entity.checkInTime!)
          : null,
      checkOutTime: entity.checkOutTime != null
          ? Timestamp.fromDate(entity.checkOutTime!)
          : null,
      checkInDistance: entity.checkInDistance,
      checkOutDistance: entity.checkOutDistance,
      createdAt: entity.createdAt != null
          ? Timestamp.fromDate(entity.createdAt!)
          : null,
      sessions: entity.sessions.map(_sessionToDto).toList(),
    );
  }

  /// Converts AttendanceSessionDto to AttendanceSession entity.
  AttendanceSession _sessionToEntity(AttendanceSessionDto dto) {
    return AttendanceSession(
      sessionId: dto.sessionId,
      checkInAt: dto.checkInAt.toDate(),
      checkOutAt: dto.checkOutAt?.toDate(),
      checkInDistance: dto.checkInDistance,
      checkOutDistance: dto.checkOutDistance,
    );
  }

  /// Converts AttendanceSession entity to AttendanceSessionDto.
  AttendanceSessionDto _sessionToDto(AttendanceSession entity) {
    return AttendanceSessionDto(
      sessionId: entity.sessionId,
      checkInAt: Timestamp.fromDate(entity.checkInAt),
      checkOutAt: entity.checkOutAt != null
          ? Timestamp.fromDate(entity.checkOutAt!)
          : null,
      checkInDistance: entity.checkInDistance,
      checkOutDistance: entity.checkOutDistance,
    );
  }
}
