import 'package:material_ui/material_ui.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/promo_offer.dart';
import '../../../domain/repositories/promo_repository.dart';
import '../../../domain/usecases/promo/promo_usecases.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';

/// Dialog showing promo analytics.
class PromoAnalyticsDialog extends StatefulWidget {
  const PromoAnalyticsDialog({super.key, required this.promo});

  final PromoOffer promo;

  @override
  State<PromoAnalyticsDialog> createState() => _PromoAnalyticsDialogState();
}

class _PromoAnalyticsDialogState extends State<PromoAnalyticsDialog> {
  PromoAnalytics? _analytics;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    final getAnalytics = sl<GetPromoAnalytics>();
    final result = await getAnalytics(widget.promo.id);

    result.fold(
      (f) => setState(() {
        _error = f.message;
        _isLoading = false;
      }),
      (analytics) => setState(() {
        _analytics = analytics;
        _isLoading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppUIConstants.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
        side: const BorderSide(color: AppUIConstants.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppUIConstants.spacingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppUIConstants.primaryLight.withValues(
                        alpha: 0.14,
                      ),
                      borderRadius: BorderRadius.circular(
                        AppUIConstants.radiusSm,
                      ),
                    ),
                    child: const Icon(
                      Icons.analytics_outlined,
                      size: 20,
                      color: AppUIConstants.primaryLight,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Promo analytics',
                          style: AppUIConstants.caption,
                        ),
                        Text(
                          widget.promo.title,
                          style: AppUIConstants.headingMd,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppUIConstants.textSecondary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(child: SingleChildScrollView(child: _buildContent())),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const _AnalyticsSkeleton();
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppUIConstants.error,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Error: $_error', style: AppUIConstants.bodyMd),
            ),
          ],
        ),
      );
    }

    if (_analytics == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text('No data available', style: AppUIConstants.bodyMd),
      );
    }

    final a = _analytics!;
    final rate = (a.clickRate / 100).clamp(0.0, 1.0).toDouble();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PremiumTwoColumnGrid(
          spacing: 10,
          children: [
            PremiumStatTile(
              icon: Icons.visibility_outlined,
              value: a.viewCount.toString(),
              label: 'Views',
            ),
            PremiumStatTile(
              icon: Icons.touch_app_outlined,
              value: a.clickCount.toString(),
              label: 'Clicks',
            ),
            PremiumStatTile(
              icon: Icons.close_rounded,
              value: a.dismissCount.toString(),
              label: 'Dismissed',
            ),
            PremiumStatTile(
              icon: Icons.person_outline_rounded,
              value: a.uniqueOwners.toString(),
              label: 'Unique owners',
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppUIConstants.surfaceMuted,
            borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.trending_up_rounded,
                    size: 18,
                    color: AppUIConstants.primaryLight,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Click rate', style: AppUIConstants.bodyMd),
                  ),
                  Text(
                    '${a.clickRate.toStringAsFixed(1)}%',
                    style: AppUIConstants.headingSm.copyWith(
                      color: AppUIConstants.primaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: rate),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 6,
                    backgroundColor: AppUIConstants.border,
                    valueColor: const AlwaysStoppedAnimation(
                      AppUIConstants.primaryLight,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnalyticsSkeleton extends StatefulWidget {
  const _AnalyticsSkeleton();

  @override
  State<_AnalyticsSkeleton> createState() => _AnalyticsSkeletonState();
}

class _AnalyticsSkeletonState extends State<_AnalyticsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final color = Color.lerp(
          AppUIConstants.surfaceMuted,
          AppUIConstants.border,
          _c.value,
        )!;
        Widget box() => Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          ),
        );
        return SizedBox(
          height: 190,
          child: GridView.count(
            crossAxisCount: 2,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.45,
            children: [box(), box(), box(), box()],
          ),
        );
      },
    );
  }
}
