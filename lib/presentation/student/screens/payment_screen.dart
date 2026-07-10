import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../domain/entities/library.dart';
import '../../../domain/entities/membership.dart'; // For MembershipPlanExtension
import '../../../domain/entities/payment.dart';
import '../../../domain/usecases/get_student_memberships.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/student_payment_cubit.dart';
import '../cubit/student_payment_state.dart';

/// Payment screen for completing seat reservation payment.
/// Supports Cash and UPI payment modes.
/// Can be used for initial payment, completing remaining payment for partial payments, or renewals.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.membershipInfo,
    this.overrideAmount,
    this.isRemainingPayment = false,
    this.isRenewal = false,
  });

  final StudentMembershipInfo membershipInfo;

  /// Override amount (for remaining payments)
  final double? overrideAmount;

  /// Whether this is for completing remaining payment
  final bool isRemainingPayment;

  /// Whether this is for renewing membership
  final bool isRenewal;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  @override
  void initState() {
    super.initState();
    // Check for existing pending cash payment
    context.read<StudentPaymentCubit>().checkForExistingPayment(
      widget.membershipInfo.membership.id,
    );
  }

  void _initiateCashPayment() {
    final userId = widget.membershipInfo.membership.userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sync your membership first')),
      );
      return;
    }
    final amount = widget.overrideAmount ?? widget.membershipInfo.paymentAmount;

    // If this is a renewal, create the upcoming membership first
    if (widget.isRenewal) {
      context.read<StudentPaymentCubit>().renewMembership(
        currentMembershipId: widget.membershipInfo.membership.id,
        userId: userId,
        libraryId: widget.membershipInfo.membership.libraryId,
        amount: amount,
        paymentMethod: PaymentMode.cash,
        plan: widget.membershipInfo.membership.plan,
      );
    } else {
      context.read<StudentPaymentCubit>().startCashPayment(
        membershipId: widget.membershipInfo.membership.id,
        userId: userId,
        libraryId: widget.membershipInfo.membership.libraryId,
        amount: amount,
      );
    }
  }

  void _initiateUpiPayment() {
    final userId = widget.membershipInfo.membership.userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sync your membership first')),
      );
      return;
    }
    final amount = widget.overrideAmount ?? widget.membershipInfo.paymentAmount;

    // If this is a renewal, create the upcoming membership first
    if (widget.isRenewal) {
      context.read<StudentPaymentCubit>().renewMembership(
        currentMembershipId: widget.membershipInfo.membership.id,
        userId: userId,
        libraryId: widget.membershipInfo.membership.libraryId,
        amount: amount,
        paymentMethod: PaymentMode.upi,
        plan: widget.membershipInfo.membership.plan,
      );
    } else {
      context.read<StudentPaymentCubit>().startUpiPayment(
        membershipId: widget.membershipInfo.membership.id,
        userId: userId,
        libraryId: widget.membershipInfo.membership.libraryId,
        amount: amount,
      );
    }
  }

  void _markUpiAsPaid({String? utrNumber}) {
    final payment = context.read<StudentPaymentCubit>().state.payment;
    if (payment != null) {
      context.read<StudentPaymentCubit>().markUpiPaymentAsPaid(
        paymentId: payment.id,
        utrNumber: utrNumber,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        backgroundColor: AppUIConstants.primary,
        title: const Text(
          'Complete Payment',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: BlocConsumer<StudentPaymentCubit, StudentPaymentState>(
        listener: (context, state) {
          if (state.isSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payment successful! Membership activated.'),
                backgroundColor: AppUIConstants.success,
              ),
            );
            Navigator.of(context).pop(true);
          }

          if (state.isCashPending) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Cash payment registered. Awaiting approval.',
                ),
                backgroundColor: AppUIConstants.primary,
              ),
            );
            Navigator.of(context).pop(true);
          }

          if (state.isUpiPending) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Payment marked complete. Awaiting approval.',
                ),
                backgroundColor: AppUIConstants.primary,
              ),
            );
            Navigator.of(context).pop(true);
          }

          if (state.isFailed && state.failure != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.failure!.message ?? 'Payment failed'),
                backgroundColor: AppUIConstants.error,
              ),
            );
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order Summary
                _OrderSummaryCard(
                  info: widget.membershipInfo,
                  overrideAmount: widget.overrideAmount,
                  isRemainingPayment: widget.isRemainingPayment,
                  isRenewal: widget.isRenewal,
                ),
                const SizedBox(height: 24),

                // Payment Status / Options
                if (state.isLoading)
                  const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                          color: AppUIConstants.primary,
                        ),
                        SizedBox(height: 16),
                        Text('Processing...'),
                      ],
                    ),
                  )
                else if (state.isSuccess)
                  _SuccessCard()
                else if (state.isCashPending)
                  _CashPendingCard()
                else if (state.isUpiAwaitingPayment)
                  // UPI payment initiated - show pay now option
                  _UpiPaymentCard(
                    payment: state.payment!,
                    library: widget.membershipInfo.library,
                    amount: widget.membershipInfo.paymentAmount,
                    onMarkAsPaid: _markUpiAsPaid,
                    isProcessing: state.isLoading,
                  )
                else if (state.hasPendingCashPayment)
                  // Already has a pending cash payment - show status
                  _PendingCashPaymentCard(
                    amount: widget.membershipInfo.paymentAmount,
                  )
                else if (state.hasPendingUpiPayment)
                  // Already has a pending UPI payment - show status
                  _PendingUpiPaymentCard(
                    amount: widget.membershipInfo.paymentAmount,
                  )
                else
                  _PaymentOptionsCard(
                    amount: widget.membershipInfo.paymentAmount,
                    onPayCash: _initiateCashPayment,
                    onPayUpi:
                        widget.membershipInfo.library?.isUpiEnabled == true
                        ? _initiateUpiPayment
                        : null,
                    ownerUpiId: widget.membershipInfo.library?.ownerUpiId,
                    isProcessing: state.isLoading,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({
    required this.info,
    this.overrideAmount,
    this.isRemainingPayment = false,
    this.isRenewal = false,
  });

  final StudentMembershipInfo info;
  final double? overrideAmount;
  final bool isRemainingPayment;
  final bool isRenewal;

  @override
  Widget build(BuildContext context) {
    final membership = info.membership;

    return Container(
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(color: AppUIConstants.border),
        boxShadow: [AppUIConstants.shadowSm],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isRenewal ? 'Renewal Summary' : 'Order Summary',
              style: AppUIConstants.headingSm,
            ),
            if (isRenewal) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppUIConstants.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppUIConstants.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'New membership will start from ${_formatDate(membership.endDate)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppUIConstants.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppUIConstants.divider),
            const SizedBox(height: 16),
            _SummaryRow(
              label: 'Library',
              value: info.library?.name ?? 'Unknown',
            ),
            _SummaryRow(label: 'Slot', value: info.slotName),
            _SummaryRow(
              label: 'Seat',
              value: membership.assignedSeatId ?? 'Not assigned',
            ),
            _SummaryRow(
              label: 'Plan',
              value: membership.plan.name.toUpperCase(),
            ),
            _SummaryRow(
              label: 'Duration',
              value: '${membership.plan.durationInDays} days',
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppUIConstants.divider),
            const SizedBox(height: 16),

            // Show discount if applied
            if (membership.paymentBreakdown?.hasDiscount ?? false) ...[
              _SummaryRow(
                label: 'Original Amount',
                value:
                    '₹${(membership.paymentBreakdown!.totalAmountBeforeDiscount).toStringAsFixed(0)}',
              ),
              _SummaryRow(
                label: 'Discount',
                value:
                    '-₹${(membership.paymentBreakdown!.discount).toStringAsFixed(0)}',
                valueColor: AppUIConstants.success,
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: AppUIConstants.divider),
              const SizedBox(height: 8),
            ],

            if (isRemainingPayment && info.hasPartialPayment) ...[
              _SummaryRow(
                label: 'Already Paid',
                value:
                    '₹${(info.membership.paymentBreakdown?.amountPaid ?? 0.0).toStringAsFixed(0)}',
              ),
              _SummaryRow(
                label: 'Remaining Amount',
                value:
                    '₹${(overrideAmount ?? info.remainingBalance).toStringAsFixed(0)}',
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: AppUIConstants.divider),
              const SizedBox(height: 8),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isRemainingPayment
                      ? 'Amount to Pay'
                      : isRenewal
                      ? 'Renewal Amount'
                      : 'Total Amount',
                  style: AppUIConstants.bodyLg,
                ),
                Text(
                  '₹${(overrideAmount ?? info.paymentAmount).toStringAsFixed(0)}',
                  style: AppUIConstants.headingMd.copyWith(
                    color: AppUIConstants.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppUIConstants.bodySm),
          Text(value, style: AppUIConstants.bodyMd.copyWith(color: valueColor)),
        ],
      ),
    );
  }
}

