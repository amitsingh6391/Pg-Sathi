import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../domain/entities/library.dart';
import '../../../domain/entities/membership.dart'; // For MembershipPlanExtension
import '../../../domain/entities/payment.dart';
import '../../../domain/usecases/get_student_memberships.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';
import '../cubit/student_payment_cubit.dart';
import '../cubit/student_payment_state.dart';

/// Checkout-style payment screen for completing a bed reservation.
/// Supports Cash and UPI payment modes.
/// Can be used for initial payment, completing remaining payment for partial
/// payments, or renewals.
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

enum _PayMethod { upi, cash }

class _PaymentScreenState extends State<PaymentScreen> {
  _PayMethod? _method;

  @override
  void initState() {
    super.initState();
    // Check for existing pending cash payment
    context.read<StudentPaymentCubit>().checkForExistingPayment(
      widget.membershipInfo.membership.id,
    );
  }

  double get _amount =>
      widget.overrideAmount ?? widget.membershipInfo.paymentAmount;

  void _initiateCashPayment() {
    final userId = widget.membershipInfo.membership.userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sync your stay first')),
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
        const SnackBar(content: Text('Please sync your stay first')),
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
    final upiEnabled = widget.membershipInfo.library?.acceptsUpi == true;
    final method = _method ?? (upiEnabled ? _PayMethod.upi : _PayMethod.cash);

    return Scaffold(
      backgroundColor: AppUIConstants.background,
      body: BlocConsumer<StudentPaymentCubit, StudentPaymentState>(
        listener: (context, state) {
          if (state.isSuccess) {
            _snack(
              'Payment successful! Stay activated.',
              AppUIConstants.success,
            );
            Navigator.of(context).pop(true);
          }

          if (state.isCashPending) {
            _snack(
              'Cash payment registered. Awaiting approval.',
              AppUIConstants.primary,
            );
            Navigator.of(context).pop(true);
          }

          if (state.isUpiPending) {
            _snack(
              'Payment marked complete. Awaiting approval.',
              AppUIConstants.primary,
            );
            Navigator.of(context).pop(true);
          }

          if (state.isFailed && state.failure != null) {
            _snack(
              state.failure!.message ?? 'Payment failed',
              AppUIConstants.error,
            );
          }
        },
        builder: (context, state) {
          final showOptions =
              !state.isLoading &&
              !state.isSuccess &&
              !state.isCashPending &&
              !state.isUpiAwaitingPayment &&
              !state.hasPendingCashPayment &&
              !state.hasPendingUpiPayment;

          Widget content;
          if (state.isLoading) {
            content = const _ProcessingCard(key: ValueKey('processing'));
          } else if (state.isSuccess) {
            content = const _SuccessCard(key: ValueKey('success'));
          } else if (state.isCashPending) {
            content = const _StatusCard(
              key: ValueKey('cash'),
              title: 'Cash payment registered',
              message: 'Your bed is reserved.\nPlease pay cash at the PG.',
              note: 'Stay activates after owner confirms',
            );
          } else if (state.isUpiAwaitingPayment) {
            content = _UpiPaymentCard(
              key: const ValueKey('upi'),
              payment: state.payment!,
              library: widget.membershipInfo.library,
              amount: _amount,
              onMarkAsPaid: _markUpiAsPaid,
              isProcessing: state.isLoading,
            );
          } else if (state.hasPendingCashPayment) {
            content = const _StatusCard(
              key: ValueKey('pendingCash'),
              title: 'Awaiting verification',
              message: 'Your cash payment is being verified by the PG owner.',
              note: 'Stay activates once approved',
            );
          } else if (state.hasPendingUpiPayment) {
            content = const _StatusCard(
              key: ValueKey('pendingUpi'),
              title: 'Awaiting verification',
              message: 'Your UPI payment is being verified by the PG owner.',
              note: 'Stay activates once approved',
            );
          } else {
            content = Column(
              key: const ValueKey('options'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.isFailed)
                  _FailureBanner(
                    message: state.failure?.message ?? 'Payment failed',
                  ),
                _MethodSelector(
                  upiEnabled: upiEnabled,
                  selected: method,
                  onSelect: (m) {
                    HapticFeedback.selectionClick();
                    setState(() => _method = m);
                  },
                ),
              ],
            );
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CheckoutHero(
                        amount: _amount,
                        isRenewal: widget.isRenewal,
                        isRemaining: widget.isRemainingPayment,
                        pgName: widget.membershipInfo.library?.name,
                        onBack: () => Navigator.of(context).maybePop(),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _OrderSummaryCard(
                              info: widget.membershipInfo,
                              overrideAmount: widget.overrideAmount,
                              isRemainingPayment: widget.isRemainingPayment,
                              isRenewal: widget.isRenewal,
                            ),
                            const PremiumSectionHeader('Payment'),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              switchInCurve: Curves.easeOut,
                              child: content,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (showOptions)
                _PayBar(
                  amount: _amount,
                  label: method == _PayMethod.upi
                      ? 'Pay with UPI'
                      : 'Reserve & pay cash',
                  onPay: method == _PayMethod.upi
                      ? _initiateUpiPayment
                      : _initiateCashPayment,
                ),
            ],
          );
        },
      ),
    );
  }

  void _snack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero + pay bar
