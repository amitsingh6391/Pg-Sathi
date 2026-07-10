import 'package:flutter/material.dart';

import '../../core/app_ui_constants.dart';

/// Card displayed when student has no active memberships.
/// Clean, professional design using AppUIConstants.
class NoMembershipCard extends StatelessWidget {
  const NoMembershipCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppUIConstants.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.menu_book_rounded,
              size: 36,
              color: AppUIConstants.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text('No Memberships Yet', style: AppUIConstants.headingSm),
          const SizedBox(height: 8),
          Text(
            'Find libraries near you using the Explore tab below',
            style: AppUIConstants.bodySm,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
