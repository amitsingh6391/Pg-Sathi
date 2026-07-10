import 'package:flutter/material.dart';

import '../../core/app_ui_constants.dart';

class ReferralStatTile extends StatelessWidget {
  const ReferralStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppUIConstants.cardDecoration,
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppUIConstants.secondary),
          const SizedBox(height: 8),
          Text(value, style: AppUIConstants.headingMd),
          const SizedBox(height: 4),
          Text(label, style: AppUIConstants.caption),
        ],
      ),
    );
  }
}

class ReferralRewardOptionButton extends StatelessWidget {
  const ReferralRewardOptionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppUIConstants.background,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
          border: Border.all(color: AppUIConstants.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppUIConstants.primary, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppUIConstants.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppUIConstants.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class ReferralHowItWorksStep extends StatelessWidget {
  const ReferralHowItWorksStep({
    super.key,
    required this.number,
    required this.title,
    required this.subtitle,
    this.isLast = false,
  });

  final String number;
  final String title;
  final String subtitle;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: AppUIConstants.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppUIConstants.bodyLg),
                const SizedBox(height: 2),
                Text(subtitle, style: AppUIConstants.bodySm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