// ---------------------------------------------------------------------------

class _CheckoutHero extends StatelessWidget {
  const _CheckoutHero({
    required this.amount,
    required this.isRenewal,
    required this.isRemaining,
    required this.pgName,
    required this.onBack,
  });

  final double amount;
  final bool isRenewal;
  final bool isRemaining;
  final String? pgName;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final title = isRemaining
        ? 'Balance due'
        : isRenewal
        ? 'Renew your stay'
        : 'Secure your bed';
    return PremiumHero(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppUIConstants.surfaceMuted,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppUIConstants.textPrimary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Checkout',
                style: TextStyle(
                  color: AppUIConstants.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.lock_rounded,
                size: 16,
                color: AppUIConstants.textSecondary,
              ),
              const SizedBox(width: 4),
              const Text(
                'Secure',
                style: TextStyle(
                  color: AppUIConstants.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Text(
            title,
            style: const TextStyle(
              color: AppUIConstants.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: amount),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text(
              '₹${NumberFormat.decimalPattern('en_IN').format(v.round())}',
              style: const TextStyle(
                color: AppUIConstants.textPrimary,
                fontSize: 44,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.5,
              ),
            ),
          ),
          if (pgName != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.apartment_rounded,
                  size: 15,
                  color: AppUIConstants.textSecondary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    pgName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppUIConstants.textSecondary,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PayBar extends StatelessWidget {
  const _PayBar({
    required this.amount,
    required this.label,
    required this.onPay,
  });

  final double amount;
  final String label;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppUIConstants.surface,
        border: Border(top: BorderSide(color: AppUIConstants.border)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Total', style: AppUIConstants.caption),
              Text(
                '₹${amount.toStringAsFixed(0)}',
                style: AppUIConstants.headingMd,
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                onPay();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppUIConstants.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plan summary
// ---------------------------------------------------------------------------

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
    final breakdown = membership.paymentBreakdown;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppUIConstants.primaryLight.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
                ),
                child: const Icon(
                  Icons.bed_rounded,
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
                      isRenewal ? 'Renewal summary' : 'Stay summary',
                      style: AppUIConstants.headingSm,
                    ),
                    Text(
                      '${membership.plan.name.toUpperCase()} plan  •  ${membership.plan.durationInDays} days',
                      style: AppUIConstants.bodySm,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isRenewal) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppUIConstants.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppUIConstants.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'New stay will start from ${_formatDate(membership.endDate)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppUIConstants.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppUIConstants.divider),
          const SizedBox(height: 10),
          _SummaryRow(label: 'PG', value: info.library?.name ?? 'Unknown'),
          _SummaryRow(label: 'Slot', value: info.slotName),
          _SummaryRow(
            label: 'Bed',
            value: membership.assignedSeatId ?? 'Not assigned',
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppUIConstants.divider),
          const SizedBox(height: 10),
          if (breakdown?.hasDiscount ?? false) ...[
            _SummaryRow(
              label: 'Original amount',
              value:
                  '₹${breakdown!.totalAmountBeforeDiscount.toStringAsFixed(0)}',
            ),
            _SummaryRow(
              label: 'Discount',
              value: '-₹${breakdown.discount.toStringAsFixed(0)}',
              valueColor: AppUIConstants.success,
            ),
          ],
          if (isRemainingPayment && info.hasPartialPayment) ...[
            _SummaryRow(
              label: 'Already paid',
              value: '₹${(breakdown?.amountPaid ?? 0.0).toStringAsFixed(0)}',
            ),
            _SummaryRow(
              label: 'Remaining amount',
              value:
                  '₹${(overrideAmount ?? info.remainingBalance).toStringAsFixed(0)}',
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isRemainingPayment
                    ? 'Amount to pay'
                    : isRenewal
                    ? 'Renewal amount'
                    : 'Total amount',
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
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: AppUIConstants.bodyMd.copyWith(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Method selection
// ---------------------------------------------------------------------------

class _MethodSelector extends StatelessWidget {
  const _MethodSelector({
    required this.upiEnabled,
    required this.selected,
    required this.onSelect,
  });

  final bool upiEnabled;
  final _PayMethod selected;
  final ValueChanged<_PayMethod> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (upiEnabled) ...[
          _MethodTile(
            icon: Icons.account_balance_outlined,
            title: 'Pay via UPI',
            subtitle: 'PhonePe, Google Pay, Paytm and more',
            color: AppUIConstants.success,
            selected: selected == _PayMethod.upi,
            badge: 'Fastest',
            onTap: () => onSelect(_PayMethod.upi),
          ),
          const SizedBox(height: 12),
        ],
        _MethodTile(
          icon: Icons.payments_outlined,
          title: 'Pay cash at PG',
          subtitle: 'Bed reserved until owner confirms',
          color: AppUIConstants.primaryLight,
          selected: selected == _PayMethod.cash,
          onTap: () => onSelect(_PayMethod.cash),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppUIConstants.surfaceMuted,
            borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 18,
                color: AppUIConstants.textSecondary,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'All payments are secure. Your bed is reserved once payment is initiated.',
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

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.08)
              : AppUIConstants.surface,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
          border: Border.all(
            color: selected ? color : AppUIConstants.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: AppUIConstants.bodyLg.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        PremiumStatusPill(badge!, color: color),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppUIConstants.caption),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? color : Colors.transparent,
                border: Border.all(
                  color: selected ? color : AppUIConstants.disabled,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppUIConstants.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(color: AppUIConstants.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppUIConstants.error,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$message. Please try again.',
              style: const TextStyle(
                color: AppUIConstants.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// States
// ---------------------------------------------------------------------------

class _ProcessingCard extends StatelessWidget {
  const _ProcessingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const PremiumCard(
      padding: EdgeInsets.symmetric(vertical: 36),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                color: AppUIConstants.primaryLight,
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 16),
            Text('Processing...', style: AppUIConstants.headingSm),
            SizedBox(height: 4),
            Text(
              'Please do not close this screen',
              style: AppUIConstants.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessCard extends StatelessWidget {
  const _SuccessCard({super.key});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.4, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppUIConstants.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 48,
                  color: AppUIConstants.success,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Payment successful',
              style: AppUIConstants.headingMd.copyWith(
                color: AppUIConstants.success,
              ),
            ),
            const SizedBox(height: 6),
            const Text('Your stay is now active', style: AppUIConstants.bodySm),
          ],
        ),
      ),
    );
  }
}

/// Shared "waiting for owner" status card.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    super.key,
    required this.title,
    required this.message,
    required this.note,
  });

  final String title;
  final String message;
  final String note;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppUIConstants.warning.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.hourglass_top_rounded,
                size: 32,
                color: AppUIConstants.warning,
              ),
            ),
            const SizedBox(height: 16),
            Text(title, style: AppUIConstants.headingMd),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppUIConstants.bodySm,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppUIConstants.surfaceMuted,
                borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppUIConstants.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(note, style: AppUIConstants.caption)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// UPI flow
// ---------------------------------------------------------------------------

class _UpiPaymentCard extends StatefulWidget {
  const _UpiPaymentCard({
    super.key,
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

  void _showQrFullScreen(BuildContext context, String qrUrl) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
                child: Image.network(
                  qrUrl,
                  fit: BoxFit.contain,
                  // Show via an <img> tag on web if the CORS fetch is blocked.
                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(
                    width: 240,
                    height: 240,
                    child: Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.close, color: Colors.white),
              label: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _copyUpiId() {
    final upiId = widget.library?.ownerUpiId ?? '';
    if (upiId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('UPI ID not available'),
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
    final ownerUpiId = widget.library?.ownerUpiId ?? '';
    final hasUpiId = ownerUpiId.trim().isNotEmpty;
    final qrUrl = widget.library?.ownerUpiQrUrl;
    final hasQr = widget.library?.hasUpiQr == true;
    final tileWidth = (MediaQuery.of(context).size.width - 32 - 32 - 24) / 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '1. Pick an app and pay',
                style: AppUIConstants.headingSm,
              ),
              const SizedBox(height: 4),
              Text(
                'Send ₹${widget.amount.toStringAsFixed(0)} to the PG owner',
                style: AppUIConstants.bodySm,
              ),
              const SizedBox(height: 16),
              // UPI QR Code - scan to pay
              if (hasQr) ...[
                Text(
                  'Scan QR to Pay',
                  style: AppUIConstants.bodySm.copyWith(
                    color: AppUIConstants.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: GestureDetector(
                    onTap: () => _showQrFullScreen(context, qrUrl),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          AppUIConstants.radiusMd,
                        ),
                        border: Border.all(color: AppUIConstants.border),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppUIConstants.radiusSm,
                        ),
                        child: Image.network(
                          qrUrl!,
                          width: 220,
                          height: 220,
                          fit: BoxFit.contain,
                          // Show via an <img> tag on web if the CORS fetch is blocked.
                          webHtmlElementStrategy:
                              WebHtmlElementStrategy.fallback,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const SizedBox(
                              width: 220,
                              height: 220,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox(
                                width: 220,
                                height: 220,
                                child: Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                    size: 40,
                                  ),
                                ),
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Tap to enlarge · Scan with any UPI app',
                    style: AppUIConstants.bodySm.copyWith(
                      color: AppUIConstants.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Or open a UPI app',
                  style: AppUIConstants.bodySm.copyWith(
                    color: AppUIConstants.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _upiApps.map((app) {
                  final c = app['color'] as Color;
                  return InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _launchUpiApp(app);
                    },
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusMd,
                    ),
                    child: Container(
                      width: tileWidth,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppUIConstants.surfaceMuted,
                        borderRadius: BorderRadius.circular(
                          AppUIConstants.radiusMd,
                        ),
                        border: Border.all(color: AppUIConstants.border),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: c.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              app['icon'] as IconData,
                              color: c,
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            app['name'] as String,
                            style: AppUIConstants.bodySm.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppUIConstants.textPrimary,
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
              if (hasUpiId) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                  decoration: BoxDecoration(
                    color: AppUIConstants.background,
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusSm,
                    ),
                    border: Border.all(color: AppUIConstants.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_balance_outlined,
                        size: 16,
                        color: AppUIConstants.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ownerUpiId,
                          style: AppUIConstants.bodyMd.copyWith(
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          _copyUpiId();
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppUIConstants.primaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '2. Confirm your payment',
                style: AppUIConstants.headingSm,
              ),
              const SizedBox(height: 4),
              const Text(
                'Enter UTR for faster verification (optional)',
                style: AppUIConstants.caption,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _utrController,
                style: AppUIConstants.bodyMd,
                decoration: InputDecoration(
                  hintText: 'UTR / Reference Number',
                  hintStyle: AppUIConstants.bodySm.copyWith(
                    color: AppUIConstants.textTertiary,
                  ),
                  filled: true,
                  fillColor: AppUIConstants.surfaceMuted,
                  prefixIcon: const Icon(
                    Icons.tag_rounded,
                    size: 18,
                    color: AppUIConstants.textTertiary,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: _inputBorder(AppUIConstants.border),
                  enabledBorder: _inputBorder(AppUIConstants.border),
                  focusedBorder: _inputBorder(AppUIConstants.primaryLight),
                ),
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: widget.isProcessing
                      ? null
                      : () {
                          HapticFeedback.mediumImpact();
                          widget.onMarkAsPaid(
                            utrNumber: _utrController.text.isNotEmpty
                                ? _utrController.text
                                : null,
                          );
                        },
                  icon: widget.isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppUIConstants.primaryLight,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    widget.isProcessing ? 'Processing...' : "I've paid",
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppUIConstants.success,
                    foregroundColor: AppUIConstants.background,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppUIConstants.surfaceMuted,
            borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: AppUIConstants.textTertiary,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Owner will verify and approve your stay after payment.',
                  style: AppUIConstants.caption,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
    borderSide: BorderSide(color: color),
  );
}
