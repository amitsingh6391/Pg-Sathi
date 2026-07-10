import 'package:equatable/equatable.dart';

/// Represents a WhatsApp reminder to be sent.
class WhatsAppReminder extends Equatable {
  const WhatsAppReminder({
    required this.studentId,
    required this.studentName,
    required this.studentPhone,
    required this.membershipId,
    required this.expiryDate,
    required this.libraryName,
    this.daysUntilExpiry = 0,
    this.lastReminderSentAt,
    this.reminderCount = 0,
    this.todayReminderCount = 0,
  });

  final String studentId;
  final String studentName;
  final String studentPhone;
  final String membershipId;
  final DateTime expiryDate;
  final String libraryName;
  final int daysUntilExpiry;
  final DateTime? lastReminderSentAt;
  final int reminderCount;
  final int todayReminderCount;

  /// Max reminders allowed per student per day.
  static const int maxRemindersPerStudentPerDay = 50;

  /// Whether max reminders reached for today.
  bool get wasSentToday => todayReminderCount >= maxRemindersPerStudentPerDay;

  /// Whether can send more reminders today.
  bool get canSendMoreToday =>
      todayReminderCount < maxRemindersPerStudentPerDay;

  /// Remaining reminders allowed today for this student.
  int get remainingRemindersToday =>
      maxRemindersPerStudentPerDay - todayReminderCount;

  /// Formatted phone for WhatsApp (with country code, no +).
  String get whatsappPhone {
    String phone = studentPhone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (phone.startsWith('+')) {
      phone = phone.substring(1);
    }
    if (!phone.startsWith('91') && phone.length == 10) {
      phone = '91$phone';
    }
    return phone;
  }

  /// Generate reminder message.
  String get message {
    final formattedDate =
        '${expiryDate.day}/${expiryDate.month}/${expiryDate.year}';

    if (daysUntilExpiry == 0) {
      return '''Hi $studentName! 👋

Your library membership at *$libraryName* expires *today* ($formattedDate).

Please renew to continue your seat without interruption.

Thank you! 📚''';
    } else if (daysUntilExpiry == 1) {
      return '''Hi $studentName! 👋

Your library membership at *$libraryName* expires *tomorrow* ($formattedDate).

Please renew to continue your seat without interruption.

Thank you! 📚''';
    } else {
      return '''Hi $studentName! 👋

Your library membership at *$libraryName* is expiring on *$formattedDate* ($daysUntilExpiry days left).

Please renew to continue your seat without interruption.

Thank you! 📚''';
    }
  }

  /// WhatsApp URL to open chat with pre-filled message.
  String get whatsappUrl {
    final encodedMessage = Uri.encodeComponent(message);
    return 'https://wa.me/$whatsappPhone?text=$encodedMessage';
  }

  /// Generate WhatsApp URL with custom message.
  String getWhatsappUrlWithCustomMessage(String customMessage) {
    // Replace placeholders in custom message
    final processedMessage = customMessage
        .replaceAll('{name}', studentName)
        .replaceAll('{library}', libraryName)
        .replaceAll(
          '{date}',
          '${expiryDate.day}/${expiryDate.month}/${expiryDate.year}',
        )
        .replaceAll('{days}', '$daysUntilExpiry');

    final encodedMessage = Uri.encodeComponent(processedMessage);
    return 'https://wa.me/$whatsappPhone?text=$encodedMessage';
  }

  @override
  List<Object?> get props => [
    studentId,
    studentName,
    studentPhone,
    membershipId,
    expiryDate,
    libraryName,
    daysUntilExpiry,
    lastReminderSentAt,
    reminderCount,
    todayReminderCount,
  ];
}

/// Daily usage stats for WhatsApp reminders.
class WhatsAppDailyUsage extends Equatable {
  const WhatsAppDailyUsage({
    required this.date,
    required this.messagesSent,
    required this.creditsUsed,
  });

  final DateTime date;
  final int messagesSent;
  final int creditsUsed;

  /// Max messages allowed per day.
  static const int maxMessagesPerDay = 1000;

  /// Remaining messages for today.
  int get remainingToday => maxMessagesPerDay - messagesSent;

  /// Whether limit is reached.
  bool get isLimitReached => messagesSent >= maxMessagesPerDay;

  @override
  List<Object?> get props => [date, messagesSent, creditsUsed];
}
