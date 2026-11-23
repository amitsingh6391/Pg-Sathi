import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:unicons/unicons.dart';

import '../../../domain/entities/subscription_plan.dart';
import '../../../domain/entities/whatsapp_credits.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/whatsapp_credits_cubit.dart';

class WhatsAppCreditsScreen extends StatefulWidget {
  const WhatsAppCreditsScreen({
    super.key,
    required this.ownerId,
    required this.ownerPhone,
  });

  final String ownerId;
  final String? ownerPhone;

  @override
  State<WhatsAppCreditsScreen> createState() => _WhatsAppCreditsScreenState();
}

class _WhatsAppCreditsScreenState extends State<WhatsAppCreditsScreen> {
  Razorpay? _razorpay;
  WhatsAppCreditPack? _pendingPack;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _razorpay = Razorpay()
        ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess)
        ..on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError)
        ..on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
    }
    context.read<WhatsAppCreditsCubit>().load(widget.ownerId);
  }

  @override
  void dispose() {
    _razorpay?.clear();
    super.dispose();
  }

  // ── Payment ───────────────────────────────────────────────────────────────

  double _payableWithCharges(WhatsAppCreditPack pack) =>
      pack.price * (1 + SubscriptionPlan.razorpayChargePercent / 100);

  void _buyPack(WhatsAppCreditPack pack) {
    if (kIsWeb) {
      _snack('Please use the mobile app to make payments', isError: true);
      return;
    }
    _pendingPack = pack;
    final amountInPaise = (_payableWithCharges(pack) * 100).round();

    // Only prefill a contact when we have a valid 10-digit Indian mobile number.
    final digits = (widget.ownerPhone ?? '').replaceAll(RegExp(r'\D'), '');
    final contact = digits.length >= 10
        ? '+91${digits.substring(digits.length - 10)}'
        : null;

    final options = <String, dynamic>{
      // Debug builds use the test key so the flow can be verified without
      // real money; release builds always use the live key.
      'key':SubscriptionPlan.razorpayLiveKey,
      'amount': amountInPaise,
      'currency': 'INR',
      'name': SubscriptionPlan.appName,
      'description': 'WhatsApp Credits - ${pack.credits} messages',
      if (contact != null) 'prefill': {'contact': contact},
      'theme': {'color': '#1E3A5F'},
    };
    debugPrint('[WhatsAppCredits] Opening Razorpay with $options');
    try {
      _razorpay!.open(options);
    } catch (e) {
      _snack('Failed to open Razorpay: $e', isError: true);
    }
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) {
    final pack = _pendingPack;
    if (pack == null) return;
    context.read<WhatsAppCreditsCubit>().creditPurchasedPack(
          pack: pack,
          amountPaid: _payableWithCharges(pack),
          paymentId: response.paymentId,
        );
    _pendingPack = null;
  }

  void _onPaymentError(PaymentFailureResponse response) {
    _pendingPack = null;
    debugPrint('[WhatsAppCredits] Razorpay error code=${response.code} '
        'message=${response.message} error=${response.error}');
    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      _snack('Payment cancelled', isError: true);
      return;
    }
    _snack(
        'Payment failed (code ${response.code}): '
        '${response.message ?? 'Unknown error'}',
        isError: true);
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    _snack('External wallet selected: ${response.walletName ?? ''}');
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFDC2626) : AppUIConstants.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        backgroundColor: AppUIConstants.surface,
        elevation: 0,
        title: const Text(
          'WhatsApp Credits',
          style: TextStyle(
            color: AppUIConstants.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: AppUIConstants.textPrimary),
      ),
      body: BlocConsumer<WhatsAppCreditsCubit, WhatsAppCreditsState>(
        listenWhen: (p, c) => p.status != c.status,
        listener: (context, state) {
          if (state.status == WhatsAppCreditsStatus.purchaseSuccess) {
            HapticFeedback.heavyImpact();
            _snack('${state.lastPurchasedCredits} credits added 🎉');
          } else if (state.status == WhatsAppCreditsStatus.error &&
              state.errorMessage != null) {
            _snack(state.errorMessage!, isError: true);
          }
        },
        builder: (context, state) {
          if (state.isLoading && state.credits == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppUIConstants.primary),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _BalanceCard(available: state.availableCredits),
              const SizedBox(height: 20),
              const Text(
                'Buy Credits',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppUIConstants.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '1 credit = 1 WhatsApp message (notice, invoice or reminder)',
                style: TextStyle(
                  fontSize: 12,
                  color: AppUIConstants.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              ...WhatsAppCreditPack.packs.map(
                (pack) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PackCard(
                    pack: pack,
                    enabled: !state.isPurchasing,
                    onBuy: () => _buyPack(pack),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const _InfoNote(),
            ],
          );
        },
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.available});

  final int available;

  @override
  Widget build(BuildContext context) {
    final isEmpty = available <= 0;
    const brand = Color(0xFF25D366);
    final numberColor =
        isEmpty ? const Color(0xFFDC2626) : AppUIConstants.textPrimary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppUIConstants.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: brand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(UniconsLine.whatsapp,
                    color: brand, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WhatsApp Credits',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppUIConstants.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Wallet balance',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppUIConstants.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$available',
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  color: numberColor,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  available == 1 ? 'credit' : 'credits',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppUIConstants.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: (isEmpty ? const Color(0xFFDC2626) : brand)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  isEmpty
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 16,
                  color: isEmpty ? const Color(0xFFDC2626) : brand,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isEmpty
                        ? 'WhatsApp notices, invoices & reminders paused — buy credits to resume.'
                        : 'WhatsApp notices, invoices & reminders are active.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                      color: isEmpty
                          ? const Color(0xFFDC2626)
                          : AppUIConstants.textSecondary,
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

class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.pack,
    required this.enabled,
    required this.onBuy,
  });

  final WhatsAppCreditPack pack;
  final bool enabled;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${pack.credits} credits',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppUIConstants.textPrimary,
                      ),
                    ),
                    if (pack.label != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppUIConstants.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          pack.label!,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppUIConstants.success,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '≈ ₹${pack.perMessagePaise.toStringAsFixed(0) == '0' ? pack.perMessagePaise.toStringAsFixed(2) : pack.perMessagePaise.toStringAsFixed(1)} paise/message',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppUIConstants.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: enabled ? onBuy : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppUIConstants.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              '₹${pack.price.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppUIConstants.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppUIConstants.primary.withValues(alpha: 0.1)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 16, color: AppUIConstants.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'You get ${WhatsAppCredits.freeCredits} free credits. After that, each WhatsApp notice (per resident), automated invoice and expiry reminder uses 1 credit. Manual reminders are always free.',
              style: TextStyle(
                fontSize: 12,
                color: AppUIConstants.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
