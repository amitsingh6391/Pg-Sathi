import 'dart:developer';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/core/failure.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/notice_whatsapp_result.dart';
import '../../domain/repositories/whatsapp_notification_repository.dart';
import '../failures/data_failures.dart';

class WhatsAppNotificationRepositoryImpl
    implements WhatsAppNotificationRepository {
  const WhatsAppNotificationRepositoryImpl({
    required FirebaseFunctions functions,
  }) : _functions = functions;

  final FirebaseFunctions _functions;

  @override
  Future<Either<Failure, void>> sendInvoiceWhatsApp(Invoice invoice) async {
    if (invoice.studentPhone.trim().isEmpty) {
      log('[WhatsApp] Skipped — no phone for invoice ${invoice.invoiceNumber}');
      return const Right(null);
    }

    // Ensure a valid ID token is available before making the callable.
    // Fire-and-forget calls run in a detached async context where the token
    // may not have been automatically refreshed yet.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      log('[WhatsApp] Skipped — no authenticated user');
      return const Right(null);
    }
    try {
      await user.getIdToken(
        true,
      ); // force refresh so the callable carries a fresh token
    } catch (e) {
      log(
        '[WhatsApp] Token refresh failed: $e — skipping to avoid UNAUTHENTICATED error',
      );
      return const Right(null);
    }

    try {
      log(
        '[WhatsApp] Calling sendWhatsAppInvoice for ${invoice.invoiceNumber} → ${invoice.studentPhone}',
      );
      final callable = _functions.httpsCallable(
        'sendWhatsAppInvoice',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
      );
      final result = await callable.call<Map<String, dynamic>>(
        _invoiceToPayload(invoice),
      );
      final data = result.data;
      log('[WhatsApp] sendWhatsAppInvoice result: $data');
      if (data['skipped'] == true) {
        final reason = data['reason'] ?? 'unknown';
        log(
          '[WhatsApp] Invoice ${invoice.invoiceNumber} skipped by server: $reason',
        );
      }
      return const Right(null);
    } on FirebaseFunctionsException catch (e) {
      log(
        '[WhatsApp] FirebaseFunctionsException [${e.code}]: ${e.message} | details: ${e.details}',
      );
      return Left(
        ServerFailure(
          message: 'WhatsApp invoice failed [${e.code}]: ${e.message}',
        ),
      );
    } catch (e, st) {
      log('[WhatsApp] Unexpected error: $e', stackTrace: st);
      return Left(ServerFailure(message: 'WhatsApp invoice error: $e'));
    }
  }

  @override
  Future<Either<Failure, NoticeWhatsAppResult>> sendNoticeWhatsApp(
    String noticeId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      log('[WhatsApp] Notice skipped — no authenticated user');
      return Left(ServerFailure(message: 'Not signed in'));
    }
    try {
      await user.getIdToken(true); // fresh token to avoid UNAUTHENTICATED
    } catch (e) {
      log('[WhatsApp] Notice token refresh failed: $e');
      return Left(ServerFailure(message: 'Authentication failed'));
    }

    try {
      log('[WhatsApp] Calling sendWhatsAppNotice for notice $noticeId');
      final result = await _functions
          .httpsCallable(
            'sendWhatsAppNotice',
            options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
          )
          .call<Map<String, dynamic>>({'noticeId': noticeId});
      log('[WhatsApp] sendWhatsAppNotice result: ${result.data}');
      return Right(NoticeWhatsAppResult.fromMap(result.data));
    } on FirebaseFunctionsException catch (e) {
      log(
        '[WhatsApp] Notice FirebaseFunctionsException [${e.code}]: ${e.message}',
      );
      return Left(
        ServerFailure(
          message: 'WhatsApp notice failed [${e.code}]: ${e.message}',
        ),
      );
    } catch (e, st) {
      log('[WhatsApp] Notice unexpected error: $e', stackTrace: st);
      return Left(ServerFailure(message: 'WhatsApp notice error: $e'));
    }
  }

  Map<String, dynamic> _invoiceToPayload(Invoice invoice) {
    return {
      'membershipId': invoice.membershipId,
      'invoiceNumber': invoice.invoiceNumber,
      'paymentId': invoice.paymentId,
      'libraryId': invoice.libraryId,
      'ownerId': invoice.ownerId,
      'isManual': false,
      'studentPhone': invoice.studentPhone,
      'studentName': invoice.studentName,
      'libraryName': invoice.libraryName,
      'libraryAddress': invoice.libraryAddress,
      'libraryLogoUrl': invoice.libraryLogoUrl ?? '',
      'ownerName': invoice.ownerName,
      'ownerContact': invoice.ownerContact,
      'seatNumber': invoice.seatNumber,
      'slotName': invoice.slotName ?? '',
      'sessionTiming': invoice.sessionTiming,
      'plan': invoice.slotName ?? invoice.slot.name,
      'amountPaid': invoice.amountPaid,
      'discountAmount': 0,
      'paymentDate': invoice.paymentDate.toIso8601String(),
      'expiryDate': invoice.expiryDate.toIso8601String(),
      'billingMonth': invoice.billingMonth,
    };
  }
}
