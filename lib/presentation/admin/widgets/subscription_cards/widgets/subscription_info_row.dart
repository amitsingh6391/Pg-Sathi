import 'package:material_ui/material_ui.dart';

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
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _Chip(
              icon: Icons.bed_outlined,
              text: '${subscription.seatCount} Beds',
            ),
            _Chip(
              icon: Icons.calendar_month_outlined,
              text: '${subscription.durationInMonths}M',
            ),
          ],
        ),
        const SizedBox(height: 10),
        _InfoItem(
          icon: Icons.schedule_outlined,
          text:
              '${dateFormat.format(subscription.startDate)} → ${dateFormat.format(subscription.endDate)}',
          isSmall: true,
        ),
        if (subscription.transactionId != null) ...[
          const SizedBox(height: 6),
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

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppUIConstants.surfaceMuted,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppUIConstants.textSecondary),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppUIConstants.textPrimary,
            ),
          ),
        ],
      ),
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
      children: [
        Icon(icon, size: isSmall ? 13 : 15, color: AppUIConstants.textTertiary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: (isSmall ? AppUIConstants.caption : AppUIConstants.bodySm)
                .copyWith(
                  color: AppUIConstants.textSecondary,
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
