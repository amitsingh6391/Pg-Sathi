import 'dart:developer';

import 'package:dartz/dartz.dart';

import '../core/core.dart';
import '../entities/invoice.dart';
import '../repositories/whatsapp_notification_repository.dart';

class SendWhatsAppInvoice implements UseCase<void, Invoice> {
  const SendWhatsAppInvoice({
    required this.whatsAppNotificationRepository,
  });

  final WhatsAppNotificationRepository whatsAppNotificationRepository;

  @override
  Future<Either<Failure, void>> call(Invoice invoice) async {
    if (invoice.studentPhone.trim().isEmpty) {
      log('SendWhatsAppInvoice: skipped — no student phone on invoice ${invoice.id}');
      return const Right(null);
    }

    log('SendWhatsAppInvoice: sending invoice ${invoice.invoiceNumber} '
        'to ${invoice.studentPhone}');

    final result =
        await whatsAppNotificationRepository.sendInvoiceWhatsApp(invoice);

    result.fold(
      (failure) => log('SendWhatsAppInvoice: failed — ${failure.message}'),
      (_) => log('SendWhatsAppInvoice: sent ✓ (${invoice.invoiceNumber})'),
    );

    // Always return Right — WhatsApp delivery failure must never block
    // or surface errors to the owner/student.
    return const Right(null);
  }
}
