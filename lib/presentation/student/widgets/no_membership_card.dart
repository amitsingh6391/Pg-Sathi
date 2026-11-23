import 'package:material_ui/material_ui.dart';

import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';

/// Friendly empty state shown when the resident has no PG stays yet.
class NoMembershipCard extends StatelessWidget {
  const NoMembershipCard({super.key, this.onExplore});

  /// Optional CTA; when null (Explore hidden) the hint points to an invite link.
  final VoidCallback? onExplore;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppUIConstants.primarySoft,
                  border: Border.all(
                    color: AppUIConstants.primary.withValues(alpha: 0.5),
                  ),
                ),
                child: const Icon(
                  Icons.bed_rounded,
                  size: 40,
                  color: AppUIConstants.primaryLight,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('No stay yet', style: AppUIConstants.headingMd),
            const SizedBox(height: 8),
            Text(
              'Your room, rent and check-ins will show up here once you join a PG.',
              style: AppUIConstants.bodyMd,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (onExplore != null)
              ElevatedButton.icon(
                onPressed: onExplore,
                icon: const Icon(Icons.apartment_rounded, size: 18),
                label: const Text('Find a PG'),
                style: AppUIConstants.accentButtonStyle,
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppUIConstants.surfaceMuted,
                  borderRadius: BorderRadius.circular(
                    AppUIConstants.radiusFull,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.link_rounded,
                      size: 16,
                      color: AppUIConstants.primaryLight,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Ask your PG owner for an invite link',
                      style: TextStyle(
                        color: AppUIConstants.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
