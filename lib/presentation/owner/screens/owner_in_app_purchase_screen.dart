import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/services/app_store_purchase_service.dart';
import '../../../domain/entities/library.dart';
import '../../../domain/entities/subscription_plan.dart';
import '../../core/app_ui_constants.dart';
import '../../core/screens/privacy_policy_screen.dart';
import '../../core/screens/terms_of_service_screen.dart';
import '../../core/widgets/premium_kit.dart';
import '../cubit/subscription_cubit.dart';

class OwnerInAppPurchaseScreen extends StatefulWidget {
  const OwnerInAppPurchaseScreen({super.key, required this.library});

  final Library library;

  @override
  State<OwnerInAppPurchaseScreen> createState() =>
      _OwnerInAppPurchaseScreenState();
}

class _OwnerInAppPurchaseScreenState extends State<OwnerInAppPurchaseScreen> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late final SubscriptionCubit _subscriptionCubit;
  StreamSubscription<AppStorePurchaseEvent>? _purchaseSubscription;
  Razorpay? _razorpay;

  bool get _isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Whether Apple In-App Purchase should be used for this session.
  ///
  /// Defaults to the Apple flow on iOS/iPad. When the
  /// `ios_owner_subscription_entry_enabled` Remote Config flag is true, iOS
  /// devices fall back to the default (Razorpay) subscription flow used on
  /// Android — so the same server-verified path handles all platforms.
  ///
  /// Resolved asynchronously in [initState] after Remote Config is fetched,
  /// so a value published while the app is running is honoured.
  bool _useAppleIap = false;

  int _selectedIndex = 0;
  bool _isStoreAvailable = false;
  bool _isLoadingProducts = true;
  bool _isPurchasing = false;
  String? _errorMessage;
  Map<String, ProductDetails> _productsById = {};

  final List<AppStorePlan> _plans = AppStorePlan.all;

  AppStorePlan get _selectedPlan => _plans[_selectedIndex];

  @override
  void initState() {
    super.initState();
    _subscriptionCubit = sl<SubscriptionCubit>();
    _resolveFlowAndInitialize();
  }

  /// Decides between Apple IAP and the default (Razorpay) flow, then wires up
  /// the chosen payment path.
  ///
  /// Android (and any non-iOS platform) always uses Razorpay — no Remote
  /// Config lookup. Only iOS consults the
  /// `ios_owner_subscription_entry_enabled` flag to optionally fall back to
  /// Razorpay.
  Future<void> _resolveFlowAndInitialize() async {
    if (_isIos) {
      final iosDefaultFlowEnabled = await _fetchIosDefaultFlowEnabled();
      if (!mounted) return;
      _useAppleIap = !iosDefaultFlowEnabled;
    } else {
      _useAppleIap = false;
    }

    if (_useAppleIap) {
      // Recording happens in the app-wide AppStorePurchaseService; this
      // screen only reflects progress.
      _purchaseSubscription = sl<AppStorePurchaseService>().events.listen(
        _onPurchaseEvent,
      );
      _loadProducts();
    } else {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleRazorpaySuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handleRazorpayError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
      setState(() {
        _isLoadingProducts = false;
        _isStoreAvailable = true;
      });
    }
  }

  /// Reads the `ios_owner_subscription_entry_enabled` flag, fetching the
  /// latest Remote Config first so a value published while the app is running
  /// is honoured. Falls back to the cached value (then `false`) on error.
  Future<bool> _fetchIosDefaultFlowEnabled() async {
    final remoteConfig = sl<FirebaseRemoteConfig>();
    try {
      await remoteConfig.fetchAndActivate();
    } catch (_) {
      // Ignore — fall back to whatever value is already cached.
    }
    try {
      return remoteConfig.getBool('ios_owner_subscription_entry_enabled');
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    _razorpay?.clear();
    _subscriptionCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        title: const Text('Choose Plan'),
        centerTitle: true,
        backgroundColor: AppUIConstants.background,
        foregroundColor: AppUIConstants.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppUIConstants.spacingXl),
                children: [
                  _buildHeader(),
                  const SizedBox(height: AppUIConstants.spacingMd),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    alignment: Alignment.topCenter,
                    child: _errorMessage != null
                        ? Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppUIConstants.spacingMd,
                            ),
                            child: _buildStatusMessage(
                              _errorMessage!,
                              isError: true,
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  if (_isLoadingProducts && _errorMessage == null)
                    ..._buildSkeletons()
                  else
                    ..._plans.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppUIConstants.spacingMd,
                        ),
                        child: _PlanCard(
                          plan: entry.value,
                          product: _productsById[entry.value.productId],
                          isSelected: entry.key == _selectedIndex,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedIndex = entry.key);
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: AppUIConstants.spacingSm),
                  _buildLegalLinks(),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSkeletons() {
    return [
      for (var i = 0; i < 4; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: AppUIConstants.spacingMd),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.3, end: 0.9),
            duration: Duration(milliseconds: 700 + i * 120),
            curve: Curves.easeInOut,
            builder: (_, v, _) => Opacity(
              opacity: v,
              child: Container(
                height: 96,
                decoration: BoxDecoration(
                  color: AppUIConstants.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
                ),
              ),
            ),
          ),
        ),
    ];
  }

  Widget _buildLegalLinks() {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppUIConstants.spacingSm,
      runSpacing: AppUIConstants.spacingXs,
      children: [
        Text(
          'Subscription renews automatically until cancelled.',
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: AppUIConstants.textSecondary,
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
          ),
          child: const Text('Terms'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
          ),
          child: const Text('Privacy'),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumCard(
          glow: AppUIConstants.primaryLight,
          padding: const EdgeInsets.all(AppUIConstants.spacingXl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppUIConstants.surfaceMuted,
                      borderRadius: BorderRadius.circular(
                        AppUIConstants.radiusSm,
                      ),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: AppUIConstants.primaryLight,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppUIConstants.spacingMd),
                  const Expanded(
                    child: Text(
                      'PG Sathi Pro',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppUIConstants.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppUIConstants.spacingSm),
              const Text(
                'Unlock unlimited beds and everything you need to run your PG',
                style: AppUIConstants.bodyMd,
              ),
              const SizedBox(height: AppUIConstants.spacingLg),
              _buildFeatureList(),
            ],
          ),
        ),
        const PremiumSectionHeader('Pick your plan'),
      ],
    );
  }

  Widget _buildFeatureList() {
    const features = [
      'Unlimited beds and tenants (free plan is capped at 7 beds)',
      'Tenant, room type and bed management',
      'UPI payment collection with auto-generated invoices',
      'Notices and reminders to tenants',
      'Revenue and occupancy analytics dashboard',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final feature in features)
          Padding(
            padding: const EdgeInsets.only(bottom: AppUIConstants.spacingSm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: AppUIConstants.success,
                ),
                const SizedBox(width: AppUIConstants.spacingSm),
                Expanded(
                  child: Text(
                    feature,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      color: AppUIConstants.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStatusMessage(String message, {bool isError = false}) {
    final color = isError ? AppUIConstants.error : AppUIConstants.primaryLight;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppUIConstants.spacingMd),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 13,
          height: 1.35,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final plan = _selectedPlan;

    final bool canPurchase;
    final String buttonLabel;

    if (_useAppleIap) {
      final product = _productsById[plan.productId];
      canPurchase =
          _isStoreAvailable &&
          !_isLoadingProducts &&
          !_isPurchasing &&
          product != null;
      buttonLabel = product == null && !_isLoadingProducts
          ? 'Product unavailable'
          : 'Subscribe with App Store - ₹${plan.price}';
    } else {
      canPurchase = _isStoreAvailable && !_isLoadingProducts && !_isPurchasing;
      final priceWithCharges =
          (plan.price * (1 + SubscriptionPlan.razorpayChargePercent / 100))
              .round();
      buttonLabel = _isLoadingProducts
          ? 'Loading...'
          : 'Pay ₹$priceWithCharges via Razorpay';
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppUIConstants.spacingXl,
        AppUIConstants.spacingMd,
        AppUIConstants.spacingXl,
        AppUIConstants.spacingLg + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        border: const Border(top: BorderSide(color: AppUIConstants.border)),
        boxShadow: [AppUIConstants.shadowLg],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    '${plan.title} plan',
                    key: ValueKey(plan.productId),
                    style: AppUIConstants.bodyMd,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  '₹${plan.price}',
                  key: ValueKey(plan.price),
                  style: AppUIConstants.headingMd,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppUIConstants.spacingMd),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: canPurchase
                  ? () {
                      HapticFeedback.mediumImpact();
                      _startPurchase();
                    }
                  : null,
              style: AppUIConstants.primaryButtonStyle.copyWith(
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.disabled)
                      ? AppUIConstants.disabled
                      : AppUIConstants.primaryLight,
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isPurchasing
                    ? const SizedBox(
                        key: ValueKey('busy'),
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        buttonLabel,
                        key: ValueKey(buttonLabel),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoadingProducts = true;
      _errorMessage = null;
    });

    final available = await _inAppPurchase.isAvailable();
    if (!mounted) return;

    if (!available) {
      setState(() {
        _isStoreAvailable = false;
        _isLoadingProducts = false;
        _errorMessage = 'App Store purchases are not available on this device.';
      });
      return;
    }

    final productIds = _plans.map((plan) => plan.productId).toSet();
    final response = await _inAppPurchase.queryProductDetails(productIds);
    if (!mounted) return;

    final productsById = {
      for (final product in response.productDetails) product.id: product,
    };

    setState(() {
      _isStoreAvailable = true;
      _isLoadingProducts = false;
      _productsById = productsById;
      _errorMessage = response.error?.message;
    });
  }

  Future<void> _startPurchase() async {
    if (_useAppleIap) {
      await _startIosPurchase();
    } else {
      await _startRazorpayPurchase();
    }
  }

  Future<void> _startIosPurchase() async {
    final product = _productsById[_selectedPlan.productId];
    if (product == null) {
      _showError('This App Store product is not available yet.');
      return;
    }

    setState(() {
      _isPurchasing = true;
      _errorMessage = null;
    });

    final purchaseParam = PurchaseParam(productDetails: product);
    final started = await _inAppPurchase.buyNonConsumable(
      purchaseParam: purchaseParam,
    );

    if (!started && mounted) {
      setState(() => _isPurchasing = false);
      _showError('Unable to start App Store purchase.');
    }
  }

  Future<void> _startRazorpayPurchase() async {
    setState(() {
      _isPurchasing = true;
      _errorMessage = null;
    });

    final plan = _selectedPlan;

    await _subscriptionCubit.initiatePayment(
      ownerId: widget.library.ownerId,
      libraryId: widget.library.id,
      seatCount: _seatCountForSubscription,
      durationInMonths: plan.months,
      planIdOverride: plan.productId,
      baseMonthlyPriceOverride: plan.price / plan.months,
      finalAmountOverride: plan.price.toDouble(),
      discountPercentOverride: 0,
      seatLimitOverride: 999999,
    );

    if (!mounted) return;

    if (_subscriptionCubit.state.createdSubscription == null) {
      setState(() => _isPurchasing = false);
      _showError(
        _subscriptionCubit.state.errorMessage ??
            'Failed to create subscription.',
      );
      return;
    }

    final amountWithCharges =
        plan.price * (1 + SubscriptionPlan.razorpayChargePercent / 100);

    final options = <String, dynamic>{
      'key': SubscriptionPlan.razorpayLiveKey,
      'amount': (amountWithCharges * 100).round(),
      'name': SubscriptionPlan.appName,
      'description': 'PG Sathi Pro - ${plan.title}',
      'prefill': {'contact': widget.library.ownerPhone ?? '', 'email': ''},
      'theme': {'color': '#0F8F8A'},
      'method': {'upi': true, 'card': true, 'netbanking': true, 'wallet': true},
    };

    try {
      _razorpay!.open(options);
    } catch (e) {
      if (mounted) setState(() => _isPurchasing = false);
      _showError('Failed to open payment: $e');
    }
  }

  void _handleRazorpaySuccess(PaymentSuccessResponse response) async {
    final createdSubscription = _subscriptionCubit.state.createdSubscription;
    if (createdSubscription == null || !mounted) return;

    await _subscriptionCubit.approveRazorpayPayment(
      subscriptionId: createdSubscription.id,
      razorpayPaymentId: response.paymentId ?? 'razorpay_success',
      ownerName: widget.library.ownerPhone ?? 'Owner',
      libraryName: widget.library.name,
      amount:
          _selectedPlan.price *
          (1 + SubscriptionPlan.razorpayChargePercent / 100),
      durationMonths: _selectedPlan.months,
    );

    if (!mounted) return;
    setState(() => _isPurchasing = false);

    if (_subscriptionCubit.state.isSuccess) {
      _showSuccessDialog(_selectedPlan);
    } else {
      _showError(
        _subscriptionCubit.state.errorMessage ??
            'Payment completed but subscription activation failed.',
      );
    }
  }

  void _handleRazorpayError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() => _isPurchasing = false);
    _showError(response.message ?? 'Payment failed. Please try again.');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    setState(() => _isPurchasing = false);
  }

  void _onPurchaseEvent(AppStorePurchaseEvent event) {
    if (!mounted) return;
    switch (event.type) {
      case AppStorePurchaseEventType.pending:
        setState(() => _isPurchasing = true);
      case AppStorePurchaseEventType.cancelled:
        setState(() => _isPurchasing = false);
      case AppStorePurchaseEventType.failed:
        setState(() => _isPurchasing = false);
        _showError(event.message ?? 'App Store purchase failed.');
      case AppStorePurchaseEventType.recorded:
        setState(() => _isPurchasing = false);
        if (event.plan != null) _showSuccessDialog(event.plan!);
    }
  }

  int get _seatCountForSubscription {
    return widget.library.totalSeatCapacity ??
        (widget.library.capacity > 0 ? widget.library.capacity : 1);
  }

  void _showSuccessDialog(AppStorePlan plan) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppUIConstants.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppUIConstants.success),
            SizedBox(width: 10),
            Text('Subscription Active'),
          ],
        ),
        content: Text(
          'Your ${plan.title} PG Sathi Pro subscription is now active.',
          style: AppUIConstants.bodyMd,
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop(true);
            },
            style: AppUIConstants.primaryButtonStyle,
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppUIConstants.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.product,
    required this.isSelected,
    required this.onTap,
  });

  final AppStorePlan plan;
  final ProductDetails? product;
  final bool isSelected;
  final VoidCallback onTap;

  bool get _recommended => plan.months == 12;

  @override
  Widget build(BuildContext context) {
    final monthlyEquivalent = (plan.price / plan.months).round();
    final accent = _recommended
        ? AppUIConstants.primaryLight
        : AppUIConstants.primaryLight;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(AppUIConstants.spacingLg),
          decoration: BoxDecoration(
            color: isSelected
                ? (_recommended
                      ? AppUIConstants.surfaceMuted
                      : AppUIConstants.primarySoft)
                : AppUIConstants.surface,
            borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
            border: Border.all(
              color: isSelected ? accent : AppUIConstants.border,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: accent.withValues(alpha: 0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                )
              else
                AppUIConstants.shadowSm,
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            plan.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppUIConstants.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppUIConstants.spacingSm),
                        _Badge(label: plan.badge, recommended: _recommended),
                      ],
                    ),
                    const SizedBox(height: AppUIConstants.spacingMd),
                    Text(
                      '₹${plan.price}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: isSelected ? accent : AppUIConstants.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppUIConstants.spacingXs),
                    Text(
                      plan.months == 1
                          ? 'per month'
                          : '₹$monthlyEquivalent/month billed every ${plan.months} months',
                      style: AppUIConstants.bodySm,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppUIConstants.spacingMd),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  key: ValueKey(isSelected),
                  color: isSelected ? accent : AppUIConstants.textTertiary,
                  size: 26,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.recommended});

  final String label;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    final color = recommended
        ? AppUIConstants.primaryLight
        : AppUIConstants.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: recommended ? color : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (recommended) ...[
            const Icon(Icons.star_rounded, size: 12, color: Colors.white),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: recommended ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }
}
