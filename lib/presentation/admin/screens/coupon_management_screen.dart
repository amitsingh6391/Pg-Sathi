import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/coupon.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';
import '../cubit/admin_cubit.dart';
import '../widgets/promo_ticket.dart';

/// Screen for managing coupon codes.
class CouponManagementScreen extends StatelessWidget {
  const CouponManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        title: const Text('Coupons'),
        backgroundColor: AppUIConstants.surface,
        foregroundColor: AppUIConstants.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateCouponDialog(context),
        backgroundColor: AppUIConstants.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New coupon'),
      ),
      body: BlocBuilder<AdminCubit, AdminState>(
        builder: (context, state) {
          Widget child;
          if (state.isLoading) {
            child = const SkeletonList(
              key: ValueKey('skeleton'),
              itemHeight: 112,
            );
          } else if (state.coupons.isEmpty) {
            child = AdminEmptyState(
              key: const ValueKey('empty'),
              icon: Icons.discount_outlined,
              title: 'No coupons yet',
              message: 'Create a coupon code to offer subscription discounts.',
              actionLabel: 'Create first coupon',
              onAction: () => _showCreateCouponDialog(context),
            );
          } else {
            final now = DateTime.now();
            final live = state.coupons.where((c) => c.isValid(now)).length;
            final redeemed = state.coupons.fold<int>(
              0,
              (sum, c) => sum + c.currentUses,
            );
            child = ListView(
              key: const ValueKey('list'),
              padding: const EdgeInsets.fromLTRB(
                AppUIConstants.spacingLg,
                AppUIConstants.spacingLg,
                AppUIConstants.spacingLg,
                96,
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: PremiumStatTile(
                        icon: Icons.discount_rounded,
                        value: '${state.coupons.length}',
                        label: 'Total',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PremiumStatTile(
                        icon: Icons.bolt_rounded,
                        value: '$live',
                        label: 'Live',
                        color: AppUIConstants.primaryLight,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PremiumStatTile(
                        icon: Icons.redeem_rounded,
                        value: '$redeemed',
                        label: 'Redeemed',
                        color: AppUIConstants.primaryLight,
                      ),
                    ),
                  ],
                ),
                const PremiumSectionHeader('All coupons'),
                for (final c in state.coupons) _CouponTicket(coupon: c),
              ],
            );
          }
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: child,
          );
        },
      ),
    );
  }

  void _showCreateCouponDialog(BuildContext context) {
    final cubit = context.read<AdminCubit>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppUIConstants.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppUIConstants.radiusXl),
        ),
      ),
      builder: (sheetContext) => _CouponForm(
        onSubmit:
            ({
              required String code,
              required double discountPercent,
              String? description,
              int? maxUses,
            }) {
              cubit.addCoupon(
                code: code,
                discountPercent: discountPercent,
                description: description,
                maxUses: maxUses,
              );
              Navigator.of(sheetContext).pop();
            },
      ),
    );
  }
}

String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

class _CouponTicket extends StatelessWidget {
  const _CouponTicket({required this.coupon});

  final Coupon coupon;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isValid = coupon.isValid(now);
    final exhausted =
        coupon.maxUses != null && coupon.currentUses >= coupon.maxUses!;
    final accent = isValid
        ? AppUIConstants.primaryLight
        : AppUIConstants.textTertiary;
    final countdown = expiryCountdown(
      coupon.validUntil,
      start: coupon.validFrom,
    );
    final usage = coupon.maxUses == null || coupon.maxUses == 0
        ? null
        : (coupon.currentUses / coupon.maxUses!).clamp(0.0, 1.0).toDouble();

    String status;
    Color statusColor;
    if (isValid) {
      status = 'Live';
      statusColor = AppUIConstants.success;
    } else if (exhausted) {
      status = 'Used up';
      statusColor = AppUIConstants.warning;
    } else if (coupon.validUntil != null && now.isAfter(coupon.validUntil!)) {
      status = 'Expired';
      statusColor = AppUIConstants.error;
    } else {
      status = 'Inactive';
      statusColor = AppUIConstants.textTertiary;
    }

