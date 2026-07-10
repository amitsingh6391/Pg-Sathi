/// Time slots for seat occupancy.
/// A seat can be occupied in one slot and available in another.
enum Slot {
  morning,
  evening;

  String get displayName {
    switch (this) {
      case Slot.morning:
        return 'Morning';
      case Slot.evening:
        return 'Evening';
    }
  }

  String get shortName {
    switch (this) {
      case Slot.morning:
        return 'AM';
      case Slot.evening:
        return 'PM';
    }
  }

  /// Start hour of the slot (24-hour format).
  int get startHour {
    switch (this) {
      case Slot.morning:
        return 6; // 6:00 AM
      case Slot.evening:
        return 14; // 2:00 PM
    }
  }

  /// End hour of the slot (24-hour format).
  int get endHour {
    switch (this) {
      case Slot.morning:
        return 14; // 2:00 PM
      case Slot.evening:
        return 22; // 10:00 PM
    }
  }

  /// Get the scheduled start time for today.
  DateTime get scheduledStartTime {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, startHour, 0);
  }

  /// Get the scheduled end time for today.
  DateTime get scheduledEndTime {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, endHour, 0);
  }

  /// Time window tolerance in minutes (±15 minutes).
  static const int timeWindowMinutes = 15;

  /// Check if current time is within check-in window.
  /// Check-in allowed: slotStartTime ± 15 minutes.
  bool get isWithinCheckInWindow {
    final now = DateTime.now();
    final windowStart = scheduledStartTime.subtract(
      const Duration(minutes: timeWindowMinutes),
    );
    final windowEnd = scheduledStartTime.add(
      const Duration(minutes: timeWindowMinutes),
    );
    return now.isAfter(windowStart) && now.isBefore(windowEnd);
  }

  /// Check if current time is within check-out window.
  /// Check-out allowed: slotEndTime ± 15 minutes.
  bool get isWithinCheckOutWindow {
    final now = DateTime.now();
    final windowStart = scheduledEndTime.subtract(
      const Duration(minutes: timeWindowMinutes),
    );
    final windowEnd = scheduledEndTime.add(
      const Duration(minutes: timeWindowMinutes),
    );
    return now.isAfter(windowStart) && now.isBefore(windowEnd);
  }

  /// Validate if check-in is allowed at the given time.
  TimeWindowValidation validateCheckInTime(DateTime time) {
    final windowStart = scheduledStartTime.subtract(
      const Duration(minutes: timeWindowMinutes),
    );
    final windowEnd = scheduledStartTime.add(
      const Duration(minutes: timeWindowMinutes),
    );

    if (time.isBefore(windowStart)) {
      final diff = windowStart.difference(time);
      return TimeWindowValidation.tooEarly(
        message: 'Check-in opens in ${_formatDuration(diff)}',
        minutesRemaining: diff.inMinutes,
      );
    }

    if (time.isAfter(windowEnd)) {
      return TimeWindowValidation.tooLate(
        message: 'Check-in window closed for $displayName slot',
      );
    }

    return TimeWindowValidation.valid();
  }

  /// Validate if check-out is allowed at the given time.
  TimeWindowValidation validateCheckOutTime(DateTime time) {
    final windowStart = scheduledEndTime.subtract(
      const Duration(minutes: timeWindowMinutes),
    );
    final windowEnd = scheduledEndTime.add(
      const Duration(minutes: timeWindowMinutes),
    );

    if (time.isBefore(windowStart)) {
      final diff = windowStart.difference(time);
      return TimeWindowValidation.tooEarly(
        message: 'Check-out opens in ${_formatDuration(diff)}',
        minutesRemaining: diff.inMinutes,
      );
    }

    if (time.isAfter(windowEnd)) {
      return TimeWindowValidation.tooLate(
        message: 'Check-out window closed for $displayName slot',
      );
    }

    return TimeWindowValidation.valid();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Parse from string (case-insensitive).
  static Slot? fromString(String? value) {
    if (value == null) return null;
    return Slot.values.cast<Slot?>().firstWhere(
      (s) => s?.name.toLowerCase() == value.toLowerCase(),
      orElse: () => null,
    );
  }
}

/// Result of time window validation for check-in/check-out.
class TimeWindowValidation {
  const TimeWindowValidation._({
    required this.isValid,
    this.message,
    this.minutesRemaining,
    this.isTooEarly = false,
    this.isTooLate = false,
  });

  final bool isValid;
  final String? message;
  final int? minutesRemaining;
  final bool isTooEarly;
  final bool isTooLate;

  factory TimeWindowValidation.valid() {
    return const TimeWindowValidation._(isValid: true);
  }

  factory TimeWindowValidation.tooEarly({
    required String message,
    int? minutesRemaining,
  }) {
    return TimeWindowValidation._(
      isValid: false,
      message: message,
      minutesRemaining: minutesRemaining,
      isTooEarly: true,
    );
  }

  factory TimeWindowValidation.tooLate({required String message}) {
    return TimeWindowValidation._(
      isValid: false,
      message: message,
      isTooLate: true,
    );
  }
}