/// Card showing payment mode options (UPI & Cash).
class _PaymentOptionsCard extends StatelessWidget {
  const _PaymentOptionsCard({
    required this.amount,
    required this.onPayCash,
    this.onPayUpi,
    this.ownerUpiId,
    this.isProcessing = false,
  });

  final double amount;
  final VoidCallback onPayCash;
  final VoidCallback? onPayUpi;
  final String? ownerUpiId;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Payment Method', style: AppUIConstants.headingSm),
        const SizedBox(height: 16),

        // UPI Payment Option (if enabled)
        if (onPayUpi != null) ...[
          _PaymentModeCard(
            icon: Icons.account_balance_outlined,
            title: 'Pay via UPI',
            subtitle: 'Pay using any UPI app',
            amount: amount,
            color: AppUIConstants.success,
            isPrimary: true,
            isDisabled: isProcessing,
            onTap: isProcessing ? null : onPayUpi,
          ),
          const SizedBox(height: 12),
        ],

        // Cash Payment Option
        _PaymentModeCard(
          icon: Icons.payments_outlined,
          title: 'Pay Cash at PG',
          subtitle: 'Seat reserved until owner confirms',
          amount: amount,
          color: onPayUpi != null
              ? AppUIConstants.secondary
              : AppUIConstants.success,
          isPrimary: onPayUpi == null,
          isDisabled: isProcessing,
          onTap: isProcessing ? null : onPayCash,
        ),

