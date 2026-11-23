import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/invoice.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';
import '../cubit/invoice_cubit.dart';
import '../cubit/invoice_state.dart';

/// Student rent ledger: every receipt, grouped on a timeline, with
/// download / share / delete actions.
class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key, required this.userId});

  final String userId;

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  bool _hasLoaded = false;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    // Only load once to avoid double query execution
    if (!_hasLoaded) {
      _hasLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<InvoiceCubit>().loadInvoices(widget.userId);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      body: BlocConsumer<InvoiceCubit, InvoiceState>(
        listener: (context, state) {
          if (state.isError && state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: AppUIConstants.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          Widget body;
          if (state.isLoading) {
            body = const _SkeletonList(key: ValueKey('loading'));
          } else if (!state.hasInvoices) {
            body = const _EmptyState(key: ValueKey('empty'));
          } else {
            body = _buildLedger(context, state);
          }
          return Column(
            children: [
              _LedgerHero(
                invoices: state.isLoading ? const [] : state.invoices,
                loading: state.isLoading,
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: body,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<String> _filters(List<Invoice> invoices) {
    final years = <String>{
      for (final i in invoices) i.paymentDate.year.toString(),
    }.toList()..sort((a, b) => b.compareTo(a));
    return ['All', ...years];
  }

  Widget _buildLedger(BuildContext context, InvoiceState state) {
    final all = state.invoices;
    final filters = _filters(all);
    final active = filters.contains(_filter) ? _filter : 'All';
    final shown = active == 'All'
        ? all
        : all.where((i) => i.paymentDate.year.toString() == active).toList();

    return RefreshIndicator(
      key: const ValueKey('ledger'),
      color: AppUIConstants.primaryLight,
      backgroundColor: AppUIConstants.surfaceMuted,
      onRefresh: () async =>
          context.read<InvoiceCubit>().loadInvoices(widget.userId),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppUIConstants.spacingLg,
          AppUIConstants.spacingMd,
          AppUIConstants.spacingLg,
          MediaQuery.of(context).padding.bottom + AppUIConstants.spacing2Xl,
        ),
        itemCount: shown.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppUIConstants.spacingLg),
              child: SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: filters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final f = filters[i];
                    final selected = f == active;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _filter = f);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppUIConstants.primary
                              : AppUIConstants.surface,
                          borderRadius: BorderRadius.circular(
                            AppUIConstants.radiusFull,
                          ),
                          border: Border.all(
                            color: selected
                                ? AppUIConstants.primaryLight
                                : AppUIConstants.border,
                          ),
                        ),
                        child: Text(
                          f == 'All' ? 'All receipts' : f,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? Colors.white
                                : AppUIConstants.textSecondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          }
          final invoice = shown[index - 1];
          final isDownloading = state.isDownloadingInvoice(invoice.id);
          return _TimelineEntry(
            isFirst: index == 1,
            isLast: index == shown.length,
            child: Builder(
              builder: (cardContext) => _InvoiceCard(
                invoice: invoice,
                isDownloading: isDownloading,
                onDownload: () =>
                    context.read<InvoiceCubit>().downloadInvoice(invoice),
                onShare: () {
                  final box = cardContext.findRenderObject() as RenderBox?;
                  final shareOrigin = box != null
                      ? box.localToGlobal(Offset.zero) & box.size
                      : null;
                  context.read<InvoiceCubit>().shareInvoice(
                    invoice,
                    shareOrigin: shareOrigin,
                  );
                },
                onDelete: () =>
                    _showDeleteConfirmation(context, invoice, widget.userId),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    Invoice invoice,
    String userId,
  ) async {
    HapticFeedback.mediumImpact();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppUIConstants.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppUIConstants.radiusXl),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppUIConstants.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppUIConstants.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppUIConstants.error,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Delete receipt?', style: AppUIConstants.headingMd),
              const SizedBox(height: 8),
              Text(
                'Receipt ${invoice.invoiceNumber} will be removed permanently. This cannot be undone.',
                style: AppUIConstants.bodySm,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppUIConstants.textPrimary,
                        side: const BorderSide(color: AppUIConstants.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppUIConstants.radiusMd,
                          ),
                        ),
                      ),
                      child: const Text('Keep it'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppUIConstants.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppUIConstants.radiusMd,
                          ),
                        ),
                      ),
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<InvoiceCubit>().deleteInvoiceById(invoice.id, userId);
    }
  }
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

class _LedgerHero extends StatelessWidget {
  const _LedgerHero({
    required this.invoices,
    required this.loading,
    required this.onBack,
  });

  final List<Invoice> invoices;
  final bool loading;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final total = invoices.fold<double>(0, (s, i) => s + i.amountPaid);
    final latest = invoices.isEmpty
        ? null
        : invoices.reduce(
            (a, b) => a.paymentDate.isAfter(b.paymentDate) ? a : b,
          );
    final fmt = NumberFormat.decimalPattern('en_IN');

    return PremiumHero(
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
                'Rent ledger',
                style: TextStyle(
                  color: AppUIConstants.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Total rent paid',
            style: TextStyle(color: AppUIConstants.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: total),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text(
              loading ? '₹ --' : '₹ ${fmt.format(v.round())}',
              style: const TextStyle(
                color: AppUIConstants.textPrimary,
                fontSize: 38,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _HeroChip(
                icon: Icons.receipt_long_rounded,
                label: '${invoices.length} receipts',
              ),
              const SizedBox(width: 8),
              if (latest != null)
                _HeroChip(
                  icon: Icons.event_available_rounded,
                  label:
                      'Last ${DateFormat('dd MMM').format(latest.paymentDate)}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppUIConstants.surfaceMuted,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppUIConstants.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppUIConstants.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timeline + card
// ---------------------------------------------------------------------------

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.child,
    required this.isFirst,
    required this.isLast,
  });

  final Widget child;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 22,
                  color: isFirst ? Colors.transparent : AppUIConstants.border,
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppUIConstants.success,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : AppUIConstants.border,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppUIConstants.spacingMd),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.invoice,
    required this.isDownloading,
    required this.onDownload,
    required this.onShare,
    required this.onDelete,
  });

  final Invoice invoice;
  final bool isDownloading;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.formattedBillingMonth,
                      style: AppUIConstants.caption,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      invoice.formattedAmount,
                      style: AppUIConstants.statValue,
                    ),
                  ],
                ),
              ),
              const PremiumStatusPill('PAID', color: AppUIConstants.success),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            invoice.libraryName,
            style: AppUIConstants.bodyMd,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                icon: Icons.bed_rounded,
                label: 'Bed ${invoice.seatNumber}',
              ),
              _MetaChip(
                icon: Icons.calendar_today_rounded,
                label: dateFormat.format(invoice.paymentDate),
              ),
              _MetaChip(icon: Icons.tag_rounded, label: invoice.invoiceNumber),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppUIConstants.divider),
          Row(
            children: [
              _ActionButton(
                icon: Icons.download_rounded,
                label: 'Download',
                color: AppUIConstants.primaryLight,
                loading: isDownloading,
                onTap: isDownloading ? null : onDownload,
              ),
              _ActionButton(
                icon: Icons.ios_share_rounded,
                label: 'Share',
                color: AppUIConstants.textSecondary,
                onTap: isDownloading ? null : onShare,
              ),
              _ActionButton(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                color: AppUIConstants.error,
                onTap: isDownloading ? null : onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppUIConstants.surfaceMuted,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppUIConstants.textTertiary),
          const SizedBox(width: 5),
          Text(label, style: AppUIConstants.bodySm.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = onTap == null && !loading ? AppUIConstants.disabled : color;
    return Expanded(
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              loading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    )
                  : Icon(icon, size: 18, color: c),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
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

// ---------------------------------------------------------------------------
// Loading / empty
// ---------------------------------------------------------------------------

class _SkeletonList extends StatefulWidget {
  const _SkeletonList({super.key});

  @override
  State<_SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<_SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final color = Color.lerp(
          AppUIConstants.surface,
          AppUIConstants.surfaceMuted,
          _c.value,
        )!;
        return ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppUIConstants.spacingLg),
          children: List.generate(
            3,
            (_) => Container(
              height: 150,
              margin: const EdgeInsets.only(bottom: AppUIConstants.spacingMd),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
                border: Border.all(color: AppUIConstants.border),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: AppUIConstants.primarySoft,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppUIConstants.primaryLight.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                size: 44,
                color: AppUIConstants.primaryLight,
              ),
            ),
            const SizedBox(height: 24),
            const Text('Your ledger is empty', style: AppUIConstants.headingMd),
            const SizedBox(height: 8),
            const Text(
              'Rent receipts will show up here\nonce you pay for your PG stay.',
              style: AppUIConstants.bodySm,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back to my PG'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppUIConstants.primaryLight,
                side: const BorderSide(color: AppUIConstants.primary),
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
    );
  }
}
