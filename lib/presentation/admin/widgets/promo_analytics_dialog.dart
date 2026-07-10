import 'package:flutter/material.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/promo_offer.dart';
import '../../../domain/repositories/promo_repository.dart';
import '../../../domain/usecases/promo/promo_usecases.dart';
import '../../core/app_ui_constants.dart';

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
    return AlertDialog(
      backgroundColor: AppUIConstants.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
      ),
      title: Row(
        children: [
          const Icon(Icons.analytics_outlined),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Analytics: ${widget.promo.title}',
              style: AppUIConstants.headingMd,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: _buildContent(),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Text('Error: $_error');
    }

    if (_analytics == null) {
      return const Text('No data available');
    }

    final a = _analytics!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStatRow('Views', a.viewCount.toString(), Icons.visibility),
        _buildStatRow('Clicks', a.clickCount.toString(), Icons.touch_app),
        _buildStatRow('Dismissed', a.dismissCount.toString(), Icons.close),
        _buildStatRow('Unique Owners', a.uniqueOwners.toString(), Icons.person),
        const Divider(height: 24),
        _buildStatRow(
          'Click Rate',
          '${a.clickRate.toStringAsFixed(1)}%',
          Icons.trending_up,
          highlight: true,
        ),
      ],
    );
  }

  Widget _buildStatRow(
    String label,
    String value,
    IconData icon, {
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: highlight
                ? AppUIConstants.accent
                : AppUIConstants.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppUIConstants.bodyMd)),
          Text(
            value,
            style: AppUIConstants.headingSm.copyWith(
              color: highlight
                  ? AppUIConstants.accent
                  : AppUIConstants.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
