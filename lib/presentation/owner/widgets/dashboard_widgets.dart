import 'package:material_ui/material_ui.dart';

import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';

/// Empty state shown before the owner has created a PG profile.
/// Explains the 3-step setup and offers a single, obvious CTA.
class EmptyLibraryCard extends StatelessWidget {
  const EmptyLibraryCard({super.key, required this.onCreateLibrary});

  final VoidCallback onCreateLibrary;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      glow: AppUIConstants.primary,
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppUIConstants.surfaceMuted,
            ),
            child: const Icon(
              Icons.apartment_rounded,
              size: 38,
              color: AppUIConstants.primaryLight,
            ),
          ),
          const SizedBox(height: 20),
          const Text('Set up your PG', style: AppUIConstants.headingLg),
          const SizedBox(height: 8),
          const Text(
            'Three quick steps and your PG is ready to run from this phone.',
            style: AppUIConstants.bodyMd,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          const _SetupStep(
            index: 1,
            icon: Icons.home_work_rounded,
            title: 'Add PG details',
            subtitle: 'Name, address, photos and house rules',
          ),
          const _SetupStep(
            index: 2,
            icon: Icons.bed_rounded,
            title: 'Create room types & beds',
            subtitle: 'Number your beds and set rent plans',
          ),
          const _SetupStep(
            index: 3,
            icon: Icons.person_add_alt_1_rounded,
            title: 'Move in your tenants',
            subtitle: 'Assign beds and start collecting rent',
            isLast: true,
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onCreateLibrary,
              icon: const Icon(Icons.rocket_launch_rounded, size: 18),
              label: const Text(
                'Set up my PG',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: AppUIConstants.primaryButtonStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({
    required this.index,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isLast = false,
  });

  final int index;
  final IconData icon;
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
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppUIConstants.primarySoft,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppUIConstants.primaryLight.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  '$index',
                  style: const TextStyle(
                    color: AppUIConstants.primaryLight,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 1.5, color: AppUIConstants.border),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16, top: 2),
              child: Row(
                children: [
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
                  Icon(icon, size: 20, color: AppUIConstants.textTertiary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Error view for the dashboard.
class DashboardErrorView extends StatelessWidget {
  const DashboardErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppUIConstants.spacing2Xl),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppUIConstants.error.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 30,
              color: AppUIConstants.error,
            ),
          ),
          const SizedBox(height: 16),
          const Text('Could not load your PG', style: AppUIConstants.headingSm),
          const SizedBox(height: 6),
          Text(
            message,
            style: AppUIConstants.bodySm,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try again'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppUIConstants.primaryLight,
              side: const BorderSide(color: AppUIConstants.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton that mirrors the cockpit layout (bed map, stat grid, actions).
class DashboardLoading extends StatefulWidget {
  const DashboardLoading({super.key});

  @override
  State<DashboardLoading> createState() => _DashboardLoadingState();
}

class _DashboardLoadingState extends State<DashboardLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
    _anim = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonBox(height: 120, anim: _anim),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _SkeletonBox(height: 104, anim: _anim)),
              const SizedBox(width: 12),
              Expanded(child: _SkeletonBox(height: 104, anim: _anim)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _SkeletonBox(height: 104, anim: _anim)),
              const SizedBox(width: 12),
              Expanded(child: _SkeletonBox(height: 104, anim: _anim)),
            ],
          ),
          const SizedBox(height: 20),
          _SkeletonBox(width: 140, height: 18, anim: _anim),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _SkeletonBox(height: 96, anim: _anim)),
              const SizedBox(width: 12),
              Expanded(child: _SkeletonBox(height: 96, anim: _anim)),
            ],
          ),
          const SizedBox(height: 12),
          _SkeletonBox(height: 150, anim: _anim),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.anim, required this.height, this.width});

  final Animation<double> anim;
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
        gradient: LinearGradient(
          begin: Alignment(anim.value - 1, 0),
          end: Alignment(anim.value + 1, 0),
          colors: const [
            AppUIConstants.surface,
            AppUIConstants.surfaceMuted,
            AppUIConstants.surface,
          ],
        ),
      ),
    );
  }
}
