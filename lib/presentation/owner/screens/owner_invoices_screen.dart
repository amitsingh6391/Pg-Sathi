import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:unicons/unicons.dart';

import '../../../core/utils/indian_currency_format.dart';
import '../../../domain/entities/invoice.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';

import '../cubit/owner_invoice_cubit.dart';
import '../cubit/owner_invoice_state.dart';
import '../widgets/invoice_advanced_filters.dart';

/// Owner invoices screen with student-wise and month-wise filtering.
class OwnerInvoicesScreen extends StatefulWidget {
  const OwnerInvoicesScreen({
    super.key,
    required this.ownerId,
    required this.libraryId,
    required this.libraryName,
  });

  final String ownerId;
  final String libraryId;
  final String libraryName;

  @override
  State<OwnerInvoicesScreen> createState() => _OwnerInvoicesScreenState();
}

class _OwnerInvoicesScreenState extends State<OwnerInvoicesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<OwnerInvoiceCubit>().loadInvoices(
      widget.ownerId,
      libraryId: widget.libraryId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        backgroundColor: AppUIConstants.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Invoices', style: AppUIConstants.headingMd),
            Text(widget.libraryName, style: AppUIConstants.caption),
          ],
        ),
        iconTheme: const IconThemeData(color: AppUIConstants.textPrimary),
        actions: [
          BlocBuilder<OwnerInvoiceCubit, OwnerInvoiceState>(
            builder: (context, state) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: state.hasFilters
                    ? IconButton(
                        key: const ValueKey('clear'),
                        icon: const Icon(
                          Icons.filter_alt_off_rounded,
                          color: AppUIConstants.primaryLight,
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          context.read<OwnerInvoiceCubit>().clearFilters();
                        },
                        tooltip: 'Clear filters',
                      )
                    : const SizedBox.shrink(key: ValueKey('none')),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<OwnerInvoiceCubit, OwnerInvoiceState>(
        listener: (context, state) {
          if (state.isError && state.errorMessage != null) {
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
            return const _InvoicesSkeleton();
          }

          final invoices = state.filteredInvoices;
          final items = _buildItems(invoices);

          return Column(
            children: [
              _SummaryStrip(invoices: invoices, hasFilters: state.hasFilters),
              const InvoiceAdvancedFilters(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: invoices.isEmpty
                      ? _EmptyState(
                          key: ValueKey('empty${state.hasFilters}'),
                          hasFilters: state.hasFilters,
                        )
                      : RefreshIndicator(
                          key: const ValueKey('list'),
                          color: AppUIConstants.primaryLight,
                          backgroundColor: AppUIConstants.surface,
                          onRefresh: () async =>
                              context.read<OwnerInvoiceCubit>().loadInvoices(
                                widget.ownerId,
                                libraryId: widget.libraryId,
                              ),
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(
                              AppUIConstants.spacingLg,
                              0,
                              AppUIConstants.spacingLg,
                              AppUIConstants.spacing3Xl,
                            ),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              if (item is _MonthHeader) {
                                return _MonthHeaderRow(header: item);
                              }
                              final invoice = item as Invoice;
                              final isDownloading = state.isDownloadingInvoice(
                                invoice.id,
                              );
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppUIConstants.spacingMd,
                                ),
                                child: Builder(
                                  builder: (cardContext) => _InvoiceCard(
                                    invoice: invoice,
                                    isDownloading: isDownloading,
                                    onDownload: () => context
                                        .read<OwnerInvoiceCubit>()
                                        .downloadInvoice(invoice),
                                    onShare: () {
                                      final box =
                                          cardContext.findRenderObject()
                                              as RenderBox?;
                                      final shareOrigin = box != null
                                          ? box.localToGlobal(Offset.zero) &
                                                box.size
                                          : null;
                                      context
                                          .read<OwnerInvoiceCubit>()
                                          .shareInvoice(
                                            invoice,
                                            shareOrigin: shareOrigin,
                                          );
                                    },
                                    onWhatsAppShare: () async {
                                      final box =
                                          cardContext.findRenderObject()
                                              as RenderBox?;
                                      final shareOrigin = box != null
                                          ? box.localToGlobal(Offset.zero) &
                                                box.size
                                          : null;
                                      final messenger = ScaffoldMessenger.of(
                                        context,
                                      );
                                      final copied = await context
                                          .read<OwnerInvoiceCubit>()
                                          .shareInvoiceToWhatsApp(
                                            invoice,
                                            shareOrigin: shareOrigin,
                                          );
                                      if (!copied) return;
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Invoice copied. In WhatsApp, long-press the message box and tap Paste.',
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                    onDelete: () => _showDeleteConfirmation(
                                      context,
                                      invoice,
                                      widget.ownerId,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Flattens invoices into month headers followed by their invoices
  /// (grouped by payment month, preserving the cubit's ordering).
  List<Object> _buildItems(List<Invoice> invoices) {
    final result = <Object>[];
    String? currentKey;
    for (var i = 0; i < invoices.length; i++) {
      final inv = invoices[i];
      final key = DateFormat('yyyy-MM').format(inv.paymentDate);
      if (key != currentKey) {
        currentKey = key;
        var total = 0.0;
        var count = 0;
        for (var j = i; j < invoices.length; j++) {
          if (DateFormat('yyyy-MM').format(invoices[j].paymentDate) != key) {
            break;
          }
          total += invoices[j].amountPaid;
          count++;
        }
        result.add(
          _MonthHeader(
            label: DateFormat('MMMM yyyy').format(inv.paymentDate),
            total: total,
            count: count,
          ),
        );
      }
      result.add(inv);
    }
    return result;
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    Invoice invoice,
    String ownerId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppUIConstants.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
          side: const BorderSide(color: AppUIConstants.border),
        ),
        icon: const Icon(
          Icons.delete_outline_rounded,
          color: AppUIConstants.error,
          size: 32,
        ),
        title: const Text('Delete invoice?', style: AppUIConstants.headingMd),
        content: Text(
          'Invoice ${invoice.invoiceNumber} will be permanently removed. This action cannot be undone.',
          style: AppUIConstants.bodyMd,
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppUIConstants.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppUIConstants.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<OwnerInvoiceCubit>().deleteInvoiceById(
        invoice.id,
        ownerId,
      );
    }
  }
}

class _MonthHeader {
  const _MonthHeader({
    required this.label,
    required this.total,
    required this.count,
  });

  final String label;
  final double total;
  final int count;
}

class _MonthHeaderRow extends StatelessWidget {
  const _MonthHeaderRow({required this.header});

  final _MonthHeader header;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 10),
      child: Row(
        children: [
          Text(
            header.label.toUpperCase(),
            style: AppUIConstants.caption.copyWith(
              letterSpacing: 1,
              color: AppUIConstants.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Divider(height: 1, color: AppUIConstants.divider),
          ),
          const SizedBox(width: 10),
          Text(
            '${header.count} • ${indianRupeeCurrencyFormat.format(header.total)}',
            style: AppUIConstants.caption,
          ),
        ],
      ),
    );
  }
}

/// Compact hero: total collected across the currently listed invoices.
class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.invoices, required this.hasFilters});

  final List<Invoice> invoices;
  final bool hasFilters;

  @override
  Widget build(BuildContext context) {
    final total = invoices.fold<double>(0, (sum, i) => sum + i.amountPaid);
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppUIConstants.spacingLg,
        AppUIConstants.spacingSm,
        AppUIConstants.spacingLg,
        0,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        // Dark brand card so the white text is readable.
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppUIConstants.primary, AppUIConstants.primaryLight],
        ),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppUIConstants.primary.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasFilters ? 'FILTERED RENT RECEIVED' : 'TOTAL RENT RECEIVED',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 10.5,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: total),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => Text(
                    indianRupeeCurrencyFormat.format(v),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
            ),
            child: Column(
              children: [
                Text(
                  '${invoices.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  invoices.length == 1 ? 'receipt' : 'receipts',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 10.5,
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

/// Dashed horizontal line used as the receipt tear-off.
class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppUIConstants.border
      ..strokeWidth = 1.2;
    const dash = 6.0;
    const gap = 5.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.invoice,
    required this.isDownloading,
    required this.onDownload,
    required this.onShare,
    required this.onWhatsAppShare,
    required this.onDelete,
  });

  final Invoice invoice;
  final bool isDownloading;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onWhatsAppShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final initial = invoice.studentName.trim().isEmpty
        ? '?'
        : invoice.studentName.trim()[0].toUpperCase();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - t)),
          child: child,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppUIConstants.surface,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
          border: Border.all(color: AppUIConstants.border),
          boxShadow: [AppUIConstants.shadowSm],
        ),
        child: Column(
          children: [
            // Receipt top: resident + amount
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppUIConstants.primarySoft,
                      borderRadius: BorderRadius.circular(
                        AppUIConstants.radiusSm + 2,
                      ),
                    ),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: AppUIConstants.primaryLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoice.studentName,
                          style: AppUIConstants.headingSm,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          invoice.studentPhone,
                          style: AppUIConstants.caption,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${invoice.invoiceNumber}  •  ${dateFormat.format(invoice.paymentDate)}',
                          style: AppUIConstants.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        invoice.formattedAmount,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppUIConstants.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const PremiumStatusPill('Paid'),
                    ],
                  ),
                ],
              ),
            ),

            // Perforated tear line with side notches
            SizedBox(
              height: 18,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: SizedBox(
                      width: double.infinity,
                      height: 1,
                      child: CustomPaint(painter: _DashedLinePainter()),
                    ),
                  ),
                  Positioned(
                    left: -9,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppUIConstants.background,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppUIConstants.border),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -9,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppUIConstants.background,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppUIConstants.border),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Receipt bottom: details + actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _MetaChip(
                          icon: UniconsLine.calendar_alt,
                          text: invoice.formattedBillingMonth,
                        ),
                        _MetaChip(
                          icon: Icons.bed_outlined,
                          text: 'Bed ${invoice.seatNumber}',
                        ),
                        _MetaChip(
                          icon: UniconsLine.clock,
                          text: invoice.slotName ?? invoice.slot.shortName,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  _ActionButton(
                    onTap: isDownloading ? null : onDownload,
                    tooltip: 'Download',
                    color: AppUIConstants.primaryLight,
                    child: isDownloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppUIConstants.primaryLight,
                            ),
                          )
                        : const Icon(UniconsLine.download_alt, size: 18),
                  ),
                  _ActionButton(
                    onTap: isDownloading ? null : onShare,
                    tooltip: 'Share',
                    color: AppUIConstants.textSecondary,
                    child: const Icon(UniconsLine.share_alt, size: 18),
                  ),
                  _ActionButton(
                    onTap: isDownloading ? null : onWhatsAppShare,
                    tooltip: 'WhatsApp',
                    color: AppUIConstants.success,
                    child: const Icon(UniconsLine.whatsapp, size: 18),
                  ),
                  _ActionButton(
                    onTap: isDownloading ? null : onDelete,
                    tooltip: 'Delete',
                    color: AppUIConstants.error,
                    child: const Icon(UniconsLine.trash_alt, size: 18),
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.onTap,
    required this.tooltip,
    required this.color,
    required this.child,
  });

  final VoidCallback? onTap;
  final String tooltip;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onTap!();
              }
            : null,
        child: Container(
          width: 34,
          height: 34,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: enabled ? 0.12 : 0.05),
            borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
          ),
          child: IconTheme(
            data: IconThemeData(
              color: enabled ? color : AppUIConstants.disabled,
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppUIConstants.textTertiary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: AppUIConstants.bodySm.copyWith(
              color: AppUIConstants.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Pulsing placeholder shown while invoices load.
class _InvoicesSkeleton extends StatefulWidget {
  const _InvoicesSkeleton();

  @override
  State<_InvoicesSkeleton> createState() => _InvoicesSkeletonState();
}

class _InvoicesSkeletonState extends State<_InvoicesSkeleton>
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
      opacity: Tween(begin: 0.4, end: 1.0).animate(_c),
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppUIConstants.spacingLg),
        children: [
          Container(
            height: 76,
            decoration: BoxDecoration(
              color: AppUIConstants.surface,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppUIConstants.surface,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
            ),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < 3; i++) ...[
            Container(
              height: 140,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppUIConstants.surface,
                borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
                border: Border.all(color: AppUIConstants.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppUIConstants.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _bar(130, 14),
                      const SizedBox(height: 8),
                      _bar(90, 10),
                      const SizedBox(height: 16),
                      _bar(160, 10),
                    ],
                  ),
                  const Spacer(),
                  _bar(70, 22),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key, required this.hasFilters});

  final bool hasFilters;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppUIConstants.primarySoft,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppUIConstants.primaryLight.withValues(alpha: 0.3),
                ),
              ),
              child: Icon(
                hasFilters
                    ? Icons.filter_alt_off_rounded
                    : Icons.receipt_long_rounded,
                size: 40,
                color: AppUIConstants.primaryLight,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasFilters ? 'No matching invoices' : 'No invoices yet',
              style: AppUIConstants.headingMd,
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Nothing fits these filters.\nTry widening the date range or status.'
                  : 'Receipts show up here once your\nresidents pay their rent.',
              style: AppUIConstants.bodyMd,
              textAlign: TextAlign.center,
            ),
            if (hasFilters) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  context.read<OwnerInvoiceCubit>().clearFilters();
                },
                style: AppUIConstants.primaryButtonStyle,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
