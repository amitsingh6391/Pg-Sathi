import 'package:flutter/material.dart';
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
        content: const Text('Library ID copied to clipboard'),
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

    final message = 'Hello ${ownerName ?? 'there'}! I wanted to discuss about the subscriptions for *$libraryName*.';
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppUIConstants.divider.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Library Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppUIConstants.primary.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppUIConstants.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.local_library_rounded,
                        color: AppUIConstants.primary,
                        size: 18,
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
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (ownerName != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              ownerName!,
                              style: AppUIConstants.bodySm.copyWith(
                                color: AppUIConstants.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Subscription count badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppUIConstants.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppUIConstants.accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: 14,
                            color: AppUIConstants.accent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${subscriptions.length}',
                            style: AppUIConstants.bodySm.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppUIConstants.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Action icons row
                const SizedBox(height: 12),
                Row(
                  children: [
                    // WhatsApp button
                    if (ownerPhone != null && ownerPhone!.isNotEmpty)
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _sendWhatsAppToOwner(context),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366).withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF25D366).withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: const Icon(
                                Icons.chat,
                                color: Color(0xFF25D366),
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (ownerPhone != null && ownerPhone!.isNotEmpty)
                      const SizedBox(width: 8),
                    // Call button
                    if (ownerPhone != null && ownerPhone!.isNotEmpty)
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _callOwner(context),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: AppUIConstants.primary.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppUIConstants.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Icon(
                                Icons.phone_rounded,
                                color: AppUIConstants.primary,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (ownerPhone != null && ownerPhone!.isNotEmpty)
                      const SizedBox(width: 8),
                    // Copy ID button
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _copyLibraryId(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: AppUIConstants.accent.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppUIConstants.accent.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Icon(
                              Icons.content_copy_rounded,
                              color: AppUIConstants.accent,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Library ID
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.tag,
                      size: 14,
                      color: AppUIConstants.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'ID: $libraryId',
                        style: AppUIConstants.bodySm.copyWith(
                          color: AppUIConstants.textSecondary,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Subscription Items
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
}
