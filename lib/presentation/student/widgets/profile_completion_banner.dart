import 'package:flutter/material.dart';

import '../../../domain/entities/user.dart';
import '../../core/app_ui_constants.dart';

/// Non-blocking banner to encourage profile completion - minimal design.
class ProfileCompletionBanner extends StatelessWidget {
  const ProfileCompletionBanner({
    super.key,
    required this.user,
    required this.onComplete,
    required this.onSkip,
  });

  final User user;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppUIConstants.spacingLg),
      padding: const EdgeInsets.all(AppUIConstants.spacingLg),
      decoration: BoxDecoration(
        color: AppUIConstants.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(
          color: AppUIConstants.warning.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.person_outline_rounded,
            color: AppUIConstants.warning,
            size: 20,
          ),
          const SizedBox(width: AppUIConstants.spacingMd),
          Expanded(
            child: Text(
              'Complete your profile',
              style: AppUIConstants.bodyLg.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              foregroundColor: AppUIConstants.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: onComplete,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppUIConstants.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
              ),
              elevation: 0,
            ),
            child: const Text('Complete', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
