import 'package:flutter/material.dart';

import '../../../../../domain/entities/subscription.dart';
import '../../../../core/app_ui_constants.dart';

/// Displays subscription info (seats, duration, dates, transaction ID)
class SubscriptionInfoRow extends StatelessWidget {
  const SubscriptionInfoRow({
    required this.subscription,
    required this.dateFormat,
    super.key,
  });

  final Subscription subscription;
  final dynamic dateFormat;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: _InfoItem(
                icon: Icons.event_seat_outlined,
                text: '${subscription.seatCount} Seats',
              ),
            ),
            const SizedBox(width: 20),
            Flexible(
              child: _InfoItem(
                icon: Icons.calendar_month_outlined,
                text: '${subscription.durationInMonths}M',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _InfoItem(
          icon: Icons.schedule_outlined,
          text: '${dateFormat.format(subscription.startDate)} → ${dateFormat.format(subscription.endDate)}',
          isSmall: true,
        ),
        if (subscription.transactionId != null) ...[
          const SizedBox(height: 8),
          _InfoItem(
            icon: Icons.tag_outlined,
            text: subscription.transactionId!,
            isSmall: true,
            isMonospace: true,
          ),
        ],
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.icon,
    required this.text,
    this.isSmall = false,
    this.isMonospace = false,
  });

  final IconData icon;
  final String text;
  final bool isSmall;
  final bool isMonospace;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: isSmall ? 13 : 15,
          color: AppUIConstants.textSecondary.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: (isSmall ? AppUIConstants.caption : AppUIConstants.bodySm).copyWith(
              color: AppUIConstants.textPrimary,
              fontWeight: FontWeight.w500,
              fontFamily: isMonospace ? 'monospace' : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
