import 'package:material_ui/material_ui.dart';

import '../../../core/app_ui_constants.dart';

/// Shared visual shell for expiring subscription / trial cards: a countdown
/// ring-style chip, PG + owner info, expiry date and quick-contact actions.
class ExpiryCardShell extends StatelessWidget {
  const ExpiryCardShell({
    super.key,
    required this.title,
    this.subtitle,
    required this.daysRemaining,
    required this.isUrgent,
    required this.dateLabel,
    this.amount,
    required this.onCall,
    required this.onWhatsApp,
    required this.onPush,
    this.callTooltip = 'Call',
  });

  final String title;
  final String? subtitle;
  final int daysRemaining;
  final bool isUrgent;
  final String dateLabel;
  final double? amount;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback onPush;
  final String callTooltip;

  Color get _color => daysRemaining < 0
      ? AppUIConstants.error
      : isUrgent
      ? AppUIConstants.warning
      : AppUIConstants.success;

  String get _countText => daysRemaining < 0
      ? 'Expired'
      : daysRemaining == 0
      ? 'Today'
      : daysRemaining == 1
      ? 'Tomorrow'
      : '$daysRemaining days';

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
        border: Border.all(
          color: isUrgent || daysRemaining < 0
              ? color.withValues(alpha: 0.5)
              : AppUIConstants.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
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
                                title,
                                style: AppUIConstants.bodyLg.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subtitle!,
                                  style: AppUIConstants.bodySm,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(
                              AppUIConstants.radiusFull,
                            ),
                            border: Border.all(
                              color: color.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 14,
                                color: color,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _countText,
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
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
                        const Icon(
                          Icons.event_rounded,
                          size: 14,
                          color: AppUIConstants.textTertiary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(dateLabel, style: AppUIConstants.bodySm),
                        ),
                        if (amount != null)
                          Text(
                            '₹${amount!.toStringAsFixed(0)}',
                            style: AppUIConstants.bodyLg.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppUIConstants.primaryLight,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _Action(
                            icon: Icons.phone_rounded,
                            label: 'Call',
                            color: AppUIConstants.primaryLight,
                            tooltip: callTooltip,
                            onTap: onCall,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Action(
                            icon: Icons.chat_rounded,
                            label: 'WhatsApp',
                            color: AppUIConstants.success,
                            tooltip: 'WhatsApp',
                            onTap: onWhatsApp,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Action(
                            icon: Icons.notifications_active_rounded,
                            label: 'Push',
                            color: AppUIConstants.primaryLight,
                            tooltip: 'Push Notification',
                            onTap: onPush,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
