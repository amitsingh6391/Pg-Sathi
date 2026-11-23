import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../domain/entities/library.dart';
import '../../../domain/entities/subscription.dart';
import '../../../domain/entities/subscription_plan.dart';
import '../../../domain/usecases/calculate_subscription_price.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';
import '../../core/widgets/whatsapp_support_button.dart';
import '../cubit/subscription_cubit.dart';
import '../widgets/upi_bottom_sheet.dart';

/// Screen for UPI payment with manual verification flow.
class UpiPaymentScreen extends StatefulWidget {
  const UpiPaymentScreen({
    super.key,
    this.subscription,
    required this.library,
    this.ownerId,
    this.libraryId,
    this.seatCount,
    this.durationInMonths,
    this.priceResult,
    this.customLibraryPrice,
    this.adminDiscountPercent,
    this.couponCode,
    this.finalAmountWithCoupon,
    this.referralCode,
  });

  final Subscription? subscription;
  final Library library;
  // Parameters for creating subscription on payment verification
  final String? ownerId;
  final String? libraryId;
  final int? seatCount;
  final int? durationInMonths;
  final SubscriptionPriceResult? priceResult;
  final double? customLibraryPrice;
  final double? adminDiscountPercent;
  final String? couponCode;
  final double? finalAmountWithCoupon;
  final String? referralCode;

  @override
  State<UpiPaymentScreen> createState() => _UpiPaymentScreenState();
}

class _UpiPaymentScreenState extends State<UpiPaymentScreen> {
  final _transactionController = TextEditingController();
  bool _showTransactionInput = false;
  Razorpay? _razorpay;

