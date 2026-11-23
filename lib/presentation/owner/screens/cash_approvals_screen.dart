import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/payment.dart';
import '../../../domain/usecases/get_pending_cash_payments.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';
import '../cubit/cash_approval_cubit.dart';
import '../cubit/cash_approval_state.dart';

// ===========================================================================
// Shared approval kit (also used by the UPI and combined approvals screens)
// ===========================================================================

/// Formats a rupee amount with Indian digit grouping.
String approvalRupees(num amount) =>
    '₹${NumberFormat.decimalPattern('en_IN').format(amount.round())}';

/// Hero band with back button, title, pending count and total amount.
class ApprovalsHero extends StatelessWidget {
  const ApprovalsHero({
    super.key,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.total,
    required this.onBack,
    this.bottom,
  });

  final String title;
  final String subtitle;
  final int count;
  final double total;
  final VoidCallback onBack;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return PremiumHero(
      padding: const EdgeInsets.fromLTRB(8, 4, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                color: AppUIConstants.textPrimary,
                onPressed: onBack,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppUIConstants.headingMd),
                    Text(
                      subtitle,
                      style: AppUIConstants.caption.copyWith(
                        color: AppUIConstants.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AWAITING APPROVAL',
                        style: AppUIConstants.caption.copyWith(
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                          color: AppUIConstants.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: total),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, _) => Text(
                          approvalRupees(v),
                          style: const TextStyle(
                            fontSize: 34,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            color: AppUIConstants.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppUIConstants.surfaceMuted,
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusFull,
                    ),
                    border: Border.all(color: AppUIConstants.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.hourglass_top_rounded,
                        size: 14,
                        color: AppUIConstants.primaryLight,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$count pending',
                        style: const TextStyle(
                          color: AppUIConstants.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (bottom != null) ...[
            const SizedBox(height: 16),
            Padding(padding: const EdgeInsets.only(left: 12), child: bottom),
          ],
        ],
      ),
    );
  }
}

/// Pulsing skeleton cards shown while pending payments load.
class ApprovalSkeletonList extends StatefulWidget {
  const ApprovalSkeletonList({super.key});

  @override
  State<ApprovalSkeletonList> createState() => _ApprovalSkeletonListState();
}

class _ApprovalSkeletonListState extends State<ApprovalSkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _bar(double w, double h) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: AppUIConstants.surfaceMuted,
      borderRadius: BorderRadius.circular(6),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1).animate(_c),
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppUIConstants.spacingLg),
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              margin: const EdgeInsets.only(bottom: AppUIConstants.spacingMd),
              padding: const EdgeInsets.all(AppUIConstants.spacingLg),
              decoration: AppUIConstants.cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: AppUIConstants.surfaceMuted,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _bar(120, 14),
                            const SizedBox(height: 8),
                            _bar(80, 10),
                          ],
                        ),
                      ),
                      _bar(70, 24),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _bar(double.infinity, 10),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: _bar(double.infinity, 42)),
                      const SizedBox(width: 12),
                      Expanded(child: _bar(double.infinity, 42)),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Empty state with icon and call to action.
