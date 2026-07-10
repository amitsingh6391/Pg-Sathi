import 'package:equatable/equatable.dart';

/// Represents a daily presence record for a student at a library.
class Presence extends Equatable {
  const Presence({
    required this.id,
    required this.userId,
    required this.libraryId,
    required this.date,
    required this.checkInTime,
    this.checkOutTime,
    this.seatId,
    this.status = PresenceStatus.checkedIn,
  });

  final String id;
  final String userId;
  final String libraryId;
  final DateTime date;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final String? seatId;
  final PresenceStatus status;

  /// Checks if user is currently present (checked in but not checked out).
  bool get isCurrentlyPresent =>
      status == PresenceStatus.checkedIn && checkOutTime == null;

  /// Calculates total duration spent in library.
  Duration? get duration {
    if (checkOutTime == null) return null;
    return checkOutTime!.difference(checkInTime);
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    libraryId,
    date,
    checkInTime,
    checkOutTime,
    seatId,
    status,
  ];

  Presence copyWith({
    String? id,
    String? userId,
    String? libraryId,
    DateTime? date,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    String? seatId,
    PresenceStatus? status,
  }) {
    return Presence(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      libraryId: libraryId ?? this.libraryId,
      date: date ?? this.date,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      seatId: seatId ?? this.seatId,
      status: status ?? this.status,
    );
  }

  /// Records check out.
  Presence checkOut(DateTime checkOutTime) {
    return copyWith(
      checkOutTime: checkOutTime,
      status: PresenceStatus.checkedOut,
    );
  }
}

/// Presence status.
enum PresenceStatus { checkedIn, checkedOut, absent }
