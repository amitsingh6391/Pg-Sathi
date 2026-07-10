import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../domain/entities/library.dart';
import '../../../domain/entities/subscription.dart';
import '../../../domain/entities/subscription_plan.dart';
import '../../../domain/usecases/calculate_subscription_price.dart';
import '../../core/app_ui_constants.dart';
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
                'Library: ${widget.library.name}\n'
                'Amount: \u20b9${(widget.subscription?.finalAmount ?? widget.finalAmountWithCoupon ?? widget.priceResult?.finalAmount ?? 0).toStringAsFixed(0)}',
          ),
          body: CustomScrollView(
            slivers: [
              // App Bar with Amount
              _buildAppBar(),

              // Content
              SliverPadding(
                padding: const EdgeInsets.all(AppUIConstants.spacingLg),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (_usesAppleInAppPurchase) ...[
                      _buildInAppPurchaseSection(state),
                    ] else if (!_showTransactionInput) ...[
                      // UPI Apps Section
                      _buildUpiAppsSection(),
                      const SizedBox(height: AppUIConstants.spacingLg),
                      // Already Paid Button
                      _buildAlreadyPaidButton(),
                    ] else ...[
                      // Transaction Input Section
                      _buildTransactionSection(state),
                    ],

                    const SizedBox(height: AppUIConstants.spacingLg),

                    const SizedBox(height: AppUIConstants.spacing2Xl),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: AppUIConstants.primary,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: AppUIConstants.primary,
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Text(
                  'Pay Securely',
                  style: AppUIConstants.bodyMd.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: AppUIConstants.spacingXs),
                Text(
                  '₹${(widget.subscription?.finalAmount ?? widget.finalAmountWithCoupon ?? widget.priceResult?.finalAmount ?? 0).toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: AppUIConstants.spacingXs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppUIConstants.spacingMd,
                    vertical: AppUIConstants.spacingXs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusFull,
                    ),
                  ),
                  child: Text(
                    '${widget.subscription?.durationInMonths ?? widget.durationInMonths ?? 0} Month${(widget.subscription?.durationInMonths ?? widget.durationInMonths ?? 0) > 1 ? 's' : ''} Plan',
                    style: AppUIConstants.bodySm.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      title: Text(
        _usesAppleInAppPurchase ? 'App Store Purchase' : 'Complete Payment',
      ),
    );
  }

  Widget _buildUpiAppsSection() {
    return _buildPaymentOptions();
  }

  Widget _buildAlreadyPaidButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: () => setState(() => _showTransactionInput = true),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            vertical: AppUIConstants.spacingMd,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 18,
              color: AppUIConstants.success,
            ),
            const SizedBox(width: AppUIConstants.spacingSm),
            Text(
              'I\'ve already paid',
              style: AppUIConstants.bodyMd.copyWith(
                color: AppUIConstants.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionSection(SubscriptionState state) {
    return Container(
      padding: const EdgeInsets.all(AppUIConstants.spacingLg),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppUIConstants.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: AppUIConstants.success,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppUIConstants.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter Transaction ID',
                      style: AppUIConstants.bodyLg.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'From your UPI payment confirmation',
                      style: AppUIConstants.bodySm.copyWith(
                        color: AppUIConstants.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppUIConstants.spacingLg),
          TextField(
            controller: _transactionController,
            decoration: InputDecoration(
              hintText: 'e.g., 123456789012',
              hintStyle: AppUIConstants.bodyMd.copyWith(
                color: AppUIConstants.textTertiary,
              ),
              filled: true,
              fillColor: AppUIConstants.background,
              prefixIcon: Icon(Icons.tag, color: AppUIConstants.textSecondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppUIConstants.success,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
                ),
              ),
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
                      'Verify Payment',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: AppUIConstants.spacingMd),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _showTransactionInput = false),
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
    );
  }

  Widget _buildPaymentOptions() {
    final amount =
        widget.subscription?.finalAmount ??
        widget.finalAmountWithCoupon ??
        widget.priceResult?.finalAmount ??
        0;
    final razorpayAmount = amount + (amount * 0.025); // Add 2.5% charges

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Payment Options Header
        Text(
          'Choose Payment Method',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppUIConstants.textPrimary,
          ),
        ),
        const SizedBox(height: AppUIConstants.spacingMd),

        // Option 1: Manual UPI (Free)
        _buildPaymentOptionCard(
          title: 'Pay via UPI (Free)',
          subtitle: 'Copy UPI ID and pay manually\nVerification: Up to 1 hour',
          amount: amount,
          icon: Icons.account_balance_wallet_outlined,
          color: Colors.green,
          onTap: () => _showManualUpiOption(),
          badge: 'RECOMMENDED',
        ),

        const SizedBox(height: AppUIConstants.spacingMd),

        // Option 2: Razorpay (2.5% charges)
        _buildPaymentOptionCard(
          title: 'Pay via Razorpay (Instant)',
          subtitle: 'Credit/Debit Card, UPI, NetBanking\nInstant verification',
          amount: razorpayAmount,
          icon: Icons.payment,
          color: AppUIConstants.primary,
          onTap: () => _initiateRazorpay(),
          badge: '+ 2.5% charges',
          badgeColor: Colors.orange,
        ),

        const SizedBox(height: AppUIConstants.spacingMd),

        // Info message for Razorpay manual flow
        Container(
          padding: const EdgeInsets.all(AppUIConstants.spacingMd),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: AppUIConstants.spacingSm),
              Expanded(
                child: Text(
                  'If paying manually via PhonePe/other UPI apps: Copy UPI ID → Make payment → Tap "I have already paid" → Enter last min 5 digits of transaction reference ID',
                  style: AppUIConstants.bodySm.copyWith(
                    color: Colors.blue.shade900,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInAppPurchaseSection(SubscriptionState state) {
    final amount =
        widget.subscription?.finalAmount ??
        widget.finalAmountWithCoupon ??
        widget.priceResult?.finalAmount ??
        0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Complete with App Store',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppUIConstants.textPrimary,
          ),
        ),
        const SizedBox(height: AppUIConstants.spacingMd),
        Container(
          padding: const EdgeInsets.all(AppUIConstants.spacingLg),
          decoration: BoxDecoration(
            color: AppUIConstants.surface,
            borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
            border: Border.all(color: AppUIConstants.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppUIConstants.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppUIConstants.radiusMd,
                      ),
                    ),
                    child: Icon(
                      Icons.apple,
                      color: AppUIConstants.primary,
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
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.subscription?.durationInMonths ?? widget.durationInMonths ?? 0} month plan',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppUIConstants.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppUIConstants.primary,
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppUIConstants.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppUIConstants.radiusMd,
                      ),
                    ),
                  ),
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
        Container(
          padding: const EdgeInsets.all(AppUIConstants.spacingMd),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: AppUIConstants.spacingSm),
              Expanded(
                child: Text(
                  'On iPhone and iPad, subscription purchases are completed through Apple in-app purchase.',
                  style: AppUIConstants.bodySm.copyWith(
                    color: Colors.blue.shade900,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
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
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
        border: Border.all(color: AppUIConstants.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
          child: Padding(
            padding: const EdgeInsets.all(AppUIConstants.spacingLg),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusMd,
                    ),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: AppUIConstants.spacingMd),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: badgeColor ?? Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                badge,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppUIConstants.textSecondary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹${amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),

                // Arrow
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppUIConstants.textSecondary,
                ),
              ],
            ),
          ),
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
      'theme': {'color': '#2E7D32'},
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
                color: AppUIConstants.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.hourglass_top_rounded,
                color: AppUIConstants.primary,
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppUIConstants.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: AppUIConstants.spacingMd,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
                ),
              ),
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
