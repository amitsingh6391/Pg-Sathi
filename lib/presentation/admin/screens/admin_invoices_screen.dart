import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/di/injection_container.dart';
import '../../../data/services/invoice_pdf_service.dart';
import '../../../domain/entities/invoice.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/admin_analytics_cubit.dart';
import '../cubit/admin_invoices_cubit.dart';

/// Admin screen for viewing and managing all invoices.
class AdminInvoicesScreen extends StatelessWidget {
  const AdminInvoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = sl<AdminInvoicesCubit>();
        // Set available libraries from analytics cubit
        final analyticsState = context.read<AdminAnalyticsCubit>().state;
        cubit.setAvailableLibraries(analyticsState.librarySummaries);
        cubit.loadInvoices();
        return cubit;
      },
      child: const _AdminInvoicesView(),
    );
  }
}

class _AdminInvoicesView extends StatefulWidget {
  const _AdminInvoicesView();

  @override
  State<_AdminInvoicesView> createState() => _AdminInvoicesViewState();
}

class _AdminInvoicesViewState extends State<_AdminInvoicesView> {
  final _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        title: const Text('Invoices'),
        backgroundColor: AppUIConstants.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context),
            tooltip: 'Filter',
          ),
        ],
      ),
      body: BlocBuilder<AdminInvoicesCubit, AdminInvoicesState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.hasError) {
            return _buildErrorView(context, state.errorMessage);
          }

          return Column(
            children: [
              // Search and Summary
              _buildHeader(context, state),

              // Invoice List
              Expanded(
                child: state.searchedInvoices.isEmpty
                    ? _buildEmptyState()
                    : _buildInvoiceList(state.searchedInvoices),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AdminInvoicesState state) {
    return Container(
      padding: const EdgeInsets.all(AppUIConstants.spacingLg),
      color: AppUIConstants.surface,
      child: Column(
        children: [
          // Search
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by invoice #, name, or phone...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        context.read<AdminInvoicesCubit>().searchInvoices('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
                borderSide: BorderSide(color: AppUIConstants.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
                borderSide: BorderSide(color: AppUIConstants.border),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppUIConstants.spacingMd,
                vertical: AppUIConstants.spacingMd,
              ),
            ),
            onChanged: (value) {
              context.read<AdminInvoicesCubit>().searchInvoices(value);
            },
          ),
          const SizedBox(height: AppUIConstants.spacingMd),

          // Summary
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Total Invoices',
                  value: '${state.filteredInvoices.length}',
                ),
              ),
              const SizedBox(width: AppUIConstants.spacingMd),
              Expanded(
                child: _SummaryCard(
                  label: 'Total Amount',
                  value: '₹${state.totalAmount.toStringAsFixed(0)}',
                  color: AppUIConstants.success,
                ),
              ),
            ],
          ),

          // Active Filters
          if (state.selectedLibraryId != null ||
              state.startDate != null ||
              state.endDate != null)
            Padding(
              padding: const EdgeInsets.only(top: AppUIConstants.spacingMd),
              child: _buildActiveFilters(context, state),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveFilters(BuildContext context, AdminInvoicesState state) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (state.selectedLibraryName != null)
            _FilterChip(
              label: state.selectedLibraryName!,
              onRemove: () {
                context.read<AdminInvoicesCubit>().filterByLibrary(null);
              },
            ),
          if (state.startDate != null || state.endDate != null)
            _FilterChip(
              label: _formatDateRange(state.startDate, state.endDate),
              onRemove: () {
                setState(() {
                  _startDate = null;
                  _endDate = null;
                });
                context.read<AdminInvoicesCubit>().filterByDateRange(
                  null,
                  null,
                );
              },
            ),
          TextButton(
            onPressed: () {
              setState(() {
                _startDate = null;
                _endDate = null;
              });
              context.read<AdminInvoicesCubit>().clearFilters();
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceList(List<Invoice> invoices) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppUIConstants.spacingMd),
      itemCount: invoices.length,
      itemBuilder: (context, index) {
        final invoice = invoices[index];
        return _InvoiceCard(
          invoice: invoice,
          onDownload: () => _downloadInvoice(invoice),
          onShare: () => _shareInvoice(invoice),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: AppUIConstants.textTertiary,
          ),
          const SizedBox(height: AppUIConstants.spacingMd),
          Text('No invoices found', style: AppUIConstants.bodyMd),
          const SizedBox(height: AppUIConstants.spacingSm),
          Text(
            'Try adjusting your filters',
            style: AppUIConstants.bodySm.copyWith(
              color: AppUIConstants.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, String? message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: AppUIConstants.error, size: 48),
          const SizedBox(height: AppUIConstants.spacingMd),
          Text(
            message ?? 'Failed to load invoices',
            style: AppUIConstants.bodyMd,
          ),
          const SizedBox(height: AppUIConstants.spacingLg),
          ElevatedButton(
            onPressed: () => context.read<AdminInvoicesCubit>().loadInvoices(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    final cubit = context.read<AdminInvoicesCubit>();
    final state = cubit.state;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppUIConstants.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppUIConstants.radiusLg),
        ),
      ),
      builder: (bottomContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppUIConstants.spacingLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle
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
                      const SizedBox(height: AppUIConstants.spacingLg),

                      Text('Filter Invoices', style: AppUIConstants.headingSm),
                      const SizedBox(height: AppUIConstants.spacingLg),

                      // Library Filter
                      Text('Library', style: AppUIConstants.bodyLg),
                      const SizedBox(height: AppUIConstants.spacingSm),
                      DropdownButtonFormField<String>(
                        initialValue: state.selectedLibraryId,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppUIConstants.radiusMd,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppUIConstants.spacingMd,
                          ),
                        ),
                        hint: const Text('All Libraries'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('All Libraries'),
                          ),
                          ...state.availableLibraries.map((lib) {
                            return DropdownMenuItem<String>(
                              value: lib.libraryId,
                              child: Text(
                                lib.libraryName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          cubit.filterByLibrary(value);
                        },
                      ),
                      const SizedBox(height: AppUIConstants.spacingLg),

                      // Date Range
                      Text('Date Range', style: AppUIConstants.bodyLg),
                      const SizedBox(height: AppUIConstants.spacingSm),
                      Row(
                        children: [
                          Expanded(
                            child: _DatePickerField(
                              label: 'Start Date',
                              value: _startDate,
                              onPicked: (date) {
                                setModalState(() => _startDate = date);
                              },
                            ),
                          ),
                          const SizedBox(width: AppUIConstants.spacingMd),
                          Expanded(
                            child: _DatePickerField(
                              label: 'End Date',
                              value: _endDate,
                              onPicked: (date) {
                                setModalState(() => _endDate = date);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppUIConstants.spacing2Xl),

                      // Apply Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            cubit.filterByDateRange(_startDate, _endDate);
                            Navigator.of(context).pop();
                          },
                          style: AppUIConstants.primaryButtonStyle,
                          child: const Text('Apply Filters'),
                        ),
                      ),
                      const SizedBox(height: AppUIConstants.spacingMd),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _formatDateRange(DateTime? start, DateTime? end) {
    final formatter = DateFormat('MMM d');
    if (start != null && end != null) {
      return '${formatter.format(start)} - ${formatter.format(end)}';
    } else if (start != null) {
      return 'From ${formatter.format(start)}';
    } else if (end != null) {
      return 'Until ${formatter.format(end)}';
    }
    return '';
  }

  Future<void> _downloadInvoice(Invoice invoice) async {
    try {
      final pdfService = sl<InvoicePdfService>();
      await pdfService.generateAndOpen(invoice);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    }
  }

  Future<void> _shareInvoice(Invoice invoice) async {
    try {
      final pdfService = sl<InvoicePdfService>();
      await pdfService.generateAndShare(invoice);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Share failed: $e')));
      }
    }
  }
}

// ============================================================================
// Supporting Widgets
// ============================================================================

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppUIConstants.spacingMd),
      decoration: BoxDecoration(
        color: (color ?? AppUIConstants.primary).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppUIConstants.caption),
          const SizedBox(height: AppUIConstants.spacingXs),
          Text(
            value,
            style: AppUIConstants.headingSm.copyWith(
              color: color ?? AppUIConstants.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: AppUIConstants.spacingSm),
      child: Chip(
        label: Text(label),
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: onRemove,
        backgroundColor: AppUIConstants.primary.withValues(alpha: 0.1),
        labelStyle: AppUIConstants.bodySm.copyWith(
          color: AppUIConstants.primary,
        ),
        deleteIconColor: AppUIConstants.primary,
        side: BorderSide.none,
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onPicked,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onPicked;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppUIConstants.spacingMd,
          vertical: AppUIConstants.spacingMd,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: AppUIConstants.border),
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 18,
              color: AppUIConstants.textSecondary,
            ),
            const SizedBox(width: AppUIConstants.spacingSm),
            Expanded(
              child: Text(
                value != null
                    ? DateFormat('MMM d, yyyy').format(value!)
                    : label,
                style: value != null
                    ? AppUIConstants.bodyMd
                    : AppUIConstants.bodyMd.copyWith(
                        color: AppUIConstants.textTertiary,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.invoice,
    required this.onDownload,
    required this.onShare,
  });

  final Invoice invoice;
  final VoidCallback onDownload;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppUIConstants.spacingMd),
      padding: const EdgeInsets.all(AppUIConstants.spacingMd),
      decoration: AppUIConstants.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppUIConstants.spacingSm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppUIConstants.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                    AppUIConstants.radiusFull,
                  ),
                ),
                child: Text(
                  invoice.invoiceNumber,
                  style: AppUIConstants.caption.copyWith(
                    color: AppUIConstants.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                invoice.formattedAmount,
                style: AppUIConstants.headingSm.copyWith(
                  color: AppUIConstants.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppUIConstants.spacingMd),

          // Details
          _DetailRow(
            icon: Icons.person_outline,
            label: invoice.studentName,
            subtitle: invoice.studentPhone,
          ),
          const SizedBox(height: AppUIConstants.spacingSm),
          _DetailRow(
            icon: Icons.business,
            label: invoice.libraryName,
            subtitle: invoice.formattedBillingMonth,
          ),
          const SizedBox(height: AppUIConstants.spacingSm),
          _DetailRow(
            icon: Icons.event_seat,
            label: 'Seat ${invoice.seatNumber}',
            subtitle: invoice.sessionTiming,
          ),

          const SizedBox(height: AppUIConstants.spacingMd),
          Divider(color: AppUIConstants.divider),
          const SizedBox(height: AppUIConstants.spacingSm),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                DateFormat('MMM d, yyyy').format(invoice.generatedAt),
                style: AppUIConstants.caption,
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.download,
                  color: AppUIConstants.primary,
                  size: 20,
                ),
                onPressed: onDownload,
                tooltip: 'Download',
              ),
              IconButton(
                icon: Icon(Icons.share, color: AppUIConstants.accent, size: 20),
                onPressed: onShare,
                tooltip: 'Share',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.subtitle,
  });

  final IconData icon;
  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppUIConstants.textTertiary),
        const SizedBox(width: AppUIConstants.spacingSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppUIConstants.bodySm.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: AppUIConstants.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
