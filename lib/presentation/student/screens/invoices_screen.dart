import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/invoice.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/invoice_cubit.dart';
import '../cubit/invoice_state.dart';

/// Student invoices screen.
/// Shows all invoices with download functionality.
class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key, required this.userId});

  final String userId;

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  bool _hasLoaded = false;

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
      appBar: AppBar(
        backgroundColor: AppUIConstants.primary,
        title: const Text(
          'My Invoices',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: BlocConsumer<InvoiceCubit, InvoiceState>(
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
            return _LoadingState();
          }

          if (!state.hasInvoices) {
            return _EmptyState();
          }

          return RefreshIndicator(
            color: AppUIConstants.primary,
            onRefresh: () async =>
                context.read<InvoiceCubit>().loadInvoices(widget.userId),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppUIConstants.spacingLg),
              itemCount: state.invoices.length,
              itemBuilder: (context, index) {
                final invoice = state.invoices[index];
                final isDownloading = state.isDownloadingInvoice(invoice.id);

                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: AppUIConstants.spacingMd,
                  ),
                  child: Builder(
                    builder: (cardContext) => _InvoiceCard(
                      invoice: invoice,
                      isDownloading: isDownloading,
                      onDownload: () =>
                          context.read<InvoiceCubit>().downloadInvoice(invoice),
                      onShare: () {
                        final box =
                            cardContext.findRenderObject() as RenderBox?;
                        final shareOrigin = box != null
                            ? box.localToGlobal(Offset.zero) & box.size
                            : null;
                        context.read<InvoiceCubit>().shareInvoice(
                          invoice,
                          shareOrigin: shareOrigin,
                        );
                      },
                      onDelete: () => _showDeleteConfirmation(
                        context,
                        invoice,
                        widget.userId,
                      ),
                    ),
                  ),
                );
              },
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        ),
        title: const Text('Delete Invoice?'),
        content: Text(
          'Are you sure you want to delete invoice ${invoice.invoiceNumber}?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
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
      await context.read<InvoiceCubit>().deleteInvoiceById(invoice.id, userId);
    }
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

    return Container(
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(color: AppUIConstants.border),
        boxShadow: [AppUIConstants.shadowSm],
      ),
      child: Column(
        children: [
          // Main content
          Padding(
            padding: const EdgeInsets.all(AppUIConstants.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoice.formattedBillingMonth,
                            style: AppUIConstants.headingSm,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            invoice.libraryName,
                            style: AppUIConstants.bodySm,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppUIConstants.spacingMd,
                        vertical: AppUIConstants.spacingXs,
                      ),
                      decoration: BoxDecoration(
                        color: AppUIConstants.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppUIConstants.radiusFull,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: AppUIConstants.success,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'PAID',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppUIConstants.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppUIConstants.spacingMd),

                // Details grid
                Row(
                  children: [
                    Expanded(
                      child: _DetailItem(
                        label: 'Amount',
                        value: invoice.formattedAmount,
                        valueStyle: AppUIConstants.bodyLg.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _DetailItem(
                        label: 'Invoice No.',
                        value: invoice.invoiceNumber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppUIConstants.spacingSm),
                Row(
                  children: [
                    Expanded(
                      child: _DetailItem(
                        label: 'Seat',
                        value: invoice.seatNumber,
                      ),
                    ),
                    Expanded(
                      child: _DetailItem(
                        label: 'Payment Date',
                        value: dateFormat.format(invoice.paymentDate),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Actions divider
          const Divider(height: 1, color: AppUIConstants.divider),

          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppUIConstants.spacingMd,
              vertical: AppUIConstants.spacingSm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: IconButton(
                    onPressed: isDownloading ? null : onDownload,
                    icon: isDownloading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppUIConstants.primary,
                            ),
                          )
                        : const Icon(Icons.download_rounded, size: 20),
                    color: AppUIConstants.primary,
                    tooltip: 'Download',
                  ),
                ),
                Container(width: 1, height: 24, color: AppUIConstants.divider),
                Expanded(
                  child: IconButton(
                    onPressed: isDownloading ? null : onShare,
                    icon: const Icon(Icons.share_rounded, size: 20),
                    color: AppUIConstants.textSecondary,
                    tooltip: 'Share',
                  ),
                ),
                Container(width: 1, height: 24, color: AppUIConstants.divider),
                Expanded(
                  child: IconButton(
                    onPressed: isDownloading ? null : onDelete,
                    icon: const Icon(Icons.delete_rounded, size: 20),
                    color: AppUIConstants.error,
                    tooltip: 'Delete',
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

class _DetailItem extends StatelessWidget {
  const _DetailItem({
    required this.label,
    required this.value,
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppUIConstants.caption),
        const SizedBox(height: 2),
        Text(
          value,
          style: valueStyle ?? AppUIConstants.bodyMd,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: AppUIConstants.primary,
              strokeWidth: 2,
            ),
            const SizedBox(height: 24),
            Text(
              'Fetching invoices...',
              style: AppUIConstants.bodyMd.copyWith(
                color: AppUIConstants.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppUIConstants.divider,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                size: 48,
                color: AppUIConstants.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            Text('No Invoices Yet', style: AppUIConstants.headingMd),
            const SizedBox(height: 8),
            Text(
              'Your fees receipts will appear here\nonce you complete a payment.',
              style: AppUIConstants.bodySm,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
