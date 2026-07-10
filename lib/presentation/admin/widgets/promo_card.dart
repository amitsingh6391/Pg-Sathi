import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/promo_offer.dart';
import '../../core/app_ui_constants.dart';

/// Card widget for displaying a promo offer in admin list.
class PromoCard extends StatelessWidget {
  const PromoCard({
    super.key,
    required this.promo,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    required this.onViewAnalytics,
  });

  final PromoOffer promo;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onViewAnalytics;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppUIConstants.spacingLg),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(
          color: promo.isActive
              ? AppUIConstants.success.withValues(alpha: 0.3)
              : AppUIConstants.border,
        ),
        boxShadow: [AppUIConstants.shadowSm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImagePreview(),
          Padding(
            padding: const EdgeInsets.all(AppUIConstants.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: AppUIConstants.spacingMd),
                _buildInfoChips(),
                if (promo.startDate != null || promo.endDate != null) ...[
                  const SizedBox(height: AppUIConstants.spacingMd),
                  _buildDateRange(),
                ],
                const SizedBox(height: AppUIConstants.spacingLg),
                const Divider(height: 1),
                const SizedBox(height: AppUIConstants.spacingMd),
                _buildActions(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppUIConstants.radiusMd),
      ),
      child: promo.imageUrl.isNotEmpty
          ? Image.network(
              promo.imageUrl,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stackTrace) =>
                  _buildDefaultPromoPreview(promo.title),
            )
          : _buildDefaultPromoPreview(promo.title),
    );
  }

  Widget _buildDefaultPromoPreview(String title) {
    return Container(
      height: 150,
      width: double.infinity,
      color: AppUIConstants.primary,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.local_offer_rounded, size: 40, color: Colors.white),
          const SizedBox(height: 8),
          Text(
            title.isNotEmpty ? title : 'Default Promo',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'No image uploaded',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            promo.title.isNotEmpty ? promo.title : 'Untitled Promo',
            style: AppUIConstants.headingSm,
          ),
        ),
        _buildStatusBadge(),
      ],
    );
  }

  Widget _buildStatusBadge() {
    final isValid = promo.isValidForDisplay;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isValid
            ? AppUIConstants.success.withValues(alpha: 0.1)
            : AppUIConstants.textTertiary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
      ),
      child: Text(
        isValid ? 'Active' : 'Inactive',
        style: AppUIConstants.bodySm.copyWith(
          color: isValid ? AppUIConstants.success : AppUIConstants.textTertiary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInfoChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildChip(Icons.people_outline, _audienceLabel(promo.targetAudience)),
        _buildChip(Icons.repeat_rounded, _frequencyLabel(promo.displayFrequency)),
        _buildChip(Icons.touch_app_outlined, promo.ctaText),
        _buildChip(Icons.low_priority_rounded, 'Priority: ${promo.priority}'),
      ],
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppUIConstants.background,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppUIConstants.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: AppUIConstants.bodySm),
        ],
      ),
    );
  }

  Widget _buildDateRange() {
    return Row(
      children: [
        Icon(
          Icons.calendar_today_outlined,
          size: 14,
          color: AppUIConstants.textTertiary,
        ),
        const SizedBox(width: 4),
        Text(
          _formatDateRange(promo.startDate, promo.endDate),
          style: AppUIConstants.bodySm.copyWith(
            color: AppUIConstants.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        _PromoActionButton(
          icon: Icons.analytics_outlined,
          label: 'Analytics',
          onTap: onViewAnalytics,
        ),
        _PromoActionButton(
          icon: Icons.edit_outlined,
          label: 'Edit',
          onTap: onEdit,
        ),
        _PromoActionButton(
          icon: promo.isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
          label: promo.isActive ? 'Pause' : 'Activate',
          onTap: onToggle,
        ),
        _PromoActionButton(
          icon: Icons.delete_outline,
          label: 'Delete',
          color: AppUIConstants.error,
          onTap: onDelete,
        ),
      ],
    );
  }

  String _audienceLabel(PromoTargetAudience audience) {
    switch (audience) {
      case PromoTargetAudience.all:
        return 'Everyone';
      case PromoTargetAudience.allOwners:
        return 'All Owners';
      case PromoTargetAudience.allStudents:
        return 'All Students';
      case PromoTargetAudience.freeTier:
        return 'Free Tier';
      case PromoTargetAudience.paid:
        return 'Paid';
      case PromoTargetAudience.expired:
        return 'Expired';
      case PromoTargetAudience.pendingVerification:
        return 'Pending';
      case PromoTargetAudience.newOwners:
        return 'New Owners';
      case PromoTargetAudience.activeMembership:
        return 'Active Students';
      case PromoTargetAudience.expiredMembership:
        return 'Expired Students';
      case PromoTargetAudience.noMembership:
        return 'No Membership';
    }
  }

  String _frequencyLabel(PromoDisplayFrequency frequency) {
    switch (frequency) {
      case PromoDisplayFrequency.once:
        return 'Once';
      case PromoDisplayFrequency.daily:
        return 'Daily';
      case PromoDisplayFrequency.session:
        return 'Every Session';
    }
  }

  String _formatDateRange(DateTime? start, DateTime? end) {
    final formatter = DateFormat('MMM d, yyyy');
    if (start != null && end != null) {
      return '${formatter.format(start)} – ${formatter.format(end)}';
    } else if (start != null) {
      return 'From ${formatter.format(start)}';
    } else if (end != null) {
      return 'Until ${formatter.format(end)}';
    }
    return '';
  }
}

/// Action button for promo card.
class _PromoActionButton extends StatelessWidget {
  const _PromoActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(icon, size: 20, color: color ?? AppUIConstants.textSecondary),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppUIConstants.bodySm.copyWith(
                  color: color ?? AppUIConstants.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
