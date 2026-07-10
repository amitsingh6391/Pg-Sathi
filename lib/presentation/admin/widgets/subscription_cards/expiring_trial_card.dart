import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../domain/repositories/notification_repository.dart';
import '../../../core/app_ui_constants.dart';
import '../../../../domain/usecases/get_expiring_trials.dart';
import '../../utils/admin_contact_helper.dart';
import '../../utils/subscription_messaging_helper.dart';

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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: trialInfo.isUrgent
              ? AppUIConstants.warning.withValues(alpha: 0.5)
              : AppUIConstants.divider.withValues(alpha: 0.1),
          width: trialInfo.isUrgent ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppUIConstants.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.timer_rounded,
                  color: AppUIConstants.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trialInfo.libraryName,
                      style: AppUIConstants.bodyLg.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trialInfo.ownerName,
                      style: AppUIConstants.bodySm.copyWith(
                        color: AppUIConstants.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: trialInfo.daysRemaining < 0
                      ? AppUIConstants.error.withValues(alpha: 0.15)
                      : trialInfo.isUrgent
                      ? AppUIConstants.warning.withValues(alpha: 0.15)
                      : AppUIConstants.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: trialInfo.daysRemaining < 0
                          ? AppUIConstants.error
                          : trialInfo.isUrgent
                          ? AppUIConstants.warning
                          : AppUIConstants.accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      trialInfo.daysRemaining < 0
                          ? 'Expired'
                          : trialInfo.daysRemaining == 0
                          ? 'Today'
                          : trialInfo.daysRemaining == 1
                          ? 'Tomorrow'
                          : '${trialInfo.daysRemaining} days',
                      style: AppUIConstants.bodySm.copyWith(
                        fontWeight: FontWeight.bold,
                        color: trialInfo.daysRemaining < 0
                            ? AppUIConstants.error
                            : trialInfo.isUrgent
                            ? AppUIConstants.warning
                            : AppUIConstants.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: AppUIConstants.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Trial ends: ${DateFormat('dd MMM yyyy').format(trialInfo.trial.endDate)}',
                style: AppUIConstants.bodySm.copyWith(
                  color: AppUIConstants.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _ActionIconButton(
                icon: Icons.phone_rounded,
                color: AppUIConstants.success,
                onTap: () => _callOwner(context),
                tooltip: 'Call',
              ),
              const SizedBox(width: 8),
              _ActionIconButton(
                icon: Icons.message_rounded,
                color: AppUIConstants.primary,
                onTap: () => _sendWhatsApp(context),
                tooltip: 'WhatsApp',
              ),
              const SizedBox(width: 8),
              _ActionIconButton(
                icon: Icons.notifications_rounded,
                color: AppUIConstants.accent,
                onTap: () => _sendPushNotification(context),
                tooltip: 'Push Notification',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }
}
