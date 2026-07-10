import 'package:flutter/material.dart';

import '../../../core/app_ui_constants.dart';

/// Badge showing days until membership expiry.
class ExpiryBadge extends StatelessWidget {
  const ExpiryBadge({super.key, required this.daysLeft});

  final int daysLeft;

  @override
  Widget build(BuildContext context) {
    final isUrgent = daysLeft <= 1;
    final color = isUrgent ? AppUIConstants.error : AppUIConstants.warning;

    String text;
    if (daysLeft == 0) {
      text = 'Today';
    } else if (daysLeft == 1) {
      text = 'Tomorrow';
    } else {
      text = '$daysLeft days';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
