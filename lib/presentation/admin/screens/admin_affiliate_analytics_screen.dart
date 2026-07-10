import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/di/injection_container.dart';
import '../../../domain/usecases/current_affairs/current_affairs_usecases.dart';
import '../../core/app_ui_constants.dart';

class AdminAffiliateAnalyticsScreen extends StatefulWidget {
  const AdminAffiliateAnalyticsScreen({super.key});

  @override
  State<AdminAffiliateAnalyticsScreen> createState() =>
      _AdminAffiliateAnalyticsScreenState();
}

class _AdminAffiliateAnalyticsScreenState
    extends State<AdminAffiliateAnalyticsScreen> {
  AffiliateCouponStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    final stats = await sl<GetAffiliateCouponStats>()();
    if (mounted) {
      setState(() {
        _stats = stats;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        title: const Text('Affiliate Analytics'),
        backgroundColor: AppUIConstants.surface,
        foregroundColor: AppUIConstants.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: ListView(
                padding: const EdgeInsets.all(AppUIConstants.spacingLg),
                children: [
                  _buildTotalStats(),
                  const SizedBox(height: 16),
                  _buildPartnerCards(),
                  const SizedBox(height: 16),
                  _buildRecentCopies(),
                ],
              ),
            ),
    );
  }

  Widget _buildTotalStats() {
    final total = _stats?.totalCopies ?? 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppUIConstants.cardDecoration,
      child: Column(
        children: [
          Text('$total', style: AppUIConstants.statValue.copyWith(fontSize: 36)),
          const SizedBox(height: 4),
          Text('Total coupon copies', style: AppUIConstants.bodyMd),
        ],
      ),
    );
  }

  Widget _buildPartnerCards() {
    final copies = _stats?.recentCopies ?? [];
    final partners = AppConstants.affiliatePartners;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Partners', style: AppUIConstants.headingSm),
        const SizedBox(height: 10),
        ...partners.map((p) {
          final count =
              copies.where((r) => r.couponCode == p.couponCode).length;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: AppUIConstants.cardDecorationFlat,
              child: Row(
                children: [
                  Icon(
                    Icons.verified_rounded,
                    color: AppUIConstants.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, style: AppUIConstants.headingSm),
                        const SizedBox(height: 2),
                        Text(
                          'Code: ${p.couponCode}',
                          style: AppUIConstants.caption,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$count',
                        style: AppUIConstants.headingSm.copyWith(
                          color: AppUIConstants.primary,
                        ),
                      ),
                      Text('copies', style: AppUIConstants.caption),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRecentCopies() {
    final copies = _stats?.recentCopies ?? [];

    if (copies.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: AppUIConstants.cardDecorationFlat,
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.content_copy_rounded,
                size: 36,
                color: AppUIConstants.textTertiary,
              ),
              const SizedBox(height: 8),
              Text('No copies yet', style: AppUIConstants.bodyMd),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: AppUIConstants.cardDecorationFlat,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text('Recent Copies', style: AppUIConstants.headingSm),
                const Spacer(),
                Text('${copies.length} shown', style: AppUIConstants.caption),
              ],
            ),
          ),
          const Divider(height: 1),
          ...copies.map((record) {
            final dateStr = record.copiedAt != null
                ? DateFormat('dd MMM yyyy, hh:mm a').format(record.copiedAt!)
                : 'Unknown';
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 18,
                    color: AppUIConstants.textTertiary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.userId,
                          style: AppUIConstants.bodySm,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (record.couponCode.isNotEmpty)
                          Text(
                            record.couponCode,
                            style: AppUIConstants.caption.copyWith(
                              color: AppUIConstants.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(dateStr, style: AppUIConstants.caption),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
