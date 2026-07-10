import 'package:flutter/material.dart';

import '../../../../domain/entities/library.dart';
import '../../../../domain/entities/user.dart';
import '../../../core/app_ui_constants.dart';
import '../../utils/admin_contact_helper.dart';

/// Reusable owner card widget showing owner info and library status.
class OwnerCard extends StatefulWidget {
  const OwnerCard({
    super.key,
    required this.owner,
    required this.library,
    required this.onExpand,
    required this.isExpanded,
    this.onEditPricing,
  });

  final User owner;
  final Library? library;
  final VoidCallback onExpand;
  final bool isExpanded;
  final VoidCallback? onEditPricing;

  @override
  State<OwnerCard> createState() => _OwnerCardState();
}

class _OwnerCardState extends State<OwnerCard> {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppUIConstants.spacingMd,
        vertical: AppUIConstants.spacingSm,
      ),
      elevation: widget.isExpanded ? 2 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: widget.isExpanded 
              ? AppUIConstants.primary.withValues(alpha: 0.2)
              : AppUIConstants.border.withValues(alpha: 0.5),
          width: widget.isExpanded ? 1.5 : 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            _OwnerHeader(
              owner: widget.owner,
              library: widget.library,
              isExpanded: widget.isExpanded,
              onTap: widget.onExpand,
            ),
            if (widget.isExpanded && widget.library != null) ...[
              _LibraryDetailsExpanded(
                owner: widget.owner,
                library: widget.library!,
                onEditPricing: widget.onEditPricing,
              ),
            ] else if (widget.isExpanded && widget.library == null) ...[
              _NoLibraryActions(owner: widget.owner),
            ],
          ],
        ),
      ),
    );
  }
}

/// Header section showing owner info with library status badge.
class _OwnerHeader extends StatelessWidget {
  const _OwnerHeader({
    required this.owner,
    required this.library,
    required this.isExpanded,
    required this.onTap,
  });

