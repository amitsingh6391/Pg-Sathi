import 'package:dartz/dartz.dart';

import '../core/core.dart';
import '../entities/notice_whatsapp_result.dart';
import '../repositories/whatsapp_notification_repository.dart';

/// Broadcasts a published notice to the library's students on WhatsApp.
class SendNoticeWhatsApp implements UseCase<NoticeWhatsAppResult, String> {
  const SendNoticeWhatsApp({required this.repository});

  final WhatsAppNotificationRepository repository;

  @override
  Future<Either<Failure, NoticeWhatsAppResult>> call(String noticeId) {
    return repository.sendNoticeWhatsApp(noticeId);
  }
}
