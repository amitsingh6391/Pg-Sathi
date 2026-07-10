import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_ui_constants.dart';
import '../../../../domain/entities/membership.dart';

/// Partial rent information section displayed within the tenant card.
class PartialPaymentSection extends StatelessWidget {
  const PartialPaymentSection({
    super.key,
    required this.membership,
    required this.paymentNotes,
  });

  final Membership membership;
  final String? paymentNotes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFfef2f2), const Color(0xFFfee2e2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFfecaca)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppUIConstants.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 18,
                  color: AppUIConstants.error,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Partial Rent',
                style: TextStyle(
                  color: AppUIConstants.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildPaymentChip(
                'Paid',
                '₹${membership.paymentBreakdown?.amountPaid.toStringAsFixed(0) ?? 0}',
                Colors.green.shade700,
              ),
              const SizedBox(width: 10),
              _buildPaymentChip(
                'Due',
                '₹${membership.paymentBreakdown?.amountRemaining.toStringAsFixed(0) ?? 0}',
                AppUIConstants.error,
              ),
              if (membership.paymentBreakdown?.discount != null &&
                  membership.paymentBreakdown!.discount > 0) ...[
                const SizedBox(width: 10),
                _buildPaymentChip(
                  'Discount',
                  '₹${membership.paymentBreakdown!.discount.toStringAsFixed(0)}',
                  Colors.blue.shade700,
                ),
              ],
            ],
          ),
          // Notes
          if (paymentNotes != null && paymentNotes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.note_outlined,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      paymentNotes!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Action buttons footer for the tenant card.
class StudentCardActions extends StatelessWidget {
  const StudentCardActions({
    super.key,
    required this.isPending,
    required this.isExpired,
    required this.isExpiring,
    required this.hasPartialPayment,
    required this.needsFuturePlanPayment,
    required this.hasActiveUpcomingPlan,
    required this.isActionInProgress,
    required this.studentPhone,
    required this.onReassign,
    required this.onEdit,
    required this.onConvertPending,
    this.onCompletePayment,
    required this.onSendReminder,
    required this.onCancel,
    required this.onRefund,
  });

  final bool isPending;
  final bool isExpired;
  final bool isExpiring;
  final bool hasPartialPayment;

  /// Future-dated upcoming row on this card still awaiting payment (paired with [onCompletePayment]).
  final bool needsFuturePlanPayment;
  final bool hasActiveUpcomingPlan;
  final bool isActionInProgress;
  final String? studentPhone;
  final VoidCallback? onReassign;
  final VoidCallback onEdit;
  final VoidCallback onConvertPending;

  /// Partial balance on primary and/or payment for a future plan — same sheet as before.
  final VoidCallback? onCompletePayment;
  final VoidCallback onSendReminder;
  final VoidCallback onCancel;
  final VoidCallback? onRefund;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Reassign for expired or expiring-soon stays; hide if upcoming plan is active.
            if ((isExpired || isExpiring) &&
                onReassign != null &&
                !hasActiveUpcomingPlan) ...[
              _buildActionBtn(
                Icons.assignment_outlined,
                'Reassign',
                AppUIConstants.primary,
                isActionInProgress ? null : onReassign,
              ),
              const SizedBox(width: 8),
            ],
            // Edit button for non-expired stays.
            if (!isExpired) ...[
              _buildActionBtn(
                Icons.edit_outlined,
                'Edit',
                AppUIConstants.primary,
                isActionInProgress ? null : onEdit,
              ),
              const SizedBox(width: 8),
            ],
            if (isPending) ...[
              _buildActionBtn(
                Icons.check_circle_outline,
                'Activate',
                AppUIConstants.success,
                isActionInProgress ? null : onConvertPending,
              ),
              const SizedBox(width: 8),
            ],
            // Same control as partial "complete" — includes future-dated plan awaiting payment
            if (!isPending && !isExpired && onCompletePayment != null) ...[
              _buildActionBtn(
                Icons.payment_outlined,
                'Complete Rent',
                AppUIConstants.success,
                isActionInProgress ? null : onCompletePayment,
              ),
              const SizedBox(width: 8),
            ],
            // Remind button
            // Hide if there's an active upcoming plan (payment already done)
            if ((isPending ||
                    hasPartialPayment ||
                    needsFuturePlanPayment ||
                    isExpired ||
                    isExpiring) &&
                !hasActiveUpcomingPlan) ...[
              _buildActionBtn(
                Icons.notifications_active_outlined,
                'Remind',
                const Color(0xFFf59e0b),
                isActionInProgress ? null : onSendReminder,
              ),
              const SizedBox(width: 8),
            ],
            // Cancel/Remove button
            _buildActionBtn(
              (isPending || isExpired)
                  ? Icons.delete_outline
                  : Icons.cancel_outlined,
              (isPending || isExpired) ? 'Remove' : 'Cancel',
              AppUIConstants.error,
              isActionInProgress ? null : onCancel,
            ),
            const SizedBox(width: 8),
            // Call button
            if (studentPhone != null)
              _buildActionBtn(
                Icons.phone,
                'Call',
                AppUIConstants.success,
                () => _makePhoneCall(studentPhone!),
              ),
            const SizedBox(width: 8),
            // Refund button for active stays with successful payments.
            if (!isPending && !isExpired && onRefund != null) ...[
              _buildActionBtn(
                Icons.money_off_outlined,
                'Refund',
                Colors.deepOrange,
                isActionInProgress ? null : onRefund,
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  void _makePhoneCall(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Widget _buildActionBtn(
    IconData icon,
    String label,
    Color color,
    VoidCallback? onTap,
  ) {
    final disabled = onTap == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap();
              },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: disabled
                ? Colors.grey.shade100
                : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: disabled ? Colors.grey.shade400 : color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: disabled ? Colors.grey.shade400 : color,
                  fontSize: 13,
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
