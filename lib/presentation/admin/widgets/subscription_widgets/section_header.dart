import 'package:flutter/material.dart';

import '../../../core/app_ui_constants.dart';

/// Section header widget for subscription lists.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    required this.icon,
    this.count,
    super.key,
  });

  final String title;
  final IconData icon;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppUIConstants.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppUIConstants.bodyLg.copyWith(fontWeight: FontWeight.bold),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppUIConstants.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: AppUIConstants.caption.copyWith(
                fontWeight: FontWeight.bold,
                color: AppUIConstants.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
