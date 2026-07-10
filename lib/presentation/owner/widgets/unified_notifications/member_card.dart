import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/app_ui_constants.dart';
import 'expiry_badge.dart';

/// Card displaying member information for notifications.
class MemberCard extends StatelessWidget {
  const MemberCard({
    super.key,
    required this.name,
    required this.phone,
    required this.daysLeft,
    required this.expiryDate,
    this.isSelected = false,
    this.isSent = false,
    this.showSendButton = false,
    this.onTap,
    this.onSend,
  });

  final String name;
  final String phone;
  final int daysLeft;
  final DateTime expiryDate;
  final bool isSelected;
  final bool isSent;
  final bool showSendButton;
  final VoidCallback? onTap;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? AppUIConstants.primary : AppUIConstants.border,
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: isSelected ? [AppUIConstants.shadowSm] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLeading(),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildInfo(),
                ),
                const SizedBox(width: 8),
                _buildTrailing(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeading() {
    if (!showSendButton) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: SizedBox(
          height: 22,
          width: 22,
          child: Checkbox(
            value: isSelected,
            activeColor: AppUIConstants.primary,
            onChanged: onTap != null ? (_) => onTap!() : null,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 22,
      backgroundColor: AppUIConstants.primary.withValues(alpha: 0.1),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: AppUIConstants.primary,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        _buildPhoneRow(),
        const SizedBox(height: 6),
        _buildExpiryRow(),
      ],
    );
  }

  Widget _buildPhoneRow() {
    return Row(
      children: [
        Icon(
          Icons.phone_outlined,
          size: 14,
          color: AppUIConstants.textTertiary,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            phone,
            style: TextStyle(fontSize: 13, color: AppUIConstants.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildExpiryRow() {
    return Row(
      children: [
        Icon(
          Icons.event_outlined,
          size: 14,
          color: AppUIConstants.textTertiary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Expires: ${DateFormat('dd MMM yyyy').format(expiryDate)}',
            style: TextStyle(fontSize: 13, color: AppUIConstants.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        ExpiryBadge(daysLeft: daysLeft),
      ],
    );
  }

  Widget _buildTrailing() {
    if (isSent) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppUIConstants.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 14, color: AppUIConstants.success),
            const SizedBox(width: 4),
            Text(
              'Sent',
              style: TextStyle(
                fontSize: 12,
                color: AppUIConstants.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (showSendButton && onSend != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: ElevatedButton(
          onPressed: onSend,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppUIConstants.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(0, 32),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: const Text('Send', style: TextStyle(fontSize: 12)),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