  bool get _usesAppleInAppPurchase =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    if (!_usesAppleInAppPurchase) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleRazorpaySuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handleRazorpayError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    }
  }

  @override
  void dispose() {
    _razorpay?.clear();
    _transactionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SubscriptionCubit, SubscriptionState>(
      listener: (context, state) {
        if (state.isSuccess) {
          _showInstantSuccessDialog();
        } else if (state.isPendingVerification) {
          _showPendingVerificationDialog();
        }
        if (state.hasError && state.errorMessage != null) {
          _showError(state.errorMessage!);
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppUIConstants.background,
          floatingActionButton: WhatsAppSupportButton(
            heroTag: 'upi_payment_support',
            contextMessage:
                'Hi, I need help with my payment.\n\n'
                'PG: ${widget.library.name}\n'
                'Amount: \u20b9${(widget.subscription?.finalAmount ?? widget.finalAmountWithCoupon ?? widget.priceResult?.finalAmount ?? 0).toStringAsFixed(0)}',
          ),
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildHero(),
              Padding(
                padding: const EdgeInsets.all(AppUIConstants.spacingLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_usesAppleInAppPurchase) ...[
                      _buildStepper(),
                      const SizedBox(height: AppUIConstants.spacingSm),
                    ],
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: KeyedSubtree(
                        key: ValueKey(
                          _usesAppleInAppPurchase
                              ? 'iap'
                              : _showTransactionInput,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_usesAppleInAppPurchase)
                              _buildInAppPurchaseSection(state)
                            else if (!_showTransactionInput) ...[
                              _buildUpiAppsSection(),
                              const SizedBox(height: AppUIConstants.spacingLg),
                              _buildAlreadyPaidButton(),
                            ] else
                              _buildTransactionSection(state),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUpiAppsSection() {
    return _buildPaymentOptions();
  }

  double get _amount =>
      widget.subscription?.finalAmount ??
      widget.finalAmountWithCoupon ??
      widget.priceResult?.finalAmount ??
      0;

  int get _months =>
      widget.subscription?.durationInMonths ?? widget.durationInMonths ?? 0;

  Widget _buildHero() {
    return PremiumHero(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                color: AppUIConstants.textPrimary,
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                constraints: const BoxConstraints(minWidth: 40),
              ),
              Text(
                _usesAppleInAppPurchase
                    ? 'App Store Purchase'
                    : 'Complete Payment',
                style: AppUIConstants.headingMd,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Amount to pay', style: AppUIConstants.bodyMd),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _amount),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Text(
              '₹${v.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: AppUIConstants.textPrimary,
                letterSpacing: -1.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _heroChip(
                Icons.event_repeat_rounded,
                '$_months Month${_months > 1 ? 's' : ''} Plan',
              ),
              _heroChip(Icons.apartment_rounded, widget.library.name),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroChip(IconData icon, String label) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppUIConstants.surfaceMuted,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppUIConstants.primaryLight),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppUIConstants.bodySm.copyWith(
                color: AppUIConstants.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    final current = _showTransactionInput ? 1 : 0;
    const labels = ['Pay', 'Verify', 'Active'];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < current
                      ? AppUIConstants.success
                      : i == current
                      ? AppUIConstants.warning
                      : AppUIConstants.surfaceMuted,
                  border: Border.all(
                    color: i <= current
                        ? Colors.transparent
                        : AppUIConstants.border,
                  ),
                ),
                alignment: Alignment.center,
                child: i < current
                    ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      )
                    : Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: i == current
                              ? Colors.white
                              : AppUIConstants.textTertiary,
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                labels[i],
                style: AppUIConstants.caption.copyWith(
                  color: i <= current
                      ? AppUIConstants.textPrimary
                      : AppUIConstants.textTertiary,
                ),
              ),
            ],
          ),
          if (i < labels.length - 1)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18, left: 6, right: 6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 2,
                  color: i < current
                      ? AppUIConstants.success
                      : AppUIConstants.border,
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildAlreadyPaidButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          HapticFeedback.selectionClick();
          setState(() => _showTransactionInput = true);
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppUIConstants.success,
          side: BorderSide(
            color: AppUIConstants.success.withValues(alpha: 0.5),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          ),
        ),
        icon: const Icon(Icons.check_circle_outline, size: 18),
        label: const Text(
          'I\'ve already paid',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildTransactionSection(SubscriptionState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _UpiIdChip(),
        const SizedBox(height: AppUIConstants.spacingMd),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppUIConstants.success.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      color: AppUIConstants.success,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppUIConstants.spacingMd),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enter Transaction ID',
                          style: AppUIConstants.bodyLg,
                        ),
                        Text(
                          'Last 5+ digits of the UPI reference number',
                          style: AppUIConstants.bodySm,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppUIConstants.spacingLg),
              TextField(
                controller: _transactionController,
                style: AppUIConstants.bodyLg.copyWith(letterSpacing: 1),
                decoration: InputDecoration(
                  hintText: 'e.g., 123456789012',
                  hintStyle: AppUIConstants.bodyMd.copyWith(
                    color: AppUIConstants.textTertiary,
                  ),
                  filled: true,
                  fillColor: AppUIConstants.surfaceMuted,
                  prefixIcon: const Icon(
                    Icons.tag,
                    color: AppUIConstants.textSecondary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusMd,
                    ),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppUIConstants.spacingMd,
                    vertical: AppUIConstants.spacingMd,
                  ),
                ),
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: AppUIConstants.spacingLg),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: state.isLoading ? null : _markPaymentDone,
                  style: AppUIConstants.primaryButtonStyle,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: state.isLoading
                        ? const SizedBox(
                            key: ValueKey('busy'),
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Verify Payment',
                            key: ValueKey('idle'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: AppUIConstants.spacingSm),
              Center(
                child: TextButton(
                  onPressed: () =>
                      setState(() => _showTransactionInput = false),
                  child: Text(
                    '← Back to payment options',
                    style: AppUIConstants.bodySm.copyWith(
                      color: AppUIConstants.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoNote(String text) {
    return Container(
      padding: const EdgeInsets.all(AppUIConstants.spacingMd),
      decoration: BoxDecoration(
        color: AppUIConstants.primarySoft,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(
          color: AppUIConstants.primaryLight.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            color: AppUIConstants.primaryLight,
            size: 20,
          ),
          const SizedBox(width: AppUIConstants.spacingSm),
          Expanded(
            child: Text(
              text,
              style: AppUIConstants.bodySm.copyWith(
                color: AppUIConstants.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOptions() {
    final amount = _amount;
    final razorpayAmount = amount + (amount * 0.025); // Add 2.5% charges

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PremiumSectionHeader('Choose Payment Method'),
        _buildPaymentOptionCard(
          title: 'Pay via UPI (Free)',
          subtitle: 'Copy UPI ID and pay manually\nVerification: Up to 1 hour',
          amount: amount,
          icon: Icons.account_balance_wallet_outlined,
          color: AppUIConstants.success,
          onTap: () => _showManualUpiOption(),
          badge: 'RECOMMENDED',
          highlighted: true,
        ),
        const SizedBox(height: AppUIConstants.spacingMd),
        _buildPaymentOptionCard(
          title: 'Pay via Razorpay (Instant)',
          subtitle: 'Credit/Debit Card, UPI, NetBanking\nInstant verification',
          amount: razorpayAmount,
          icon: Icons.payment,
          color: AppUIConstants.primaryLight,
          onTap: () => _initiateRazorpay(),
          badge: '+ 2.5% charges',
          badgeColor: AppUIConstants.primaryLight,
        ),
        const SizedBox(height: AppUIConstants.spacingMd),
        _buildInfoNote(
          'If paying manually via PhonePe/other UPI apps: Copy UPI ID → Make payment → Tap "I have already paid" → Enter last min 5 digits of transaction reference ID',
        ),
      ],
    );
  }

  Widget _buildInAppPurchaseSection(SubscriptionState state) {
    final amount = _amount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PremiumSectionHeader('Complete with App Store'),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppUIConstants.primarySoft,
                      borderRadius: BorderRadius.circular(
                        AppUIConstants.radiusMd,
                      ),
                    ),
                    child: const Icon(
                      Icons.apple,
                      color: AppUIConstants.primaryLight,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: AppUIConstants.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'In-App Purchase',
                          style: AppUIConstants.headingSm,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_months month plan',
                          style: AppUIConstants.bodySm,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppUIConstants.primaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppUIConstants.spacingLg),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: state.isLoading ? null : _startInAppPurchase,
                  style: AppUIConstants.primaryButtonStyle,
                  child: state.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Continue with App Store',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppUIConstants.spacingMd),
        _buildInfoNote(
          'On iPhone and iPad, subscription purchases are completed through Apple in-app purchase.',
        ),
      ],
    );
  }

  Widget _buildPaymentOptionCard({
    required String title,
    required String subtitle,
    required double amount,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? badge,
    Color? badgeColor,
    bool highlighted = false,
  }) {
    final badgeC = badgeColor ?? AppUIConstants.success;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppUIConstants.radiusLg + 2),
        border: highlighted
            ? Border.all(color: color.withValues(alpha: 0.7), width: 1.5)
            : null,
      ),
      child: PremiumCard(
        glow: highlighted ? color : null,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppUIConstants.surfaceMuted,
                borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
              ),
              child: Icon(icon, color: AppUIConstants.textSecondary, size: 26),
            ),
            const SizedBox(width: AppUIConstants.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (badge != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: PremiumStatusPill(badge, color: badgeC),
                    ),
                  Text(title, style: AppUIConstants.headingSm),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppUIConstants.bodySm.copyWith(height: 1.3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppUIConstants.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showManualUpiOption() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UpiBottomSheet(
        amount:
            widget.subscription?.finalAmount ??
            widget.finalAmountWithCoupon ??
            widget.priceResult?.finalAmount ??
            0,
        onAppLaunched: () {
          // Don't auto-show transaction input
          // Let user manually click "I've already paid" after they actually make payment
        },
        onError: _showError,
        getUpiAppIcon: _getUpiAppIcon,
        getUpiAppColor: _getUpiAppColor,
      ),
    );
  }

  IconData _getUpiAppIcon(String appName) {
    if (appName.toLowerCase().contains('phonepe')) return Icons.phone_android;
    if (appName.toLowerCase().contains('google') ||
        appName.toLowerCase().contains('pay')) {
      return Icons.payment;
    }
    if (appName.toLowerCase().contains('paytm')) return Icons.wallet;
    if (appName.toLowerCase().contains('amazon')) return Icons.shopping_cart;
    if (appName.toLowerCase().contains('cred')) return Icons.credit_card;
    return Icons.account_balance;
  }

  Color _getUpiAppColor(String appName) {
    if (appName.toLowerCase().contains('phonepe')) {
      return const Color(0xFF5F259F);
    }
    if (appName.toLowerCase().contains('google')) {
      return const Color(0xFF4285F4);
    }
    if (appName.toLowerCase().contains('paytm')) return const Color(0xFF00BAF2);
    if (appName.toLowerCase().contains('amazon')) {
      return const Color(0xFFFF9900);
    }
    if (appName.toLowerCase().contains('cred')) return Colors.black;
    return AppUIConstants.primary;
  }

  void _initiateRazorpay() {
    if (_usesAppleInAppPurchase) {
      _showError('Use App Store in-app purchase on this device.');
      return;
    }

    final amount =
        widget.subscription?.finalAmount ??
        widget.finalAmountWithCoupon ??
        widget.priceResult?.finalAmount ??
        0;
    final amountWithCharges =
        amount * (1 + SubscriptionPlan.razorpayChargePercent / 100);
    final amountInPaise = (amountWithCharges * 100).round();

    var options = {
      'key': SubscriptionPlan.razorpayLiveKey,
      'amount': amountInPaise,
      'name': SubscriptionPlan.appName,
      'description':
          'Owner Subscription - ${widget.subscription?.durationInMonths ?? widget.durationInMonths ?? 0} months',
      'prefill': {'contact': widget.library.ownerPhone ?? '', 'email': ''},
      'theme': {'color': '#0F8F8A'},
      'method': {'upi': true, 'card': true, 'netbanking': true, 'wallet': true},
    };

    try {
      _razorpay?.open(options);
    } catch (e) {
      _showError('Failed to open Razorpay: $e');
    }
  }

  void _startInAppPurchase() {
    _showError(
      'In-app purchase products are not configured yet. Add App Store product IDs and receipt verification before release.',
    );
  }

  void _handleRazorpaySuccess(PaymentSuccessResponse response) async {
    // Razorpay payment successful - auto-approve and activate instantly
    final cubit = context.read<SubscriptionCubit>();

    // If subscription doesn't exist, create it first
    if (widget.subscription == null) {
      await cubit.initiatePayment(
        ownerId: widget.ownerId!,
        libraryId: widget.libraryId!,
        seatCount: widget.seatCount!,
        durationInMonths: widget.durationInMonths!,
        customLibraryPrice: widget.customLibraryPrice,
        adminDiscountPercent: widget.adminDiscountPercent,
        couponCode: widget.couponCode,
        referralCode: widget.referralCode,
      );

      await Future.delayed(const Duration(milliseconds: 400));

      final state = cubit.state;
      if (state.createdSubscription == null) {
        _showError('Failed to create subscription');
        return;
      }

      // Now approve with Razorpay
      cubit.approveRazorpayPayment(
        subscriptionId: state.createdSubscription!.id,
        razorpayPaymentId: response.paymentId ?? 'razorpay_success',
        ownerName: widget.library.ownerPhone ?? 'Owner',
        libraryName: widget.library.name,
        amount:
            state.createdSubscription!.finalAmount *
            (1 + SubscriptionPlan.razorpayChargePercent / 100),
        durationMonths: state.createdSubscription!.durationInMonths,
      );
    } else {
      // Legacy flow - subscription already exists
      cubit.approveRazorpayPayment(
        subscriptionId: widget.subscription!.id,
        razorpayPaymentId: response.paymentId ?? 'razorpay_success',
        ownerName: widget.library.ownerPhone ?? 'Owner',
        libraryName: widget.library.name,
        amount:
            widget.subscription!.finalAmount *
            (1 + SubscriptionPlan.razorpayChargePercent / 100),
        durationMonths: widget.subscription!.durationInMonths,
      );
    }
  }

  void _handleRazorpayError(PaymentFailureResponse response) {
    _showError('Payment failed: ${response.message ?? "Unknown error"}');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showError('External wallet selected: ${response.walletName}');
  }

  // =========================================================================
  // Action Methods
  // =========================================================================

  void _markPaymentDone() async {
    if (_usesAppleInAppPurchase) {
      _showError('Manual payment is not available on iPhone or iPad.');
      return;
    }

    final txnId = _transactionController.text.trim();
    if (txnId.isEmpty) {
      _showError('Please enter the transaction/reference number');
      return;
    }

    final cubit = context.read<SubscriptionCubit>();

    // If subscription doesn't exist, create it first
    if (widget.subscription == null) {
      await cubit.initiatePayment(
        ownerId: widget.ownerId!,
        libraryId: widget.libraryId!,
        seatCount: widget.seatCount!,
        durationInMonths: widget.durationInMonths!,
        customLibraryPrice: widget.customLibraryPrice,
        adminDiscountPercent: widget.adminDiscountPercent,
        couponCode: widget.couponCode,
        referralCode: widget.referralCode,
      );

      // Wait for subscription creation
      await Future.delayed(const Duration(milliseconds: 400));

      final state = cubit.state;
      if (state.createdSubscription == null) {
        _showError('Failed to create subscription. Please try again.');
        return;
      }

      // Now mark payment as done
      cubit.markPaymentAsDone(
        subscriptionId: state.createdSubscription!.id,
        transactionId: txnId,
        libraryName: widget.library.name,
        ownerName: widget.library.ownerPhone ?? 'Owner',
      );
    } else {
      // Legacy flow - subscription already exists
      cubit.markPaymentAsDone(
        subscriptionId: widget.subscription!.id,
        transactionId: txnId,
        libraryName: widget.library.name,
        ownerName: widget.library.ownerPhone ?? 'Owner',
      );
    }
  }

  void _showPendingVerificationDialog() {
    // Capture the screen's navigator before showing dialog
    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppUIConstants.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppUIConstants.primaryLight.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.hourglass_top_rounded,
                color: AppUIConstants.primaryLight,
                size: 40,
              ),
            ),
            const SizedBox(height: AppUIConstants.spacingLg),
            Text(
              'Payment Submitted!',
              style: AppUIConstants.headingMd,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppUIConstants.spacingSm),
            Text(
              'We\'re verifying your payment.\nYour subscription will be activated within 1 hour.',
              style: AppUIConstants.bodyMd.copyWith(
                color: AppUIConstants.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppUIConstants.spacingMd),
            Container(
              padding: const EdgeInsets.all(AppUIConstants.spacingMd),
              decoration: BoxDecoration(
                color: AppUIConstants.background,
                borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
              ),
              child: Text(
                'You can close the app. We\'ll notify you once your subscription is active.',
                style: AppUIConstants.bodySm.copyWith(
                  color: AppUIConstants.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close dialog
                navigator.pop(
                  true,
                ); // Return to dashboard using screen's navigator
              },
              style: AppUIConstants.primaryButtonStyle,
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  void _showInstantSuccessDialog() {
    // Capture the screen's navigator before showing dialog
    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppUIConstants.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppUIConstants.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                color: AppUIConstants.success,
                size: 50,
              ),
            ),
            const SizedBox(height: AppUIConstants.spacingLg),
            Text(
              'Payment Successful!',
              style: AppUIConstants.headingMd.copyWith(
                color: AppUIConstants.success,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppUIConstants.spacingSm),
            Text(
              'Your subscription is now active!',
              style: AppUIConstants.bodyLg.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppUIConstants.spacingMd),
            Container(
              padding: const EdgeInsets.all(AppUIConstants.spacingMd),
              decoration: BoxDecoration(
                color: AppUIConstants.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
                border: Border.all(
                  color: AppUIConstants.success.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.celebration_outlined,
                        color: AppUIConstants.success,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Instant Activation',
                        style: AppUIConstants.bodyMd.copyWith(
                          color: AppUIConstants.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.subscription?.durationInMonths ?? widget.durationInMonths ?? 0} month${(widget.subscription?.durationInMonths ?? widget.durationInMonths ?? 0) > 1 ? 's' : ''} plan activated',
                    style: AppUIConstants.bodySm.copyWith(
                      color: AppUIConstants.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppUIConstants.spacingMd),
            Text(
              '✨ You can now enjoy all premium features',
              style: AppUIConstants.bodySm.copyWith(
                color: AppUIConstants.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close dialog
                navigator.pop(true); // Return to dashboard
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppUIConstants.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: AppUIConstants.spacingMd,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Start Using',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppUIConstants.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// UPI ID pill with a tap-to-copy micro-interaction.
class _UpiIdChip extends StatefulWidget {
  const _UpiIdChip();

  @override
  State<_UpiIdChip> createState() => _UpiIdChipState();
}

class _UpiIdChipState extends State<_UpiIdChip> {
  bool _copied = false;

  Future<void> _copy() async {
    HapticFeedback.mediumImpact();
    await Clipboard.setData(ClipboardData(text: SubscriptionPlan.upiId));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final color = _copied
        ? AppUIConstants.success
        : AppUIConstants.primaryLight;
    return GestureDetector(
      onTap: _copy,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppUIConstants.surface,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Icon(Icons.alternate_email_rounded, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('UPI ID', style: AppUIConstants.caption),
                  Text(
                    SubscriptionPlan.upiId,
                    style: AppUIConstants.bodyLg,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _copied ? Icons.check_circle_rounded : Icons.copy_rounded,
                key: ValueKey(_copied),
                size: 20,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