        const SizedBox(height: 24),

        // Security info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppUIConstants.divider.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 18,
                color: AppUIConstants.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'All payments are secure. Your seat is reserved once payment is initiated.',
                  style: AppUIConstants.caption,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentModeCard extends StatelessWidget {
  const _PaymentModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.color,
    required this.isPrimary,
    this.isDisabled = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final double amount;
  final Color color;
  final bool isPrimary;
  final bool isDisabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isDisabled ? Colors.grey : color;
    final opacity = isDisabled ? 0.5 : 1.0;

    return Opacity(
      opacity: opacity,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isPrimary
                ? effectiveColor.withValues(alpha: 0.05)
                : AppUIConstants.surface,
            borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
            border: Border.all(
              color: isPrimary
                  ? effectiveColor.withValues(alpha: 0.3)
                  : AppUIConstants.border,
              width: isPrimary ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isDisabled
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.grey,
                        ),
                      )
                    : Icon(icon, color: effectiveColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppUIConstants.bodyLg.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDisabled ? Colors.grey : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDisabled ? 'Processing...' : subtitle,
                      style: AppUIConstants.caption,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${amount.toStringAsFixed(0)}',
                    style: AppUIConstants.headingSm.copyWith(
                      color: effectiveColor,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppUIConstants.textTertiary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppUIConstants.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(
          color: AppUIConstants.success.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle, size: 64, color: AppUIConstants.success),
          const SizedBox(height: 16),
          Text(
            'Payment Successful!',
            style: AppUIConstants.headingMd.copyWith(
              color: AppUIConstants.success,
            ),
          ),
          const SizedBox(height: 8),
          Text('Your membership is now active', style: AppUIConstants.bodySm),
        ],
      ),
    );
  }
}

