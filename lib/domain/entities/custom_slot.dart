import 'package:equatable/equatable.dart';

/// Represents a custom time slot defined by a library.
/// Libraries can create unlimited custom slots with their own time ranges and pricing.
class CustomSlot extends Equatable {
  const CustomSlot({
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

  /// Start time of the slot (TimeOfDay stored as minutes since midnight).
  /// Example: 360 = 6:00 AM, 840 = 2:00 PM
  final int startTime;

  /// End time of the slot (TimeOfDay stored as minutes since midnight).
  /// Example: 840 = 2:00 PM, 1320 = 10:00 PM
  final int endTime;

  /// Price for this slot (in INR per month).
  final double price;

  /// Number of seats available for this slot.
  final int capacity;
  final bool isActive;

  /// Optional prefix for bed labels (e.g. "A" -> A01, A02...).
  /// When null the default "B" prefix is used.
  final String? seatPrefix;

  /// Optional starting number for seat labels (e.g. 20 → prefix20, prefix21…).
  /// When null seat numbering starts at 1.
  final int? seatStartNumber;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Returns the effective prefix used for labelling seats.
  String get effectivePrefix => (seatPrefix?.trim().isNotEmpty == true)
      ? seatPrefix!.trim().toUpperCase()
      : 'B';

  /// Returns the effective seat start number (defaults to 1).
  int get effectiveStartNumber =>
      (seatStartNumber != null && seatStartNumber! > 0) ? seatStartNumber! : 1;

  /// Generates the ordered list of seat label strings for this slot.
  /// E.g. prefix="A", startNumber=20, capacity=5 → ["A20","A21","A22","A23","A24"]
  List<String> get seatLabels {
    final prefix = effectivePrefix;
    final start = effectiveStartNumber;
    return List.generate(capacity, (i) => '$prefix${start + i}');
  }

  /// Get start time as hours and minutes.
  ({int hour, int minute}) get startTimeOfDay {
    return (hour: startTime ~/ 60, minute: startTime % 60);
  }

  /// Get end time as hours and minutes.
  ({int hour, int minute}) get endTimeOfDay {
    return (hour: endTime ~/ 60, minute: endTime % 60);
  }

  /// Formatted display string (e.g., "6:00 AM – 2:00 PM").
  String get displayTime {
    final start = startTimeOfDay;
    final end = endTimeOfDay;
    return '${_formatTime(start.hour, start.minute)} – ${_formatTime(end.hour, end.minute)}';
  }

  /// Formatted display string with price (e.g., "6:00 AM – 2:00 PM (₹500/month)").
  String get displayWithPrice =>
      '$displayTime (₹${price.toStringAsFixed(0)}/month)';

  String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0
        ? 12
        : hour > 12
        ? hour - 12
        : hour;
    final displayMinute = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $period';
  }

  /// Check if this slot overlaps with another slot.
  /// Handles overnight slots (where endTime < startTime).
  bool overlapsWith(CustomSlot other) {
    if (id == other.id) return false; // Same slot doesn't overlap with itself
    if (!isActive || !other.isActive) {
      return false; // Inactive slots don't overlap
    }

    // Handle overnight slots (endTime < startTime means slot spans to next day)
    final thisIsOvernight = endTime < startTime;
    final otherIsOvernight = other.endTime < other.startTime;

    if (thisIsOvernight && otherIsOvernight) {
      // Both are overnight - they always overlap
      return true;
    } else if (thisIsOvernight) {
      // This slot is overnight, check if it overlaps with other
      // Overnight slot spans from startTime to 1440 (midnight) and 0 to endTime
      return startTime < other.endTime || endTime > other.startTime;
    } else if (otherIsOvernight) {
      // Other slot is overnight, check if it overlaps with this
      return other.startTime < endTime || other.endTime > startTime;
    } else {
      // Both are normal slots (same day)
      return startTime < other.endTime && endTime > other.startTime;
    }
  }

  /// Validate slot times.
  /// Allows overnight slots (endTime < startTime means slot spans to next day).
  /// Valid range: 0-1440 minutes (24 hours).
  bool get isValid =>
      startTime >= 0 &&
      startTime <= 1440 &&
      endTime >= 0 &&
      endTime <= 1440 &&
      startTime != endTime; // Start and end cannot be the same

  @override
  List<Object?> get props => [
    id,
    libraryId,
    name,
    startTime,
    endTime,
    price,
    capacity,
    isActive,
    seatPrefix,
    seatStartNumber,
    createdAt,
    updatedAt,
  ];

  CustomSlot copyWith({
    String? id,
    String? libraryId,
    String? name,
    int? startTime,
    int? endTime,
    double? price,
    int? capacity,
    bool? isActive,
    // Use sentinel to allow clearing optional string
    Object? seatPrefix = _keep,
    Object? seatStartNumber = _keep,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomSlot(
      id: id ?? this.id,
      libraryId: libraryId ?? this.libraryId,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      price: price ?? this.price,
      capacity: capacity ?? this.capacity,
      isActive: isActive ?? this.isActive,
      seatPrefix: seatPrefix == _keep ? this.seatPrefix : seatPrefix as String?,
      seatStartNumber: seatStartNumber == _keep
          ? this.seatStartNumber
          : seatStartNumber as int?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Sentinel value used by copyWith to distinguish "not provided" from null.
  static const Object _keep = Object();

  CustomSlot deactivate() => copyWith(isActive: false);
  CustomSlot activate() => copyWith(isActive: true);
}
