import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/whatsapp_reminder.dart';

/// Repository for WhatsApp reminder operations.
abstract class WhatsAppReminderRepository {
  /// Fetches expiring memberships with WhatsApp-ready data.
  Future<Either<Failure, List<WhatsAppReminder>>> getExpiringReminders({
    required String libraryId,
    required int daysThreshold,
  });

  /// Logs a WhatsApp reminder sent to a student.
  Future<Either<Failure, void>> logReminderSent({required String membershipId});
}
