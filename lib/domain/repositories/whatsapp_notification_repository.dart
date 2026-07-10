import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/invoice.dart';

/// Outcome of a WhatsApp notice broadcast.
class NoticeWhatsAppResult {
  const NoticeWhatsAppResult({
    required this.sent,
    required this.failed,
    required this.remaining,
    this.skippedReason,
  });

  final int sent;
  final int failed;

  /// Remaining free broadcasts for the library this month.
  final int remaining;

  /// Non-null when the server skipped the broadcast, e.g. 'monthly_limit'
  /// or 'no_recipients'.
  final String? skippedReason;

  bool get wasSkipped => skippedReason != null;
}

abstract class WhatsAppNotificationRepository {
  Future<Either<Failure, void>> sendInvoiceWhatsApp(Invoice invoice);

  /// Broadcasts a published notice to the library's active tenants.
  Future<Either<Failure, NoticeWhatsAppResult>> sendNoticeWhatsApp({
    required String libraryId,
    required String noticeId,
    required String libraryName,
    required String title,
    required String description,
  });

  /// Reads how many free notice broadcasts remain for the library this month.
  Future<Either<Failure, int>> getRemainingNoticeQuota(String libraryId);
}
