import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../domain/entities/library.dart';
import '../../../../domain/entities/subscription.dart';
import '../../../../domain/repositories/notification_repository.dart';
import '../../../core/app_ui_constants.dart';
import '../../utils/admin_contact_helper.dart';
import '../../utils/subscription_messaging_helper.dart';
import '../subscription_widgets/expiry_card_shell.dart';

/// Card widget to display an expiring subscription with action buttons.
class ExpiringSubscriptionCard extends StatelessWidget {
  const ExpiringSubscriptionCard({
    required this.subscription,
    this.library,
    this.ownerName,
    this.ownerPhone,
    this.customMessage,
    super.key,
  });

  final Subscription subscription;
  final Library? library;
  final String? ownerName;
  final String? ownerPhone;
  final String? customMessage;

  Future<void> _callOwner(BuildContext context) async {
    if (ownerPhone == null || ownerPhone!.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Owner phone number not available'),
            backgroundColor: AppUIConstants.warning,
          ),
        );
      }
      return;
    }

    final success = await AdminContactHelper.callOwner(ownerPhone!);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open phone dialer'),
          backgroundColor: AppUIConstants.error,
        ),
      );
    }
  }

  Future<void> _sendWhatsApp(BuildContext context) async {
    if (library == null || ownerPhone == null || ownerPhone!.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Owner phone number not available'),
            backgroundColor: AppUIConstants.warning,
          ),
        );
      }
      return;
    }

    final now = DateTime.now();
    final daysRemaining = subscription.daysRemaining(now);
    final message =
        customMessage ??
        SubscriptionMessagingHelper.generateExpiringSubscriptionMessage(
          ownerName: ownerName ?? 'Owner',
          libraryName: library!.name,
          expiryDate: subscription.endDate,
          daysRemaining: daysRemaining,
          amount: subscription.finalAmount,
        );

    final processedMessage = message
        .replaceAll('{name}', ownerName ?? 'Owner')
        .replaceAll('{library}', library!.name)
        .replaceAll(
          '{date}',
          DateFormat('dd MMM yyyy').format(subscription.endDate),
        )
        .replaceAll('{days}', '$daysRemaining');

    await AdminContactHelper.sendWhatsApp(
      phone: ownerPhone!,
      message: processedMessage,
    );
  }

  Future<void> _sendPushNotification(BuildContext context) async {
    if (library == null) return;

    final now = DateTime.now();
    final daysRemaining = subscription.daysRemaining(now);
    final title = SubscriptionMessagingHelper.getExpiringSubscriptionTitle(
      daysRemaining,
    );
    final body =
        SubscriptionMessagingHelper.generateExpiringSubscriptionNotificationBody(
          libraryName: library!.name,
          daysRemaining: daysRemaining,
        );

    final notificationRepo = sl<NotificationRepository>();
    await notificationRepo.sendNotificationToUser(
      userId: subscription.ownerId,
      title: title,
      body: body,
      data: {'type': 'subscription_expiring', 'libraryId': library!.id},
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Push notification sent'),
          backgroundColor: AppUIConstants.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysRemaining = subscription.daysRemaining(DateTime.now());

    return ExpiryCardShell(
      title: library?.name ?? 'Unknown PG',
      subtitle: ownerName,
      daysRemaining: daysRemaining,
      isUrgent: daysRemaining <= 3,
      dateLabel:
          'Expires ${DateFormat('dd MMM yyyy').format(subscription.endDate)}',
      amount: subscription.finalAmount,
      callTooltip: 'Call Owner',
      onCall: () => _callOwner(context),
      onWhatsApp: () => _sendWhatsApp(context),
      onPush: () => _sendPushNotification(context),
    );
  }
}
