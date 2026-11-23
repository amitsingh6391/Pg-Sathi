import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/invoice.dart';
import '../entities/notice_whatsapp_result.dart';

abstract class WhatsAppNotificationRepository {
  Future<Either<Failure, void>> sendInvoiceWhatsApp(Invoice invoice);

  /// Broadcasts a published notice to the PG's active residents, charging
  /// 1 WhatsApp credit per message.
  Future<Either<Failure, NoticeWhatsAppResult>> sendNoticeWhatsApp(
    String noticeId,
  );
}