  final User owner;
  final Library? library;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasCustomPricing = library?.customMonthlyPrice != null;

    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: isExpanded
              ? LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppUIConstants.primary.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                )
              : null,
        ),
        child: Row(
          children: [
            // Avatar with gradient border
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppUIConstants.primary.withValues(alpha: 0.3),
                    AppUIConstants.primary.withValues(alpha: 0.1),
                  ],
                ),
                boxShadow: isExpanded
                    ? [
                        BoxShadow(
                          color: AppUIConstants.primary.withValues(alpha: 0.2),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              padding: const EdgeInsets.all(2),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: AppUIConstants.surface,
                child: Text(
                  owner.displayName.isNotEmpty
                      ? owner.displayName[0].toUpperCase()
                      : '?',
                  style: AppUIConstants.headingSm.copyWith(
                    color: AppUIConstants.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Owner Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    owner.displayName,
                    style: AppUIConstants.bodyMd.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppUIConstants.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.phone,
                        size: 12,
                        color: AppUIConstants.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        owner.phone,
                        style: AppUIConstants.caption.copyWith(
                          color: AppUIConstants.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Badges
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (library != null)
                  _StatusBadge(
                    label: 'Active',
                    icon: Icons.check_circle,
                    color: AppUIConstants.success,
                  )
                else
                  _StatusBadge(
                    label: 'Pending',
                    icon: Icons.pending,
                    color: AppUIConstants.warning,
                  ),
                if (hasCustomPricing) ...[
                  const SizedBox(height: 4),
                  _StatusBadge(
                    label: 'Custom',
                    icon: Icons.star,
                    color: AppUIConstants.primary,
                    compact: true,
                  ),
                ],
              ],
            ),
            const SizedBox(width: 8),

            // Expand icon
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isExpanded
                    ? AppUIConstants.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                color: isExpanded
                    ? AppUIConstants.primary
                    : AppUIConstants.textSecondary,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Library details section (expanded view with actions).
class _LibraryDetailsExpanded extends StatelessWidget {
  const _LibraryDetailsExpanded({
    required this.owner,
    required this.library,
    this.onEditPricing,
  });

  final User owner;
  final Library library;
  final VoidCallback? onEditPricing;

  Future<void> _handleCall(BuildContext context) async {
    final success = await AdminContactHelper.callOwner(owner.phone);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Could not open phone dialer'),
            ],
          ),
          backgroundColor: AppUIConstants.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleWhatsApp(BuildContext context) async {
    final success = await AdminContactHelper.sendWhatsApp(
      phone: owner.phone,
      message: 'Hello! 👋',
    );
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Could not open WhatsApp'),
            ],
          ),
          backgroundColor: AppUIConstants.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppUIConstants.surface.withValues(alpha: 0.3),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Library Name Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppUIConstants.primary.withValues(alpha: 0.08),
                  AppUIConstants.primary.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppUIConstants.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.local_library_rounded,
                    size: 20,
                    color: AppUIConstants.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        library.name,
                        style: AppUIConstants.bodyMd.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppUIConstants.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (library.area != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 12,
                              color: AppUIConstants.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                library.area!,
                                style: AppUIConstants.caption.copyWith(
                                  color: AppUIConstants.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Compact Details Section
          _CompactInfoRow(
            icon: Icons.event_seat,
            label: 'Capacity',
            value: '${library.capacity} seats',
            color: AppUIConstants.primary,
          ),
          const SizedBox(height: 8),
          _CompactInfoRow(
            icon: Icons.payments_outlined,
            label: 'Pricing',
            value: library.customMonthlyPrice != null
                ? '₹${library.customMonthlyPrice!.toStringAsFixed(0)}/month'
                : 'Default tier pricing',
            color: library.customMonthlyPrice != null
                ? AppUIConstants.success
                : AppUIConstants.textSecondary,
            highlighted: library.customMonthlyPrice != null,
          ),
          const SizedBox(height: 8),
          _CompactInfoRow(
            icon: Icons.calendar_today,
            label: 'Created',
            value: library.createdAt != null
                ? _formatDate(library.createdAt!)
                : 'N/A',
            color: AppUIConstants.textSecondary,
          ),
          const SizedBox(height: 8),
          _CompactInfoRow(
            icon: Icons.info_outline,
            label: 'Status',
            value: library.isProfileComplete ? 'Profile Complete' : 'Profile Incomplete',
            color: library.isProfileComplete
                ? AppUIConstants.success
                : AppUIConstants.warning,
            highlighted: !library.isProfileComplete,
          ),

          // Address (if available)
          if (library.fullAddress != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppUIConstants.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppUIConstants.border.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 16,
                    color: AppUIConstants.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      library.fullAddress!,
                      style: AppUIConstants.caption.copyWith(
                        color: AppUIConstants.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Action Buttons - Compact Row
          Row(
            children: [
              Expanded(
                child: _CompactActionButton(
                  icon: Icons.phone_rounded,
                  label: 'Call',
                  onTap: () => _handleCall(context),
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactActionButton(
                  icon: Icons.message_rounded,
                  label: 'WhatsApp',
                  onTap: () => _handleWhatsApp(context),
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactActionButton(
                  icon: Icons.notifications_rounded,
                  label: 'Notify',
                  onTap: () {
                    // TODO: Implement notification
                  },
                  color: AppUIConstants.primary,
                ),
              ),
            ],
          ),

          // Edit pricing button
          if (onEditPricing != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onEditPricing!,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit Custom Pricing'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppUIConstants.primary,
                  side: BorderSide(
                    color: AppUIConstants.primary.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// No library actions for owners without library.
class _NoLibraryActions extends StatelessWidget {
  const _NoLibraryActions({required this.owner});

  final User owner;

  Future<void> _handleCall(BuildContext context) async {
    final success = await AdminContactHelper.callOwner(owner.phone);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Could not open phone dialer'),
            ],
          ),
          backgroundColor: AppUIConstants.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleWhatsApp(BuildContext context) async {
    final success = await AdminContactHelper.sendWhatsApp(
      phone: owner.phone,
      message: 'Hello! 👋',
    );
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Could not open WhatsApp'),
            ],
          ),
          backgroundColor: AppUIConstants.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppUIConstants.warning.withValues(alpha: 0.05),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppUIConstants.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppUIConstants.warning.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AppUIConstants.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No library profile created yet',
                    style: AppUIConstants.bodySm.copyWith(
                      color: AppUIConstants.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CompactActionButton(
                  icon: Icons.phone_rounded,
                  label: 'Call',
                  onTap: () => _handleCall(context),
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactActionButton(
                  icon: Icons.message_rounded,
                  label: 'WhatsApp',
                  onTap: () => _handleWhatsApp(context),
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactActionButton(
                  icon: Icons.notifications_rounded,
                  label: 'Notify',
                  onTap: () {
                    // TODO: Implement notification
                  },
                  color: AppUIConstants.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact info row for displaying library details.
class _CompactInfoRow extends StatelessWidget {
  const _CompactInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted
            ? color.withValues(alpha: 0.08)
            : AppUIConstants.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: highlighted
            ? Border.all(color: color.withValues(alpha: 0.3), width: 1)
            : null,
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppUIConstants.caption.copyWith(
              color: AppUIConstants.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: AppUIConstants.bodySm.copyWith(
              color: highlighted ? color : AppUIConstants.textPrimary,
              fontWeight: highlighted ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact action button for quick actions.
class _CompactActionButton extends StatelessWidget {
  const _CompactActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppUIConstants.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Status badge widget with optional icon.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    this.icon,
    this.compact = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: compact ? 10 : 12,
              color: color,
            ),
            SizedBox(width: compact ? 3 : 4),
          ],
          Text(
            label,
            style: (compact ? AppUIConstants.caption : AppUIConstants.caption)
                .copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 9 : 11,
            ),
          ),
        ],
      ),
    );
  }
}

