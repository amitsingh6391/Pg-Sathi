import 'package:flutter/material.dart';

import '../../core/app_ui_constants.dart';

/// Quick action buttons for admin dashboard.
class AdminQuickActions extends StatelessWidget {
  const AdminQuickActions({
    super.key,
    required this.onInvoicesTap,
    required this.onLibrariesTap,
    required this.onSubscriptionsTap,
    this.onFeatureAnalyticsTap,
  });

  final VoidCallback onInvoicesTap;
  final VoidCallback onLibrariesTap;
  final VoidCallback onSubscriptionsTap;
  final VoidCallback? onFeatureAnalyticsTap;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionItem(
        icon: Icons.receipt_long_outlined,
        label: 'Invoices',
        color: Colors.orange,
        onTap: onInvoicesTap,
      ),
      _ActionItem(
        icon: Icons.business_outlined,
        label: 'Libraries',
        color: Colors.blue,
        onTap: onLibrariesTap,
      ),
      _ActionItem(
        icon: Icons.card_membership_outlined,
        label: 'Subscriptions',
        color: Colors.purple,
        onTap: onSubscriptionsTap,
      ),
      if (onFeatureAnalyticsTap != null)
        _ActionItem(
          icon: Icons.analytics_outlined,
          label: 'Analytics',
          color: Colors.teal,
          onTap: onFeatureAnalyticsTap!,
        ),
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: AppUIConstants.headingSm),
        const SizedBox(height: AppUIConstants.spacingMd),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: actions.length == 4 ? 4 : 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.95,
          ),
          itemCount: actions.length,
          padding: EdgeInsets.zero,
          itemBuilder: (context, index) => _QuickActionCard(
            action: actions[index],
          ),
        ),
      ],
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action});

  final _ActionItem action;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: action.color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  action.icon,
                  color: action.color,
                  size: 20,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                action.label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
