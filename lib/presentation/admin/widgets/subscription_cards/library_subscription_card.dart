import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../../../domain/entities/library.dart';
import '../../../../domain/entities/subscription.dart';
import '../../../core/app_ui_constants.dart';
import '../../utils/admin_contact_helper.dart';
import 'subscription_tile.dart';

/// Card widget to display subscriptions grouped by library.
class LibrarySubscriptionCard extends StatelessWidget {
  const LibrarySubscriptionCard({
    required this.libraryId,
    this.library,
    required this.libraryName,
    required this.subscriptions,
    this.ownerName,
    this.ownerPhone,
    required this.onApprove,
    required this.onReject,
    this.onDelete,
    super.key,
  });

  final String libraryId;
  final Library? library;
  final String libraryName;
  final List<Subscription> subscriptions;
  final String? ownerName;
  final String? ownerPhone;
  final void Function(Subscription) onApprove;
  final void Function(Subscription) onReject;
  final void Function(Subscription)? onDelete;

  Future<void> _callOwner(BuildContext context) async {
    if (ownerPhone == null || ownerPhone!.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Owner phone number not available'),
            backgroundColor: AppUIConstants.warning,
          ),
        );
      }
      return;
    }

    final success = await AdminContactHelper.callOwner(ownerPhone!);

    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open phone dialer'),
          backgroundColor: AppUIConstants.error,
        ),
      );
    }
  }

  void _copyLibraryId(BuildContext context) {
    Clipboard.setData(ClipboardData(text: libraryId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('PG ID copied to clipboard'),
        backgroundColor: AppUIConstants.success,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _sendWhatsAppToOwner(BuildContext context) async {
    if (ownerPhone == null || ownerPhone!.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Owner phone number not available'),
            backgroundColor: AppUIConstants.warning,
          ),
        );
      }
      return;
    }

    final message =
        'Hello ${ownerName ?? 'there'}! I wanted to discuss about the subscriptions for *$libraryName*.';
    final success = await AdminContactHelper.sendWhatsApp(
      phone: ownerPhone!,
      message: message,
    );

    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open WhatsApp'),
          backgroundColor: AppUIConstants.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhone = ownerPhone != null && ownerPhone!.isNotEmpty;
    final pendingCount = subscriptions
        .where(
          (s) =>
              s.status == SubscriptionStatus.pending ||
              s.status == SubscriptionStatus.pendingVerification,
        )
        .length;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
        border: Border.all(color: AppUIConstants.border),
        boxShadow: [AppUIConstants.shadowSm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 6, 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppUIConstants.primarySoft,
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusMd,
                    ),
                  ),
                  child: const Icon(
                    Icons.apartment_rounded,
                    color: AppUIConstants.primaryLight,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        libraryName,
                        style: AppUIConstants.bodyLg.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (ownerName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          ownerName!,
                          style: AppUIConstants.bodySm,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _CountPill(
                            '${subscriptions.length} plan${subscriptions.length == 1 ? '' : 's'}',
                            AppUIConstants.primaryLight,
                          ),
                          if (pendingCount > 0)
                            _CountPill(
                              '$pendingCount pending',
                              AppUIConstants.warning,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppUIConstants.textSecondary,
                  ),
                  tooltip: 'Actions',
                  onPressed: () => _openActions(context, hasPhone),
                ),
              ],
            ),
          ),
          ...subscriptions.map(
            (sub) => SubscriptionTile(
              subscription: sub,
              onApprove: () => onApprove(sub),
              onReject: () => onReject(sub),
              onDelete: onDelete != null ? () => onDelete!(sub) : null,
            ),
          ),
        ],
      ),
    );
  }

  void _openActions(BuildContext context, bool hasPhone) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppUIConstants.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppUIConstants.radiusXl),
        ),
      ),
      builder: (ctx) {
        Widget tile(IconData icon, String label, Color color, VoidCallback f) {
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
              f();
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
                  child: Text(libraryName, style: AppUIConstants.headingSm),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                  child: Text(
                    'ID: $libraryId',
                    style: AppUIConstants.caption.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                if (hasPhone)
                  tile(
                    Icons.chat_rounded,
                    'WhatsApp owner',
                    AppUIConstants.success,
                    () => _sendWhatsAppToOwner(context),
                  ),
                if (hasPhone)
                  tile(
                    Icons.phone_rounded,
                    'Call owner',
                    AppUIConstants.primaryLight,
                    () => _callOwner(context),
                  ),
                tile(
                  Icons.content_copy_rounded,
                  'Copy PG ID',
                  AppUIConstants.primaryLight,
                  () => _copyLibraryId(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
