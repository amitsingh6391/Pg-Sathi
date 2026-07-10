import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/payment.dart';
import '../../../domain/usecases/get_pending_cash_payments.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/cash_approval_cubit.dart';
import '../cubit/cash_approval_state.dart';

/// Screen for owner to approve/reject pending cash payments.
class CashApprovalsScreen extends StatefulWidget {
  const CashApprovalsScreen({
    super.key,
    required this.libraryId,
    required this.ownerId,
    required this.libraryName,
  });

  final String libraryId;
  final String ownerId;
  final String libraryName;

  @override
  State<CashApprovalsScreen> createState() => _CashApprovalsScreenState();
}

class _CashApprovalsScreenState extends State<CashApprovalsScreen> {
  /// Tracks if any payment was approved or rejected during this session.
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    context.read<CashApprovalCubit>().loadPendingPayments(widget.libraryId);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pop(_hasChanges);
        }
      },
      child: Scaffold(
        backgroundColor: AppUIConstants.background,
        appBar: AppBar(
          backgroundColor: AppUIConstants.primary,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_hasChanges),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cash Approvals',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                widget.libraryName,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: BlocConsumer<CashApprovalCubit, CashApprovalState>(
          listener: (context, state) {
            if (state.isApproved) {
              _hasChanges = true;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cash payment approved successfully'),
                  backgroundColor: AppUIConstants.success,
                ),
              );
              context.read<CashApprovalCubit>().resetToLoaded();
            } else if (state.isRejected) {
              _hasChanges = true;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Cash payment rejected'),
                  backgroundColor: AppUIConstants.warning,
                ),
              );
              context.read<CashApprovalCubit>().resetToLoaded();
            } else if (state.isError && state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: AppUIConstants.error,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppUIConstants.primary,
                  strokeWidth: 2,
                ),
              );
            }

            // Filter only cash payments
            final cashPayments = state.pendingPayments
                .where((p) => p.payment.mode != PaymentMode.upi)
                .toList();

            if (cashPayments.isEmpty) {
              return _EmptyState();
            }

            return RefreshIndicator(
              color: AppUIConstants.primary,
              onRefresh: () async => context
                  .read<CashApprovalCubit>()
                  .loadPendingPayments(widget.libraryId),
              child: ListView.builder(
                padding: const EdgeInsets.all(AppUIConstants.spacingLg),
                itemCount: cashPayments.length,
                itemBuilder: (context, index) {

                  final info = cashPayments[index];
                  final isProcessing = state.isProcessingPayment(
                    info.payment.id,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: AppUIConstants.spacingMd,
                    ),
                    child: _PendingPaymentCard(
                      info: info,
                      isProcessing: isProcessing,
                      onApprove: () => _handleApprove(info),
                      onReject: () => _handleReject(info),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleApprove(PendingCashPaymentInfo info) {
    final isPartialCompletion = info.isPartialPaymentCompletion;
    final membership = info.membership;
    final breakdown = membership?.paymentBreakdown;
    final willCompletePayment =
        breakdown != null &&
        (breakdown.amountPaid + info.payment.amount >= breakdown.totalAmount);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isPartialCompletion ? 'Approve Remaining Payment' : 'Approve Payment',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Approve payment of ₹${info.payment.amount.toStringAsFixed(0)} from ${info.studentName}?',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (isPartialCompletion && breakdown != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Details:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Already Paid: ₹${breakdown.amountPaid.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      'This Payment: ₹${info.payment.amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (willCompletePayment)
                      Text(
                        'Total After: ₹${breakdown.totalAmount.toStringAsFixed(0)} (Full Payment)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      )
                    else
                      Text(
                        'Remaining After: ₹${(breakdown.amountRemaining - info.payment.amount).toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              willCompletePayment
                  ? 'This will complete the remaining payment and fully activate their membership.'
                  : isPartialCompletion
                  ? 'This will update their partial payment. Membership remains active.'
                  : 'This will activate their membership.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<CashApprovalCubit>().approve(
                paymentId: info.payment.id,
                ownerId: widget.ownerId,
                libraryId: widget.libraryId,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppUIConstants.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _handleReject(PendingCashPaymentInfo info) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Cash Payment'),
        content: Text(
          'Reject cash payment from ${info.studentName}?\n\nTheir seat reservation will be cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<CashApprovalCubit>().reject(
                paymentId: info.payment.id,
                ownerId: widget.ownerId,
                libraryId: widget.libraryId,
                reason: 'Cash payment rejected by owner',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppUIConstants.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}

class _PendingPaymentCard extends StatelessWidget {
  const _PendingPaymentCard({
    required this.info,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
  });

  final PendingCashPaymentInfo info;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM, hh:mm a');
    final isUpi = info.payment.mode == PaymentMode.upi;

    return Container(
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(color: AppUIConstants.border),
        boxShadow: [AppUIConstants.shadowSm],
      ),
      child: Column(
        children: [
          // Header - Clean, neutral design
          Padding(
            padding: const EdgeInsets.all(AppUIConstants.spacingLg),
            child: Row(
              children: [
                // Icon container
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppUIConstants.divider,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isUpi
                        ? Icons.account_balance_outlined
                        : Icons.payments_outlined,
                    color: AppUIConstants.textSecondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppUIConstants.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.studentName,
                        style: AppUIConstants.headingSm,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(info.studentPhone, style: AppUIConstants.caption),
                    ],
                  ),
                ),
                // Payment type badge - Minimal
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppUIConstants.divider,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isUpi ? 'UPI' : 'CASH',
                    style: AppUIConstants.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppUIConstants.textSecondary,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Divider
          const Divider(height: 1, color: AppUIConstants.border),

          // Details
          Padding(
            padding: const EdgeInsets.all(AppUIConstants.spacingLg),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _DetailItem(
                        icon: Icons.event_seat_outlined,
                        label: 'Seat',
                        value: info.seatNumber,
                      ),
                    ),
                    Expanded(
                      child: _DetailItem(
                        icon: Icons.schedule_outlined,
                        label: 'Slot',
                        value: info.slot,
                      ),
                    ),
                    Expanded(
                      child: _DetailItem(
                        icon: Icons.currency_rupee_rounded,
                        label: 'Amount',
                        value: '₹${info.payment.amount.toStringAsFixed(0)}',
                        valueStyle: AppUIConstants.bodyMd.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppUIConstants.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppUIConstants.spacingSm),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: AppUIConstants.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Initiated: ${info.payment.createdAt != null ? dateFormat.format(info.payment.createdAt!) : '-'}',
                      style: AppUIConstants.caption,
                    ),
                  ],
                ),
                // Show UTR for UPI payments
                if (isUpi && info.payment.utrNumber != null) ...[
                  const SizedBox(height: AppUIConstants.spacingSm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppUIConstants.divider,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 14,
                          color: AppUIConstants.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'UTR: ${info.payment.utrNumber}',
                          style: AppUIConstants.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppUIConstants.textPrimary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Actions
          const Divider(height: 1, color: AppUIConstants.divider),
          Padding(
            padding: const EdgeInsets.all(AppUIConstants.spacingMd),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isProcessing ? null : onReject,
                    icon: isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppUIConstants.error,
                      side: const BorderSide(color: AppUIConstants.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppUIConstants.spacingMd),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isProcessing ? null : onApprove,
                    icon: isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppUIConstants.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueStyle,
  });

  final IconData icon;
  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: AppUIConstants.textTertiary),
        const SizedBox(height: 4),
        Text(label, style: AppUIConstants.caption),
        const SizedBox(height: 2),
        Text(
          value,
          style: valueStyle ?? AppUIConstants.bodySm,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppUIConstants.divider,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline_rounded,
                size: 48,
                color: AppUIConstants.success,
              ),
            ),
            const SizedBox(height: 24),
            Text('All Caught Up!', style: AppUIConstants.headingMd),
            const SizedBox(height: 8),
            Text(
              'No pending cash payments\nawaiting your approval.',
              style: AppUIConstants.bodySm,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
