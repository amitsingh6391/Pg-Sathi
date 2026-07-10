import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../domain/entities/custom_slot.dart';
import '../../../../domain/entities/library.dart';
import '../../../../domain/entities/payment.dart';
import '../../../../domain/entities/payment_breakdown.dart';
import '../../../../domain/repositories/membership_repository.dart';
import '../../../../domain/repositories/notification_repository.dart';
import '../../../../domain/usecases/get_occupied_seats.dart';
import '../../../../domain/usecases/mark_payment_received.dart';
import '../../../../domain/usecases/send_payment_reminder.dart';
import '../../../auth/cubit/phone_auth_cubit.dart';
import '../../cubit/occupied_seats_cubit.dart';
import 'convert_payment_bottom_sheet.dart';
import 'occupied_seats_actions.dart'
    show calculateFullPaymentAmount, showOccupiedSeatsSnackBar;
import 'reminder_dialog.dart' show showReminderBottomSheet;
import 'reminder_whatsapp_helper.dart' show ReminderType;

// ---------------------------------------------------------------------------
// Convert pending / mark payment
// ---------------------------------------------------------------------------

/// Shows the convert-to-active payment bottom sheet.
void showConvertPendingDialog(
  BuildContext context, {
  required OccupiedSeatInfo seatInfo,
  required List<CustomSlot> customSlots,
  required void Function(String message, {required bool isError}) onSnackBar,
  required void Function(
    OccupiedSeatInfo seatInfo,
    String ownerId, {
    double? amountPaid,
    bool isPartial,
    String? notes,
    double discount,
    required PaymentMode paymentMethod,
  })
  onExecute,
}) {
  final membership = seatInfo.membership;
  final fullAmount = calculateFullPaymentAmount(membership, customSlots);
  final existingPaid = membership.paymentBreakdown?.amountPaid ?? 0.0;
  final existingRemaining = membership.paymentBreakdown?.amountRemaining ?? 0.0;
  final existingDiscount = membership.paymentBreakdown?.discount ?? 0.0;
  final hasExistingPartial = membership.hasPartialPayment;

  final owner = context.read<PhoneAuthCubit>().state.currentUser;
  if (owner == null) {
    onSnackBar('Owner not found', isError: true);
    return;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => ConvertPaymentBottomSheet(
      seatInfo: seatInfo,
      fullAmount: fullAmount,
      existingPaid: existingPaid,
      existingRemaining: existingRemaining,
      existingDiscount: existingDiscount,
      hasExistingPartial: hasExistingPartial,
      onConvert: (amountPaid, isPartial, notes, discount, paymentMethod) {
        Navigator.of(sheetContext).pop();
        onExecute(
          seatInfo,
          owner.id,
          amountPaid: amountPaid,
          isPartial: isPartial,
          notes: notes,
          discount: discount,
          paymentMethod: paymentMethod,
        );
      },
    ),
  );
}

/// Executes the payment conversion: updates breakdown, marks payment received.
Future<void> executeConvertPending(
  BuildContext context, {
  required OccupiedSeatInfo seatInfo,
  required String ownerId,
  required List<CustomSlot> customSlots,
  required OccupiedSeatsCubit cubit,
  required void Function(String message, {required bool isError}) onSnackBar,
  double? amountPaid,
  bool isPartial = false,
  String? notes,
  double discount = 0.0,
  required PaymentMode paymentMethod,
}) async {
  onSnackBar('Processing...', isError: false);

  final hasExistingPartial = seatInfo.membership.hasPartialPayment;
  final fullAmount = calculateFullPaymentAmount(
    seatInfo.membership,
    customSlots,
  );
  final finalAmount = (fullAmount - discount).clamp(0.0, double.infinity);

  final existingPaid = seatInfo.membership.paymentBreakdown?.amountPaid ?? 0.0;

  double cumulativeAmountPaid;
  if (hasExistingPartial && amountPaid != null) {
    cumulativeAmountPaid = existingPaid + amountPaid;
  } else if (amountPaid != null) {
    cumulativeAmountPaid = amountPaid;
  } else {
    cumulativeAmountPaid = finalAmount;
  }

  final remainingAmount = (finalAmount - cumulativeAmountPaid).clamp(
    0.0,
    double.infinity,
  );

  final updatedMembership = seatInfo.membership.copyWith(
    paymentBreakdown: PaymentBreakdown(
      amountPaid: cumulativeAmountPaid,
      amountRemaining: remainingAmount,
      notes: notes,
      discount: discount,
    ),
    paymentMethod: paymentMethod,
  );

  final membershipRepo = sl<MembershipRepository>();
  final updateResult = await membershipRepo.updateMembership(updatedMembership);

  if (updateResult.isLeft()) {
    onSnackBar('Failed to update rent details', isError: true);
    return;
  }

  final useCase = sl<MarkPaymentReceived>();
  final result = await useCase(
    MarkPaymentReceivedParams(
      membershipId: seatInfo.membership.id,
      ownerId: ownerId,
    ),
  );

  result.fold(
    (failure) {
      onSnackBar(failure.message ?? 'Failed to activate stay', isError: true);
    },
    (markPaymentResult) {
      final invoiceNumber = markPaymentResult.invoice?.invoiceNumber;
      final hasNewPayment = markPaymentResult.payment.amount > 0;
      final message = isPartial
          ? (hasNewPayment && invoiceNumber != null
                ? 'Partial rent marked! Invoice #$invoiceNumber generated'
                : 'Rent breakdown updated successfully')
          : invoiceNumber != null
          ? 'Stay activated! Invoice #$invoiceNumber generated'
          : 'Stay activated successfully';
      onSnackBar(message, isError: false);
      cubit.refresh();
    },
  );
}

