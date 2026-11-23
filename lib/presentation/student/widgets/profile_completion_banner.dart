import 'package:material_ui/material_ui.dart';

import '../../../domain/entities/user.dart';
import '../../core/app_ui_constants.dart';

/// Non-blocking banner nudging the resident to finish their profile.
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
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppUIConstants.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
                ),
                child: const Icon(
                  Icons.badge_outlined,
                  color: AppUIConstants.primaryLight,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppUIConstants.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Complete your profile',
                      style: AppUIConstants.bodyLg.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Help your PG owner know you better.',
                      style: AppUIConstants.bodySm,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppUIConstants.spacingMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: AppUIConstants.textSecondary,
                ),
                child: const Text('Skip'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onComplete,
                style: AppUIConstants.accentButtonStyle.copyWith(
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
                child: const Text('Complete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
