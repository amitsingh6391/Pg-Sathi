import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../domain/repositories/notification_repository.dart';
import '../../../core/app_ui_constants.dart';
import '../../../../domain/usecases/get_expiring_trials.dart';
import '../../utils/admin_contact_helper.dart';
import '../../utils/subscription_messaging_helper.dart';
import '../subscription_widgets/expiry_card_shell.dart';

/// Card widget to display an expiring trial with action buttons.
class ExpiringTrialCard extends StatelessWidget {
  const ExpiringTrialCard({
    required this.trialInfo,
    this.customMessage,
    super.key,
  });

  final ExpiringTrialInfo trialInfo;
  final String? customMessage;

  Future<void> _callOwner(BuildContext context) async {
    if (trialInfo.ownerPhone.isEmpty) {
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

    final success = await AdminContactHelper.callOwner(trialInfo.ownerPhone);
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
    if (trialInfo.ownerPhone.isEmpty) {
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

    final message =
        customMessage ??
        SubscriptionMessagingHelper.generateExpiringTrialMessage(
          ownerName: trialInfo.ownerName,
          libraryName: trialInfo.libraryName,
          expiryDate: trialInfo.trial.endDate,
          daysRemaining: trialInfo.daysRemaining,
        );

    final processedMessage = message
        .replaceAll('{name}', trialInfo.ownerName)
        .replaceAll('{library}', trialInfo.libraryName)
        .replaceAll(
          '{date}',
          DateFormat('dd MMM yyyy').format(trialInfo.trial.endDate),
        )
        .replaceAll('{days}', '${trialInfo.daysRemaining}');

    await AdminContactHelper.sendWhatsApp(
      phone: trialInfo.ownerPhone,
      message: processedMessage,
    );
  }

  Future<void> _sendPushNotification(BuildContext context) async {
    final title = SubscriptionMessagingHelper.getExpiringTrialTitle(
      trialInfo.daysRemaining,
    );
    final body =
        SubscriptionMessagingHelper.generateExpiringTrialNotificationBody(
          libraryName: trialInfo.libraryName,
          daysRemaining: trialInfo.daysRemaining,
        );

    final notificationRepo = sl<NotificationRepository>();
    await notificationRepo.sendNotificationToUser(
      userId: trialInfo.ownerId,
      title: title,
      body: body,
      data: {'type': 'trial_expiring', 'libraryId': trialInfo.libraryId},
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
    return ExpiryCardShell(
      title: trialInfo.libraryName,
      subtitle: trialInfo.ownerName,
      daysRemaining: trialInfo.daysRemaining,
      isUrgent: trialInfo.isUrgent,
      dateLabel:
          'Trial ends ${DateFormat('dd MMM yyyy').format(trialInfo.trial.endDate)}',
      onCall: () => _callOwner(context),
      onWhatsApp: () => _sendWhatsApp(context),
      onPush: () => _sendPushNotification(context),
    );
  }
}
