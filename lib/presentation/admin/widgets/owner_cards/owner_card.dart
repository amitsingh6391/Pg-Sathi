import 'package:material_ui/material_ui.dart';

import '../../../../domain/entities/library.dart';
import '../../../../domain/entities/subscription_plan.dart';
import '../../../../domain/entities/user.dart';
import '../../../core/app_ui_constants.dart';
import '../../../core/widgets/premium_kit.dart';
import '../../utils/admin_contact_helper.dart';

/// Reusable owner card widget showing owner info and PG status.
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
  Future<void> _call() async {
    final ok = await AdminContactHelper.callOwner(widget.owner.phone);
    if (!ok && mounted) _snack('Could not open phone dialer');
  }

  Future<void> _whatsApp() async {
    final ok = await AdminContactHelper.sendWhatsApp(
      phone: widget.owner.phone,
      message: 'Hello! 👋',
    );
    if (!ok && mounted) _snack('Could not open WhatsApp');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(msg),
          ],
        ),
        backgroundColor: AppUIConstants.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openActions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppUIConstants.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppUIConstants.radiusXl),
        ),
      ),
      builder: (ctx) {
        Widget tile(
          IconData icon,
          String label,
          Color color,
          VoidCallback onTap,
        ) {
          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            title: Text(
              label,
              style: AppUIConstants.bodyMd.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () {
              Navigator.of(ctx).pop();
              onTap();
            },
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppUIConstants.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    widget.owner.displayName,
                    style: AppUIConstants.headingSm,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                  child: Text(widget.owner.phone, style: AppUIConstants.bodySm),
                ),
                tile(
                  Icons.phone_rounded,
                  'Call owner',
                  AppUIConstants.primaryLight,
                  _call,
                ),
                tile(
                  Icons.chat_rounded,
                  'WhatsApp',
                  AppUIConstants.success,
                  _whatsApp,
                ),
                tile(
                  Icons.notifications_rounded,
                  'Notify',
                  AppUIConstants.primaryLight,
                  () {
                    // TODO: Implement notification
                  },
                ),
                if (widget.onEditPricing != null)
                  tile(
                    Icons.price_change_rounded,
                    'Edit custom pricing',
                    AppUIConstants.primaryLight,
                    widget.onEditPricing!,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final owner = widget.owner;
    final library = widget.library;
    final expanded = widget.isExpanded;
    final active = library != null;
    final statusColor = active
        ? AppUIConstants.success
        : AppUIConstants.warning;
    final hasCustom = library?.customMonthlyPrice != null;
    final plan = library != null
        ? SubscriptionPlan.getPlanForSeats(library.capacity).name
        : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
        border: Border.all(
          color: expanded
              ? AppUIConstants.primaryLight.withValues(alpha: 0.5)
              : AppUIConstants.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            InkWell(
              onTap: widget.onExpand,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppUIConstants.primarySoft,
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        owner.displayName.isNotEmpty
                            ? owner.displayName[0].toUpperCase()
                            : '?',
                        style: AppUIConstants.headingSm.copyWith(
                          color: AppUIConstants.primaryLight,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            owner.displayName,
                            style: AppUIConstants.bodyMd.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            library?.name ?? owner.phone,
                            style: AppUIConstants.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              PremiumStatusPill(
                                active ? 'Active' : 'Pending',
                                color: statusColor,
                              ),
                              if (plan != null)
                                PremiumStatusPill(
                                  plan,
                                  color: AppUIConstants.primaryLight,
                                ),
                              if (hasCustom)
                                const PremiumStatusPill(
                                  'Custom',
                                  color: AppUIConstants.primaryLight,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _openActions,
                      tooltip: 'Actions',
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: AppUIConstants.textSecondary,
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: const Icon(
                        Icons.expand_more_rounded,
                        color: AppUIConstants.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: expanded
                  ? _Details(
                      owner: owner,
                      library: library,
                      onCall: _call,
                      onWhatsApp: _whatsApp,
                      onEditPricing: widget.onEditPricing,
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.owner,
    required this.library,
    required this.onCall,
    required this.onWhatsApp,
    this.onEditPricing,
  });

  final User owner;
  final Library? library;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback? onEditPricing;

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final lib = library;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: const BoxDecoration(
        color: AppUIConstants.surfaceMuted,
        border: Border(top: BorderSide(color: AppUIConstants.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lib == null)
            Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AppUIConstants.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No PG profile created yet',
                    style: AppUIConstants.bodySm.copyWith(
                      color: AppUIConstants.textPrimary,
                    ),
                  ),
                ),
              ],
            )
          else ...[
            Row(
              children: [
                const Icon(
                  Icons.apartment_rounded,
                  size: 18,
                  color: AppUIConstants.primaryLight,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lib.name,
                    style: AppUIConstants.bodyMd.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (lib.fullAddress != null || lib.area != null) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 14,
                    color: AppUIConstants.textTertiary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      lib.fullAddress ?? lib.area!,
                      style: AppUIConstants.caption.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Capacity',
                    value: '${lib.capacity} beds',
                    color: AppUIConstants.primaryLight,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniStat(
                    label: 'Pricing',
                    value: lib.customMonthlyPrice != null
                        ? '₹${lib.customMonthlyPrice!.toStringAsFixed(0)}/mo'
                        : 'Default tier',
                    color: lib.customMonthlyPrice != null
                        ? AppUIConstants.primaryLight
                        : AppUIConstants.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Created',
                    value: lib.createdAt != null ? _fmt(lib.createdAt!) : 'N/A',
                    color: AppUIConstants.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniStat(
                    label: 'Profile',
                    value: lib.isProfileComplete ? 'Complete' : 'Incomplete',
                    color: lib.isProfileComplete
                        ? AppUIConstants.success
                        : AppUIConstants.warning,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.phone_rounded,
                  label: 'Call',
                  color: AppUIConstants.primaryLight,
                  onTap: onCall,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.chat_rounded,
                  label: 'WhatsApp',
                  color: AppUIConstants.success,
                  onTap: onWhatsApp,
                ),
              ),
              if (onEditPricing != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.price_change_rounded,
                    label: 'Pricing',
                    color: AppUIConstants.primaryLight,
                    onTap: onEditPricing!,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppUIConstants.caption),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
