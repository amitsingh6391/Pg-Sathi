import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

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
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppUIConstants.primarySoft,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            ),
            child: Icon(icon, size: 18, color: AppUIConstants.primaryLight),
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: double.tryParse(value) ?? 0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Text(
              double.tryParse(value) == null ? value : v.round().toString(),
              style: AppUIConstants.statValue,
            ),
          ),
          const SizedBox(height: 2),
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
    return Material(
      color: AppUIConstants.surfaceMuted,
      borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
            border: Border.all(
              color: AppUIConstants.primaryLight.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppUIConstants.primaryLight, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
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
      ),
    );
  }
}

/// Vertical timeline step used in "How it works".
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
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppUIConstants.primarySoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppUIConstants.primaryLight),
                ),
                alignment: Alignment.center,
                child: Text(
                  number,
                  style: const TextStyle(
                    color: AppUIConstants.primaryLight,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: AppUIConstants.border),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppUIConstants.bodyLg),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppUIConstants.bodySm),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Timeline row for the referral history (dot + connector + content).
class ReferralTimelineTile extends StatelessWidget {
  const ReferralTimelineTile({
    super.key,
    required this.title,
    required this.color,
    required this.icon,
    this.subtitle,
    this.trailing,
    this.isLast = false,
  });

  final String title;
  final String? subtitle;
  final String? trailing;
  final Color color;
  final IconData icon;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppUIConstants.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 14,
                  color: AppUIConstants.textSecondary,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: AppUIConstants.border),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14, top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppUIConstants.bodyLg),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle!,
                              style: AppUIConstants.bodySm,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null)
                    Text(trailing!, style: AppUIConstants.caption),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pulsing placeholder block for skeleton loading.
class ReferralSkeletonBox extends StatelessWidget {
  const ReferralSkeletonBox({super.key, required this.height, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.35, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (_, v, _) => Opacity(
        opacity: v,
        child: Container(
          height: height,
          width: width ?? double.infinity,
          decoration: BoxDecoration(
            color: AppUIConstants.surfaceMuted,
            borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          ),
        ),
      ),
    );
  }
}