// ---------------------------------------------------------------------------
// Reminder
// ---------------------------------------------------------------------------

/// Shows the reminder bottom sheet with Push/WhatsApp options.
void sendOccupiedSeatsReminder(
  BuildContext context, {
  required OccupiedSeatInfo seatInfo,
  required Library library,
  required List<CustomSlot> customSlots,
}) {
  final hasPartialPayment = seatInfo.membership.hasPartialPayment;
  final remaining =
      seatInfo.membership.paymentBreakdown?.amountRemaining ?? 0.0;
  final isPending = seatInfo.isReserved;

  String notificationTitle;
  String notificationBody;
  ReminderType reminderType;
  double? amount;

  if (isPending) {
    final fullAmount = calculateFullPaymentAmount(
      seatInfo.membership,
      customSlots,
    );
    notificationTitle = 'Rent Pending';
    notificationBody =
        'Your rent payment of ₹${fullAmount.toStringAsFixed(0)} is pending. Please complete the payment to activate your stay.';
    reminderType = ReminderType.pendingPayment;
    amount = fullAmount;
  } else if (hasPartialPayment) {
    notificationTitle = 'Rent Reminder';
    notificationBody =
        'You have a remaining rent balance of ₹${remaining.toStringAsFixed(0)}. Please complete your payment to keep your stay active.';
    reminderType = ReminderType.partialPayment;
    amount = remaining;
  } else {
    notificationTitle = 'Stay Renewal Reminder';
    notificationBody =
        'Your stay is expiring soon. Please renew at your convenience to continue your bed.';
    reminderType = ReminderType.expiry;
    amount = null;
  }

  showReminderBottomSheet(
    context: context,
    seatInfo: seatInfo,
    library: library,
    notificationTitle: notificationTitle,
    notificationBody: notificationBody,
    amount: amount,
    reminderType: reminderType,
    onSendPushNotification: (editedBody) async {
      await executeSendReminder(
        context,
        seatInfo: seatInfo,
        customSlots: customSlots,
        bodyOverride: editedBody,
      );
    },
  );
}

/// Executes sending the push notification reminder.
Future<void> executeSendReminder(
  BuildContext context, {
  required OccupiedSeatInfo seatInfo,
  required List<CustomSlot> customSlots,
  String? bodyOverride,
}) async {
  if (seatInfo.membership.userId == null) {
    if (context.mounted) {
      showOccupiedSeatsSnackBar(
        context,
        'No user associated with this stay',
        isError: true,
      );
    }
    return;
  }

  final hasPartialPayment = seatInfo.membership.hasPartialPayment;
  final isPending = seatInfo.isReserved;

  String notificationTitle;
  String notificationBody;
  Map<String, dynamic> notificationData;

  if (isPending) {
    final fullAmount = calculateFullPaymentAmount(
      seatInfo.membership,
      customSlots,
    );
    notificationTitle = 'Rent Pending';
    notificationBody =
        'Your rent payment of ₹${fullAmount.toStringAsFixed(0)} is pending. Please complete the payment to activate your stay.';
    notificationData = {
      'type': 'payment_reminder',
      'libraryId': seatInfo.membership.libraryId,
      'membershipId': seatInfo.membership.id,
      'isPending': true,
    };
  } else if (hasPartialPayment) {
    final useCase = sl<SendPaymentReminder>();
    final result = await useCase(
      SendPaymentReminderParams(membershipId: seatInfo.membership.id),
    );
    if (context.mounted) {
      result.fold(
        (failure) => showOccupiedSeatsSnackBar(
          context,
          failure.message ?? 'Failed',
          isError: true,
        ),
        (_) => showOccupiedSeatsSnackBar(
          context,
          'Reminder sent successfully',
          isError: false,
        ),
      );
    }
    return;
  } else {
    notificationTitle = 'Stay Renewal Reminder';
    notificationBody =
        'Your stay is expiring soon. Please renew at your convenience to continue your bed.';
    notificationData = {
      'type': 'membership_expiry_reminder',
      'libraryId': seatInfo.membership.libraryId,
      'membershipId': seatInfo.membership.id,
    };
  }

  final notificationRepository = sl<NotificationRepository>();
  final result = await notificationRepository.sendNotificationToUser(
    userId: seatInfo.membership.userId!,
    title: notificationTitle,
    body: bodyOverride ?? notificationBody,
    data: notificationData,
  );
  if (context.mounted) {
    result.fold(
      (failure) => showOccupiedSeatsSnackBar(
        context,
        failure.message ?? 'Failed to send notification',
        isError: true,
      ),
      (_) => showOccupiedSeatsSnackBar(
        context,
        'Reminder sent successfully',
        isError: false,
      ),
    );
  }
}