class _CashPendingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Column(
        children: [
          // Status Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppUIConstants.warning.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.schedule_rounded,
              size: 32,
              color: AppUIConstants.warning,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Cash Payment Registered',
            style: AppUIConstants.headingMd.copyWith(
              color: AppUIConstants.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your seat is reserved.\nPlease pay cash at the library.',
            style: AppUIConstants.bodySm.copyWith(
              color: AppUIConstants.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppUIConstants.divider,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AppUIConstants.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Membership activates after owner confirms',
                    style: AppUIConstants.caption.copyWith(
                      color: AppUIConstants.textSecondary,
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

/// Card shown when student already has a pending cash payment.
class _PendingCashPaymentCard extends StatelessWidget {
  const _PendingCashPaymentCard({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Status Card - Neutral design
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppUIConstants.surface,
            borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
            border: Border.all(color: AppUIConstants.border),
          ),
          child: Column(
            children: [
              // Status Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppUIConstants.warning.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.schedule_rounded,
                  size: 32,
                  color: AppUIConstants.warning,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Awaiting Verification',
                style: AppUIConstants.headingMd.copyWith(
                  color: AppUIConstants.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your cash payment is being verified by the library owner.',
                style: AppUIConstants.bodySm.copyWith(
                  color: AppUIConstants.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppUIConstants.divider,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: AppUIConstants.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Membership activates once approved',
                        style: AppUIConstants.caption.copyWith(
                          color: AppUIConstants.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Card for UPI payment flow - shows UPI ID and "I've Paid" button.
class _UpiPaymentCard extends StatefulWidget {
  const _UpiPaymentCard({
    required this.payment,
    required this.library,
    required this.amount,
    required this.onMarkAsPaid,
    this.isProcessing = false,
  });

  final Payment payment;
  final Library? library;
  final double amount;
  final void Function({String? utrNumber}) onMarkAsPaid;
  final bool isProcessing;

  @override
  State<_UpiPaymentCard> createState() => _UpiPaymentCardState();
}

class _UpiPaymentCardState extends State<_UpiPaymentCard> {
  final _utrController = TextEditingController();

  @override
  void dispose() {
    _utrController.dispose();
    super.dispose();
  }

  /// UPI apps to display
  static const List<Map<String, dynamic>> _upiApps = [
    {
      'name': 'PhonePe',
      'icon': Icons.phone_android,
      'color': Color(0xFF5F259F),
      'iosScheme': 'phonepe://',
      'androidPackage': 'com.phonepe.app',
    },
    {
      'name': 'Google Pay',
      'icon': Icons.payment,
      'color': Color(0xFF4285F4),
      'iosScheme': 'tez://',
      'androidPackage': 'com.google.android.apps.nbu.paisa.user',
      'androidPackageFallback': 'com.google.android.apps.walletnfcrel',
      'playStoreUrl':
          'https://play.google.com/store/apps/details?id=com.google.android.apps.nbu.paisa.user',
    },
    {
      'name': 'Paytm',
      'icon': Icons.wallet,
      'color': Color(0xFF00BAF2),
      'iosScheme': 'paytmmp://',
      'androidPackage': 'net.one97.paytm',
    },
  ];

  void _copyUpiId() {
    final upiId = widget.library?.ownerUpiId ?? '';
    if (upiId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('UPI ID not available'),
          backgroundColor: AppUIConstants.error,
        ),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: upiId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('UPI ID copied'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppUIConstants.primary,
      ),
    );
  }

  Future<void> _launchUpiApp(Map<String, dynamic> app) async {
    try {
      final iosScheme = app['iosScheme'] as String?;
      final androidPackage = app['androidPackage'] as String?;
      final androidPackageFallback = app['androidPackageFallback'] as String?;
      final playStoreUrl = app['playStoreUrl'] as String?;

      // Try iOS URL scheme
      if (iosScheme != null) {
        final uri = Uri.parse(iosScheme);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }

      // Try primary Android package
      if (androidPackage != null) {
        final intentUri = Uri.parse(
          'intent://#Intent;scheme=upi;package=$androidPackage;end',
        );
        if (await canLaunchUrl(intentUri)) {
          await launchUrl(intentUri, mode: LaunchMode.externalApplication);
          return;
        }
      }

      // Try fallback Android package (for GPay)
      if (androidPackageFallback != null) {
        final intentUri = Uri.parse(
          'intent://#Intent;scheme=upi;package=$androidPackageFallback;end',
        );
        if (await canLaunchUrl(intentUri)) {
          await launchUrl(intentUri, mode: LaunchMode.externalApplication);
          return;
        }
      }

      // Try Play Store as final fallback
      if (playStoreUrl != null) {
        final playStoreUri = Uri.parse(playStoreUrl);
        if (await canLaunchUrl(playStoreUri)) {
          await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
          return;
        }
      }

      // If app not installed, copy UPI ID instead
      if (mounted) {
        _copyUpiId();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${app['name']} not installed. UPI ID copied instead.',
            ),
            backgroundColor: AppUIConstants.secondary,
          ),
        );
      }
    } catch (e) {
      // Fallback to copying UPI ID
      if (mounted) {
        _copyUpiId();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ownerUpiId = widget.library?.ownerUpiId ?? 'Not available';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Amount Card - Premium, minimal
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppUIConstants.surface,
            borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
            border: Border.all(color: AppUIConstants.border),
          ),
          child: Column(
            children: [
              // Amount Display
              Text(
                '₹${widget.amount.toStringAsFixed(0)}',
                style: AppUIConstants.headingLg.copyWith(
                  color: AppUIConstants.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 36,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Membership Payment',
                style: AppUIConstants.bodySm.copyWith(
                  color: AppUIConstants.textSecondary,
                ),
              ),
              const SizedBox(height: 20),

              // UPI Apps Grid
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: _upiApps.map((app) {
                  return InkWell(
                    onTap: () => _launchUpiApp(app),
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusMd,
                    ),
                    child: Container(
                      width: (MediaQuery.of(context).size.width - 120) / 3,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppUIConstants.surface,
                        borderRadius: BorderRadius.circular(
                          AppUIConstants.radiusMd,
                        ),
                        border: Border.all(color: AppUIConstants.border),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: (app['color'] as Color).withValues(
                                alpha: 0.1,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              app['icon'] as IconData,
                              color: app['color'] as Color,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            app['name'] as String,
                            style: AppUIConstants.bodySm.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Info text
              Text(
                'Tap to open UPI app and make payment',
                style: AppUIConstants.bodySm.copyWith(
                  color: AppUIConstants.textSecondary,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // UPI ID Display with Copy Button
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppUIConstants.background,
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
                  border: Border.all(color: AppUIConstants.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_outlined,
                      size: 14,
                      color: AppUIConstants.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ownerUpiId,
                        style: AppUIConstants.bodySm.copyWith(
                          color: AppUIConstants.textSecondary,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _copyUpiId,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.copy_rounded,
                          size: 16,
                          color: AppUIConstants.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Confirm Payment Section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppUIConstants.surface,
            borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
            border: Border.all(color: AppUIConstants.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'After completing payment',
                style: AppUIConstants.bodyMd.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppUIConstants.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Enter UTR for faster verification (optional)',
                style: AppUIConstants.caption,
              ),
              const SizedBox(height: 16),

              // UTR Input - Minimal
              TextFormField(
                controller: _utrController,
                decoration: InputDecoration(
                  hintText: 'UTR / Reference Number',
                  hintStyle: AppUIConstants.bodySm.copyWith(
                    color: AppUIConstants.textTertiary,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusMd,
                    ),
                    borderSide: const BorderSide(color: AppUIConstants.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusMd,
                    ),
                    borderSide: const BorderSide(color: AppUIConstants.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusMd,
                    ),
                    borderSide: const BorderSide(color: AppUIConstants.primary),
                  ),
                ),
                keyboardType: TextInputType.text,
              ),

              const SizedBox(height: 16),

              // Confirm Button - Outline style for secondary action
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: widget.isProcessing
                      ? null
                      : () => widget.onMarkAsPaid(
                          utrNumber: _utrController.text.isNotEmpty
                              ? _utrController.text
                              : null,
                        ),
                  icon: widget.isProcessing
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppUIConstants.primary,
                          ),
                        )
                      : Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    widget.isProcessing ? 'Processing...' : "I've Paid",
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppUIConstants.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: AppUIConstants.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppUIConstants.radiusMd,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Info Note - Subtle neutral design
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppUIConstants.divider,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: AppUIConstants.textTertiary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Owner will verify and approve your membership after payment.',
                  style: AppUIConstants.caption.copyWith(
                    color: AppUIConstants.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Card shown when student has a pending UPI payment.
class _PendingUpiPaymentCard extends StatelessWidget {
  const _PendingUpiPaymentCard({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Status Card - Premium, minimal
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppUIConstants.surface,
            borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
            border: Border.all(color: AppUIConstants.border),
          ),
          child: Column(
            children: [
              // Status Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppUIConstants.warning.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.schedule_rounded,
                  size: 32,
                  color: AppUIConstants.warning,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Awaiting Verification',
                style: AppUIConstants.headingMd.copyWith(
                  color: AppUIConstants.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your UPI payment is being verified by the library owner.',
                style: AppUIConstants.bodySm.copyWith(
                  color: AppUIConstants.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Info Row
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppUIConstants.divider,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: AppUIConstants.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Membership activates once approved',
                        style: AppUIConstants.caption.copyWith(
                          color: AppUIConstants.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