class ApprovalEmptyState extends StatelessWidget {
  const ApprovalEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.85, end: 1),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutBack,
          builder: (_, v, child) => Transform.scale(
            scale: v,
            child: Opacity(opacity: v.clamp(0, 1), child: child),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: AppUIConstants.primarySoft,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppUIConstants.primaryLight.withValues(
                        alpha: 0.18,
                      ),
                      blurRadius: 32,
                    ),
                  ],
                ),
                child: Icon(icon, size: 44, color: AppUIConstants.primaryLight),
              ),
              const SizedBox(height: 24),
              Text(title, style: AppUIConstants.headingMd),
              const SizedBox(height: 8),
              Text(
                message,
                style: AppUIConstants.bodySm,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(actionLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppUIConstants.primaryLight,
                  side: const BorderSide(color: AppUIConstants.primary),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusFull,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _DateFilter { all, today, earlier }

bool _isToday(DateTime? d) {
  if (d == null) return false;
  final n = DateTime.now();
  return d.year == n.year && d.month == n.month && d.day == n.day;
}

String _dayLabel(DateTime? d) {
  if (d == null) return 'Undated';
  if (_isToday(d)) return 'Today';
  final y = DateTime.now().subtract(const Duration(days: 1));
  if (d.year == y.year && d.month == y.month && d.day == y.day) {
    return 'Yesterday';
  }
  return DateFormat('dd MMM yyyy').format(d);
}

/// Filter chips + date-grouped list of [ApprovalCard]s with pull to refresh.
class ApprovalList extends StatefulWidget {
  const ApprovalList({
    super.key,
    required this.payments,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
    required this.onRefresh,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final List<PendingCashPaymentInfo> payments;
  final bool Function(String paymentId) isProcessing;
  final void Function(PendingCashPaymentInfo info) onApprove;
  final void Function(PendingCashPaymentInfo info) onReject;
  final Future<void> Function() onRefresh;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;

  @override
  State<ApprovalList> createState() => _ApprovalListState();
}

class _ApprovalListState extends State<ApprovalList> {
  _DateFilter _filter = _DateFilter.all;

  @override
  Widget build(BuildContext context) {
    final all = widget.payments;
    if (all.isEmpty) {
      return RefreshIndicator(
        color: AppUIConstants.primaryLight,
        backgroundColor: AppUIConstants.surface,
        onRefresh: widget.onRefresh,
        child: LayoutBuilder(
          builder: (context, c) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: c.maxHeight,
                child: ApprovalEmptyState(
                  icon: widget.emptyIcon,
                  title: widget.emptyTitle,
                  message: widget.emptyMessage,
                  actionLabel: 'Refresh',
                  onAction: widget.onRefresh,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final todayCount = all.where((p) => _isToday(p.payment.createdAt)).length;
    final counts = {
      _DateFilter.all: all.length,
      _DateFilter.today: todayCount,
      _DateFilter.earlier: all.length - todayCount,
    };
    final filtered = all.where((p) {
      switch (_filter) {
        case _DateFilter.all:
          return true;
        case _DateFilter.today:
          return _isToday(p.payment.createdAt);
        case _DateFilter.earlier:
          return !_isToday(p.payment.createdAt);
      }
    }).toList();

    final groups = <String, List<PendingCashPaymentInfo>>{};
    for (final p in filtered) {
      groups.putIfAbsent(_dayLabel(p.payment.createdAt), () => []).add(p);
    }

    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            children: [
              for (final f in _DateFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label: switch (f) {
                      _DateFilter.all => 'All',
                      _DateFilter.today => 'Today',
                      _DateFilter.earlier => 'Earlier',
                    },
                    count: counts[f]!,
                    selected: _filter == f,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _filter = f);
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppUIConstants.primaryLight,
            backgroundColor: AppUIConstants.surface,
            onRefresh: widget.onRefresh,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: filtered.isEmpty
                  ? ListView(
                      key: ValueKey('empty-$_filter'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(48),
                      children: [
                        Center(
                          child: Text(
                            'Nothing here for this filter.',
                            style: AppUIConstants.bodySm,
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      key: ValueKey('list-$_filter'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      children: [
                        for (final e in groups.entries) ...[
                          PremiumSectionHeader(e.key),
                          for (final info in e.value)
                            Padding(
                              key: ValueKey(info.payment.id),
                              padding: const EdgeInsets.only(
                                bottom: AppUIConstants.spacingMd,
                              ),
                              child: ApprovalCard(
                                info: info,
                                isProcessing: widget.isProcessing(
                                  info.payment.id,
                                ),
                                onApprove: () => widget.onApprove(info),
                                onReject: () => widget.onReject(info),
                              ),
                            ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppUIConstants.primarySoft : AppUIConstants.surface,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
          border: Border.all(
            color: selected
                ? AppUIConstants.primaryLight
                : AppUIConstants.border,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? AppUIConstants.primaryLight
                    : AppUIConstants.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected
                    ? AppUIConstants.textPrimary
                    : AppUIConstants.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fintech style approval card: big amount, status timeline, actions.
class ApprovalCard extends StatelessWidget {
  const ApprovalCard({
    super.key,
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
    final isUpi = info.payment.mode == PaymentMode.upi;
    final modeColor = isUpi
        ? AppUIConstants.primaryLight
        : AppUIConstants.warning;
    final created = info.payment.createdAt;
    final name = info.studentName;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: isProcessing ? 0.6 : 1,
      child: PremiumCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: modeColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: modeColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: AppUIConstants.headingSm,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(info.studentPhone, style: AppUIConstants.caption),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        approvalRupees(info.payment.amount),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppUIConstants.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      PremiumStatusPill(
                        isUpi ? 'UPI' : 'CASH',
                        color: modeColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(Icons.bed_outlined, 'Bed ${info.seatNumber}'),
                  _InfoChip(Icons.schedule_outlined, info.slot),
                  if (info.isPartialPaymentCompletion)
                    const _InfoChip(
                      Icons.pie_chart_outline_rounded,
                      'Balance payment',
                      color: AppUIConstants.warning,
                    ),
                  if (info.payment.utrNumber != null)
                    _InfoChip(
                      Icons.receipt_long_outlined,
                      'UTR ${info.payment.utrNumber}',
                      mono: true,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Clipboard.setData(
                          ClipboardData(text: info.payment.utrNumber!),
                        );
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(content: Text('UTR copied')),
                          );
                      },
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: _Timeline(created: created),
            ),
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppUIConstants.surfaceMuted,
                border: Border(top: BorderSide(color: AppUIConstants.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isProcessing
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              onReject();
                            },
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppUIConstants.error,
                        side: BorderSide(
                          color: AppUIConstants.error.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppUIConstants.radiusMd,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: isProcessing
                          ? null
                          : () {
                              HapticFeedback.mediumImpact();
                              onApprove();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppUIConstants.success,
                        foregroundColor: AppUIConstants.background,
                        disabledBackgroundColor: AppUIConstants.disabled,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppUIConstants.radiusMd,
                          ),
                        ),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: isProcessing
                            ? const SizedBox(
                                key: ValueKey('busy'),
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppUIConstants.textPrimary,
                                ),
                              )
                            : const Row(
                                key: ValueKey('idle'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_rounded, size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    'Approve',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(
    this.icon,
    this.text, {
    this.color,
    this.mono = false,
    this.onTap,
  });

  final IconData icon;
  final String text;
  final Color? color;
  final bool mono;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppUIConstants.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppUIConstants.surfaceMuted,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: c),
            const SizedBox(width: 6),
            Text(
              text,
              style: AppUIConstants.caption.copyWith(
                color: color ?? AppUIConstants.textPrimary,
                fontWeight: FontWeight.w600,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.copy_rounded,
                size: 12,
                color: AppUIConstants.textTertiary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Initiated -> Awaiting you -> Stay active.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.created});

  final DateTime? created;

  @override
  Widget build(BuildContext context) {
    final time = created != null
        ? DateFormat('dd MMM, hh:mm a').format(created!)
        : '-';
    Widget dot(Color c, {bool filled = true}) => Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? c : Colors.transparent,
        border: Border.all(color: c, width: 2),
      ),
    );
    Widget line(Color c) => Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: c,
      ),
    );
    Widget label(String t, {Color? color}) => Text(
      t,
      style: AppUIConstants.caption.copyWith(
        fontSize: 11,
        color: color ?? AppUIConstants.textTertiary,
      ),
    );
    return Column(
      children: [
        Row(
          children: [
            dot(AppUIConstants.primaryLight),
            line(AppUIConstants.primaryLight),
            dot(AppUIConstants.warning),
            line(AppUIConstants.border),
            dot(AppUIConstants.disabled, filled: false),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            label(time, color: AppUIConstants.textSecondary),
            label('Awaiting you', color: AppUIConstants.warning),
            label('Stay active'),
          ],
        ),
      ],
    );
  }
}

/// Confirmation bottom sheet. Resolves true when the owner confirms.
Future<bool> showApprovalConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required Color color,
  required IconData icon,
  required String personName,
  required double amount,
  Widget? extra,
}) async {
  HapticFeedback.selectionClick();
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppUIConstants.border)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppUIConstants.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppUIConstants.surfaceMuted,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: AppUIConstants.textSecondary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Text(title, style: AppUIConstants.headingMd)),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppUIConstants.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(personName, style: AppUIConstants.bodySm),
                    const SizedBox(height: 4),
                    Text(
                      approvalRupees(amount),
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              if (extra != null) ...[const SizedBox(height: 12), extra],
              const SizedBox(height: 12),
              Text(message, style: AppUIConstants.bodySm),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppUIConstants.textSecondary,
                        side: const BorderSide(color: AppUIConstants.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppUIConstants.radiusMd,
                          ),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Navigator.of(ctx).pop(true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: AppUIConstants.background,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppUIConstants.radiusMd,
                          ),
                        ),
                      ),
                      child: Text(
                        confirmLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}

/// Floating dark snackbar used by approval screens.
void showApprovalSnack(
  BuildContext context,
  String text,
  Color color,
  IconData icon,
) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppUIConstants.surfaceMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          side: BorderSide(color: color.withValues(alpha: 0.5)),
        ),
        content: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: AppUIConstants.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
}

double approvalTotal(List<PendingCashPaymentInfo> list) =>
    list.fold<double>(0, (s, p) => s + p.payment.amount);

// ===========================================================================
// Cash approvals screen
// ===========================================================================

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
        body: BlocConsumer<CashApprovalCubit, CashApprovalState>(
          listener: (context, state) {
            if (state.isApproved) {
              _hasChanges = true;
              showApprovalSnack(
                context,
                'Cash payment approved successfully',
                AppUIConstants.success,
                Icons.check_circle_rounded,
              );
              context.read<CashApprovalCubit>().resetToLoaded();
            } else if (state.isRejected) {
              _hasChanges = true;
              showApprovalSnack(
                context,
                'Cash payment rejected',
                AppUIConstants.warning,
                Icons.cancel_rounded,
              );
              context.read<CashApprovalCubit>().resetToLoaded();
            } else if (state.isError && state.errorMessage != null) {
              showApprovalSnack(
                context,
                state.errorMessage!,
                AppUIConstants.error,
                Icons.error_rounded,
              );
            }
          },
          builder: (context, state) {
            // Filter only cash payments
            final cashPayments = state.pendingPayments
                .where((p) => p.payment.mode != PaymentMode.upi)
                .toList();

            return Column(
              children: [
                ApprovalsHero(
                  title: 'Cash Approvals',
                  subtitle: widget.libraryName,
                  count: state.isLoading ? 0 : cashPayments.length,
                  total: state.isLoading ? 0 : approvalTotal(cashPayments),
                  onBack: () => Navigator.of(context).pop(_hasChanges),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: state.isLoading
                        ? const ApprovalSkeletonList(key: ValueKey('skeleton'))
                        : ApprovalList(
                            key: const ValueKey('list'),
                            payments: cashPayments,
                            isProcessing: state.isProcessingPayment,
                            onApprove: _handleApprove,
                            onReject: _handleReject,
                            onRefresh: () async => context
                                .read<CashApprovalCubit>()
                                .loadPendingPayments(widget.libraryId),
                            emptyIcon: Icons.verified_rounded,
                            emptyTitle: 'All caught up!',
                            emptyMessage:
                                'No pending cash payments\nawaiting your approval.',
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleApprove(PendingCashPaymentInfo info) async {
    final isPartialCompletion = info.isPartialPaymentCompletion;
    final membership = info.membership;
    final breakdown = membership?.paymentBreakdown;
    final willCompletePayment =
        breakdown != null &&
        (breakdown.amountPaid + info.payment.amount >= breakdown.totalAmount);

    Widget? extra;
    if (isPartialCompletion && breakdown != null) {
      Widget row(String l, String v, {Color? c}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l, style: AppUIConstants.caption),
            Text(
              v,
              style: AppUIConstants.bodySm.copyWith(
                color: c ?? AppUIConstants.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
      extra = Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          border: Border.all(color: AppUIConstants.border),
        ),
        child: Column(
          children: [
            row('Already paid', approvalRupees(breakdown.amountPaid)),
            row('This payment', approvalRupees(info.payment.amount)),
            if (willCompletePayment)
              row(
                'Total after (full payment)',
                approvalRupees(breakdown.totalAmount),
                c: AppUIConstants.success,
              )
            else
              row(
                'Remaining after',
                approvalRupees(breakdown.amountRemaining - info.payment.amount),
              ),
          ],
        ),
      );
    }

    final ok = await showApprovalConfirmSheet(
      context,
      title: isPartialCompletion
          ? 'Approve remaining payment'
          : 'Approve payment',
      personName: 'Cash from ${info.studentName}',
      amount: info.payment.amount,
      extra: extra,
      message: willCompletePayment
          ? 'This will complete the remaining payment and fully activate their stay.'
          : isPartialCompletion
          ? 'This will update their partial payment. Stay remains active.'
          : 'This will activate their stay.',
      confirmLabel: 'Approve',
      color: AppUIConstants.success,
      icon: Icons.check_circle_outline_rounded,
    );
    if (!ok || !mounted) return;
    context.read<CashApprovalCubit>().approve(
      paymentId: info.payment.id,
      ownerId: widget.ownerId,
      libraryId: widget.libraryId,
    );
  }

  Future<void> _handleReject(PendingCashPaymentInfo info) async {
    final ok = await showApprovalConfirmSheet(
      context,
      title: 'Reject cash payment',
      personName: 'Cash from ${info.studentName}',
      amount: info.payment.amount,
      message: 'Their bed reservation will be cancelled.',
      confirmLabel: 'Reject',
      color: AppUIConstants.error,
      icon: Icons.cancel_outlined,
    );
    if (!ok || !mounted) return;
    context.read<CashApprovalCubit>().reject(
      paymentId: info.payment.id,
      ownerId: widget.ownerId,
      libraryId: widget.libraryId,
      reason: 'Cash payment rejected by owner',
    );
  }
}
