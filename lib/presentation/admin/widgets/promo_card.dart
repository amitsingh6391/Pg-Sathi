import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/promo_offer.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';
import 'promo_ticket.dart';

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
    final isValid = promo.isValidForDisplay;
    final accent = isValid
        ? AppUIConstants.primaryLight
        : AppUIConstants.textTertiary;
    final countdown = expiryCountdown(promo.endDate, start: promo.startDate);
    return TicketCard(
      accent: accent,
      onTap: onEdit,
      stub: _buildStub(accent),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      promo.title.isNotEmpty ? promo.title : 'Untitled promo',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppUIConstants.headingSm,
                    ),
                  ),
                ),
                _buildMenu(),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                PremiumStatusPill(
                  isValid ? 'Live' : (promo.isActive ? 'Scheduled' : 'Paused'),
                  color: isValid
                      ? AppUIConstants.success
                      : (promo.isActive
                            ? AppUIConstants.primaryLight
                            : AppUIConstants.textTertiary),
                ),
                const SizedBox(width: 8),
                Icon(Icons.timer_outlined, size: 14, color: countdown.color),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    countdown.label,
                    overflow: TextOverflow.ellipsis,
                    style: AppUIConstants.bodySm.copyWith(
                      color: countdown.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildInfoChips(),
            ..._buildScheduleProgress(accent),
          ],
        ),
      ),
    );
  }

  Widget _buildStub(Color accent) {
    final fallback = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.local_offer_rounded, size: 30, color: accent),
        const SizedBox(height: 6),
        Text(
          '#${promo.priority}',
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        const Text('priority', style: AppUIConstants.caption),
      ],
    );
    if (promo.imageUrl.isEmpty) return fallback;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 120),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.network(
              promo.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stackTrace) => fallback,
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : fallback,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      color: AppUIConstants.surfaceMuted,
      icon: const Icon(
        Icons.more_vert_rounded,
        size: 20,
        color: AppUIConstants.textSecondary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppUIConstants.radiusSm + 2),
        side: const BorderSide(color: AppUIConstants.border),
      ),
      onSelected: (v) {
        switch (v) {
          case 'analytics':
            onViewAnalytics();
          case 'edit':
            onEdit();
          case 'toggle':
            onToggle();
          case 'delete':
            onDelete();
        }
      },
      itemBuilder: (_) => [
        _menuItem('analytics', Icons.analytics_outlined, 'Analytics'),
        _menuItem('edit', Icons.edit_outlined, 'Edit'),
        _menuItem(
          'toggle',
          promo.isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
          promo.isActive ? 'Pause' : 'Activate',
        ),
        _menuItem(
          'delete',
          Icons.delete_outline_rounded,
          'Delete',
          color: AppUIConstants.error,
        ),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(
    String v,
    IconData icon,
    String label, {
    Color? color,
  }) {
    final c = color ?? AppUIConstants.textPrimary;
    return PopupMenuItem<String>(
      value: v,
      child: Row(
        children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: c, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildInfoChips() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _buildChip(Icons.people_outline, _audienceLabel(promo.targetAudience)),
        _buildChip(
          Icons.repeat_rounded,
          _frequencyLabel(promo.displayFrequency),
        ),
        if (promo.ctaText.isNotEmpty)
          _buildChip(Icons.touch_app_outlined, promo.ctaText),
      ],
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppUIConstants.surfaceMuted,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppUIConstants.textSecondary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: AppUIConstants.bodySm.copyWith(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  /// Schedule progress bar (start -> end) plus date range text.
  List<Widget> _buildScheduleProgress(Color accent) {
    final start = promo.startDate;
    final end = promo.endDate;
    if (start == null && end == null) return const [];
    double? progress;
    if (start != null && end != null && end.isAfter(start)) {
      final total = end.difference(start).inSeconds;
      final done = DateTime.now().difference(start).inSeconds;
      progress = (done / total).clamp(0.0, 1.0);
    }
    return [
      const SizedBox(height: 10),
      if (progress != null)
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: AppUIConstants.surfaceMuted,
            valueColor: AlwaysStoppedAnimation(accent),
          ),
        ),
      const SizedBox(height: 6),
      Text(_formatDateRange(start, end), style: AppUIConstants.caption),
    ];
  }

  String _audienceLabel(PromoTargetAudience audience) {
    switch (audience) {
      case PromoTargetAudience.all:
        return 'Everyone';
      case PromoTargetAudience.allOwners:
        return 'All Owners';
      case PromoTargetAudience.allStudents:
        return 'All Residents';
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
        return 'Active Residents';
      case PromoTargetAudience.expiredMembership:
        return 'Expired Residents';
      case PromoTargetAudience.noMembership:
        return 'No Stay';
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
