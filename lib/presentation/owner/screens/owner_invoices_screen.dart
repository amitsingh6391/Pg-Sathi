import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:unicons/unicons.dart';

import '../../../domain/entities/invoice.dart';
import '../../core/app_ui_constants.dart';

import '../cubit/owner_invoice_cubit.dart';
import '../cubit/owner_invoice_state.dart';
import '../widgets/invoice_advanced_filters.dart';

/// Owner invoices screen with student-wise and month-wise filtering.
class OwnerInvoicesScreen extends StatefulWidget {
  const OwnerInvoicesScreen({
    super.key,
    required this.ownerId,
    required this.libraryName,
  });

  final String ownerId;
  final String libraryName;

  @override
  State<OwnerInvoicesScreen> createState() => _OwnerInvoicesScreenState();
}

class _OwnerInvoicesScreenState extends State<OwnerInvoicesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<OwnerInvoiceCubit>().loadInvoices(widget.ownerId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        backgroundColor: AppUIConstants.primary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Invoices',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.libraryName,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          BlocBuilder<OwnerInvoiceCubit, OwnerInvoiceState>(
            builder: (context, state) {
              if (state.hasFilters) {
                return IconButton(
                  icon: const Icon(Icons.filter_alt_off_rounded),
                  onPressed: () =>
                      context.read<OwnerInvoiceCubit>().clearFilters(),
                  tooltip: 'Clear filters',
                );
              }
              return const SizedBox.shrink();
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
            return const Center(
              child: CircularProgressIndicator(
                color: AppUIConstants.primary,
                strokeWidth: 2,
              ),
            );
          }

          return Column(
            children: [
              // Advanced Filter Section (Feature 3)
              const InvoiceAdvancedFilters(),

              // Invoice List
              Expanded(
                child: state.filteredInvoices.isEmpty
                    ? _EmptyState(hasFilters: state.hasFilters)
                    : RefreshIndicator(
                        color: AppUIConstants.primary,
                        onRefresh: () async => context
                            .read<OwnerInvoiceCubit>()
                            .loadInvoices(widget.ownerId),
                        child: Builder(
                          builder: (context) {
                            return ListView.builder(
                              padding: const EdgeInsets.all(
                                AppUIConstants.spacingLg,
                              ),
                              itemCount: state.filteredInvoices.length,
                              itemBuilder: (context, index) {
                                final invoice = state.filteredInvoices[index];
                                final isDownloading = state
                                    .isDownloadingInvoice(invoice.id);
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
                                      onWhatsAppShare: () {
                                        final box =
                                            cardContext.findRenderObject()
                                                as RenderBox?;
                                        final shareOrigin = box != null
                                            ? box.localToGlobal(Offset.zero) &
                                                  box.size
                                            : null;
                                        context
                                            .read<OwnerInvoiceCubit>()
                                            .shareInvoiceToWhatsApp(
                                              invoice,
                                              shareOrigin: shareOrigin,
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
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    Invoice invoice,
    String ownerId,
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
      await context.read<OwnerInvoiceCubit>().deleteInvoiceById(
        invoice.id,
        ownerId,
      );
    }
  }
}

// _FilterSection removed - using InvoiceAdvancedFilters widget instead

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
                // Header row: Student name & Amount
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          invoice.formattedAmount,
                          style: AppUIConstants.headingSm.copyWith(
                            color: AppUIConstants.success,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppUIConstants.success.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'PAID',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppUIConstants.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppUIConstants.spacingMd),

                // Details grid
                Container(
                  padding: const EdgeInsets.all(AppUIConstants.spacingMd),
                  decoration: BoxDecoration(
                    color: AppUIConstants.background,
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusSm,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _DetailItem(
                          icon: UniconsLine.calendar_alt,
                          label: 'Month',
                          value: invoice.formattedBillingMonth,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: AppUIConstants.border,
                      ),
                      Expanded(
                        child: _DetailItem(
                          icon: UniconsLine.streering,
                          label: 'Seat',
                          value: invoice.seatNumber,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: AppUIConstants.border,
                      ),
                      Expanded(
                        child: _DetailItem(
                          icon: UniconsLine.clock,
                          label: 'Slot',
                          value: invoice.slotName ?? invoice.slot.shortName,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppUIConstants.spacingSm),

                // Invoice number & date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(invoice.invoiceNumber, style: AppUIConstants.caption),
                    Text(
                      dateFormat.format(invoice.paymentDate),
                      style: AppUIConstants.caption,
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
                        : const Icon(UniconsLine.download_alt, size: 20),
                    color: AppUIConstants.primary,
                    tooltip: 'Download',
                  ),
                ),
                Container(width: 1, height: 24, color: AppUIConstants.divider),
                Expanded(
                  child: IconButton(
                    onPressed: isDownloading ? null : onShare,
                    icon: const Icon(UniconsLine.share_alt, size: 20),
                    color: AppUIConstants.textSecondary,
                    tooltip: 'Share',
                  ),
                ),
                Container(width: 1, height: 24, color: AppUIConstants.divider),
                Expanded(
                  child: IconButton(
                    onPressed: isDownloading ? null : onWhatsAppShare,
                    icon: const Icon(UniconsLine.whatsapp, size: 20),
                    color: const Color(0xFF25D366),
                    tooltip: 'WhatsApp',
                  ),
                ),
                Container(width: 1, height: 24, color: AppUIConstants.divider),
                Expanded(
                  child: IconButton(
                    onPressed: isDownloading ? null : onDelete,
                    icon: const Icon(UniconsLine.trash_alt, size: 20),
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
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: AppUIConstants.textTertiary),
        const SizedBox(height: 4),
        Text(label, style: AppUIConstants.caption),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppUIConstants.bodySm.copyWith(
            fontWeight: FontWeight.w600,
            color: AppUIConstants.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilters});

  final bool hasFilters;

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
                hasFilters
                    ? Icons.filter_alt_off_rounded
                    : Icons.receipt_long_rounded,
                size: 48,
                color: AppUIConstants.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              hasFilters ? 'No Matching Invoices' : 'No Invoices Yet',
              style: AppUIConstants.headingMd,
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Try adjusting your filters.'
                  : 'Invoices will appear here\nwhen students complete payments.',
              style: AppUIConstants.bodySm,
              textAlign: TextAlign.center,
            ),
            if (hasFilters) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () =>
                    context.read<OwnerInvoiceCubit>().clearFilters(),
                child: const Text('Clear Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
