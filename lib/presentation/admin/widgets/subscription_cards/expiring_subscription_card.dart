import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../domain/entities/library.dart';
import '../../../../domain/entities/subscription.dart';
import '../../../../domain/repositories/notification_repository.dart';
import '../../../core/app_ui_constants.dart';
import '../../utils/admin_contact_helper.dart';
import '../../utils/subscription_messaging_helper.dart';

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
    final now = DateTime.now();
    final daysRemaining = subscription.daysRemaining(now);
    final isUrgent = daysRemaining <= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUrgent
              ? AppUIConstants.warning.withValues(alpha: 0.5)
              : AppUIConstants.divider.withValues(alpha: 0.1),
          width: isUrgent ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      library?.name ?? 'Unknown Library',
                      style: AppUIConstants.bodyLg.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (ownerName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        ownerName!,
                        style: AppUIConstants.bodySm.copyWith(
                          color: AppUIConstants.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isUrgent
                      ? AppUIConstants.warning.withValues(alpha: 0.15)
                      : AppUIConstants.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: isUrgent
                          ? AppUIConstants.warning
                          : AppUIConstants.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      daysRemaining < 0
                          ? 'Expired'
                          : daysRemaining == 0
                          ? 'Today'
                          : daysRemaining == 1
                          ? 'Tomorrow'
                          : '$daysRemaining days',
                      style: AppUIConstants.bodySm.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isUrgent
                            ? AppUIConstants.warning
                            : AppUIConstants.primary,
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
                'Expires: ${DateFormat('dd MMM yyyy').format(subscription.endDate)}',
                style: AppUIConstants.bodySm.copyWith(
                  color: AppUIConstants.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '₹${subscription.finalAmount.toStringAsFixed(0)}',
                style: AppUIConstants.bodyMd.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppUIConstants.primary,
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
                tooltip: 'Call Owner',
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