    return TicketCard(
      accent: accent,
      stub: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            coupon.discountPercent.toStringAsFixed(0),
            style: TextStyle(
              color: accent,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          Text(
            '% OFF',
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: coupon.code));
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text('Copied ${coupon.code}'),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            coupon.code,
                            overflow: TextOverflow.ellipsis,
                            style: AppUIConstants.headingSm.copyWith(
                              fontFamily: 'monospace',
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.copy_rounded,
                          size: 14,
                          color: AppUIConstants.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
                PremiumStatusPill(status, color: statusColor),
              ],
            ),
            if (coupon.description != null &&
                coupon.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                coupon.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppUIConstants.bodySm,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.redeem_rounded,
                  size: 14,
                  color: AppUIConstants.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  coupon.maxUses != null
                      ? '${coupon.currentUses}/${coupon.maxUses} used'
                      : '${coupon.currentUses} used · unlimited',
                  style: AppUIConstants.bodySm,
                ),
                const Spacer(),
                Icon(Icons.timer_outlined, size: 14, color: countdown.color),
                const SizedBox(width: 4),
                Text(
                  countdown.label,
                  style: AppUIConstants.bodySm.copyWith(
                    color: countdown.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (usage != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: usage),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 5,
                    backgroundColor: AppUIConstants.surfaceMuted,
                    valueColor: AlwaysStoppedAnimation(
                      v >= 1
                          ? AppUIConstants.warning
                          : AppUIConstants.primaryLight,
                    ),
                  ),
                ),
              ),
            ],
            if (coupon.validUntil != null) ...[
              const SizedBox(height: 6),
              Text(
                'Valid until ${_formatDate(coupon.validUntil!)}',
                style: AppUIConstants.caption,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

typedef _CouponSubmit =
    void Function({
      required String code,
      required double discountPercent,
      String? description,
      int? maxUses,
    });

class _CouponForm extends StatefulWidget {
  const _CouponForm({required this.onSubmit});

  final _CouponSubmit onSubmit;

  @override
  State<_CouponForm> createState() => _CouponFormState();
}

class _CouponFormState extends State<_CouponForm> {
  final _code = TextEditingController();
  final _discount = TextEditingController();
  final _description = TextEditingController();
  final _maxUses = TextEditingController();
  bool _limitUses = false;
  bool _showErrors = false;

  @override
  void dispose() {
    _code.dispose();
    _discount.dispose();
    _description.dispose();
    _maxUses.dispose();
    super.dispose();
  }

  InputDecoration _decoration(
    String label, {
    String? hint,
    String? error,
    String? suffix,
  }) {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppUIConstants.radiusSm + 2),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: error,
      suffixText: suffix,
      filled: true,
      fillColor: AppUIConstants.surfaceMuted,
      labelStyle: const TextStyle(color: AppUIConstants.textSecondary),
      hintStyle: const TextStyle(color: AppUIConstants.textTertiary),
      border: b(AppUIConstants.border),
      enabledBorder: b(AppUIConstants.border),
      focusedBorder: b(AppUIConstants.primaryLight, 1.5),
      errorBorder: b(AppUIConstants.error),
      focusedErrorBorder: b(AppUIConstants.error, 1.5),
    );
  }

  Widget _card(String title, IconData icon, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppUIConstants.spacingMd),
      child: PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppUIConstants.primaryLight),
                const SizedBox(width: 8),
                Text(title, style: AppUIConstants.headingSm),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  void _submit() {
    final code = _code.text.trim();
    final discount = double.tryParse(_discount.text) ?? 0;
    if (code.isEmpty || discount <= 0) {
      setState(() => _showErrors = true);
      return;
    }
    widget.onSubmit(
      code: code,
      discountPercent: discount,
      description: _description.text.isEmpty ? null : _description.text,
      maxUses: _limitUses ? int.tryParse(_maxUses.text) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            decoration: BoxDecoration(
              color: AppUIConstants.disabled,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 8, 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Create coupon', style: AppUIConstants.headingMd),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppUIConstants.textSecondary,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: ListenableBuilder(
                listenable: Listenable.merge([_code, _discount, _description]),
                builder: (context, _) {
                  final codeErr = _showErrors && _code.text.trim().isEmpty
                      ? 'Enter a code'
                      : null;
                  final discErr =
                      _showErrors && (double.tryParse(_discount.text) ?? 0) <= 0
                      ? 'Enter a discount above 0'
                      : null;
                  final pct = double.tryParse(_discount.text) ?? 0;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _previewTicket(pct),
                      const SizedBox(height: AppUIConstants.spacingMd),
                      _card('Code & discount', Icons.discount_rounded, [
                        TextField(
                          controller: _code,
                          textCapitalization: TextCapitalization.characters,
                          style: AppUIConstants.bodyLg,
                          decoration: _decoration(
                            'Coupon code',
                            hint: 'e.g., SAVE20',
                            error: codeErr,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _discount,
                          keyboardType: TextInputType.number,
                          style: AppUIConstants.bodyLg,
                          decoration: _decoration(
                            'Discount',
                            hint: 'e.g., 20',
                            error: discErr,
                            suffix: '%',
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _description,
                          maxLines: 2,
                          style: AppUIConstants.bodyLg,
                          decoration: _decoration('Description (optional)'),
                        ),
                      ]),
                      _card('Usage limit', Icons.redeem_rounded, [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _limitUses,
                          onChanged: (v) => setState(() => _limitUses = v),
                          activeThumbColor: AppUIConstants.primaryLight,
                          title: const Text(
                            'Limit total uses',
                            style: AppUIConstants.bodyLg,
                          ),
                          subtitle: Text(
                            _limitUses
                                ? 'Coupon stops working after the limit'
                                : 'Unlimited redemptions',
                            style: AppUIConstants.bodySm,
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          child: _limitUses
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: TextField(
                                    controller: _maxUses,
                                    keyboardType: TextInputType.number,
                                    style: AppUIConstants.bodyLg,
                                    decoration: _decoration(
                                      'Max uses',
                                      hint: 'e.g., 100',
                                    ),
                                  ),
                                )
                              : const SizedBox(width: double.infinity),
                        ),
                      ]),
                    ],
                  );
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: AppUIConstants.surface,
              border: Border(top: BorderSide(color: AppUIConstants.border)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _submit,
                      style: AppUIConstants.primaryButtonStyle,
                      icon: const Icon(Icons.check_rounded, size: 20),
                      label: const Text(
                        'Create coupon',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewTicket(double pct) {
    final code = _code.text.trim().isEmpty ? 'YOURCODE' : _code.text.trim();
    final desc = _description.text.trim();
    return TicketCard(
      accent: AppUIConstants.primaryLight,
      stubWidth: 92,
      stub: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            pct > 0 ? pct.toStringAsFixed(0) : '--',
            style: const TextStyle(
              color: AppUIConstants.primaryLight,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const Text(
            '% OFF',
            style: TextStyle(
              color: AppUIConstants.primaryLight,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('PREVIEW', style: AppUIConstants.caption),
            const SizedBox(height: 4),
            Text(
              code,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppUIConstants.headingMd.copyWith(
                fontFamily: 'monospace',
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc.isEmpty ? 'Subscription discount' : desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppUIConstants.bodySm,
            ),
          ],
        ),
      ),
    );
  }
}
