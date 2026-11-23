import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/di/injection_container.dart';
import '../../../data/services/invoice_pdf_service.dart';
import '../../../domain/entities/invoice.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/admin_analytics_cubit.dart';
import '../../core/widgets/premium_kit.dart';
import '../cubit/admin_invoices_cubit.dart';
import '../widgets/subscription_widgets/shimmer_box.dart';

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
        title: const Text(
          'Invoices',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: AppUIConstants.background,
        foregroundColor: AppUIConstants.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => _showFilterSheet(context),
            tooltip: 'Filter',
          ),
        ],
      ),
      body: BlocBuilder<AdminInvoicesCubit, AdminInvoicesState>(
        builder: (context, state) {
          final Widget child;
          if (state.isLoading) {
            child = ListView(
              key: const ValueKey('loading'),
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 16),
              children: List.generate(5, (_) => const ShimmerCardRow()),
            );
          } else if (state.hasError) {
            child = KeyedSubtree(
              key: const ValueKey('error'),
              child: _buildErrorView(context, state.errorMessage),
            );
          } else {
            child = Column(
              key: const ValueKey('content'),
              children: [
                _buildHeader(context, state),
                Expanded(
                  child: state.searchedInvoices.isEmpty
                      ? _buildEmptyState(state)
                      : _buildInvoiceList(state.searchedInvoices),
                ),
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

  bool _hasFilters(AdminInvoicesState state) =>
      state.selectedLibraryId != null ||
      state.startDate != null ||
      state.endDate != null;

  Widget _buildHeader(BuildContext context, AdminInvoicesState state) {
    return Column(
      children: [
        PremiumHero(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TOTAL BILLED',
                style: TextStyle(
                  color: AppUIConstants.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '₹${NumberFormat('#,##,##0', 'en_IN').format(state.totalAmount)}',
                style: const TextStyle(
                  color: AppUIConstants.textPrimary,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  PremiumStatusPill(
                    '${state.filteredInvoices.length} invoices',
                    color: AppUIConstants.primaryLight,
                  ),
                  if (_hasFilters(state)) ...[
                    const SizedBox(width: 8),
                    const PremiumStatusPill(
                      'Filtered',
                      color: AppUIConstants.warning,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Container(
            decoration: BoxDecoration(
              color: AppUIConstants.surface,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
              border: Border.all(color: AppUIConstants.border),
            ),
            child: TextField(
              controller: _searchController,
              style: AppUIConstants.bodyMd,
              cursorColor: AppUIConstants.primaryLight,
              decoration: InputDecoration(
                hintText: 'Search invoice #, name or phone',
                hintStyle: AppUIConstants.bodySm.copyWith(
                  color: AppUIConstants.textTertiary,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppUIConstants.textTertiary,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppUIConstants.textSecondary,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          context.read<AdminInvoicesCubit>().searchInvoices('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                context.read<AdminInvoicesCubit>().searchInvoices(value);
              },
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _hasFilters(state)
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: _buildActiveFilters(context, state),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
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
            style: TextButton.styleFrom(
              foregroundColor: AppUIConstants.primaryLight,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceList(List<Invoice> invoices) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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

  Widget _buildEmptyState(AdminInvoicesState state) {
    return AdminEmptyState(
      icon: Icons.receipt_long_outlined,
      title: 'No invoices found',
      message: 'Try adjusting your search or filters',
      actionLabel: _hasFilters(state) ? 'Clear filters' : null,
      onAction: _hasFilters(state)
          ? () {
              setState(() {
                _startDate = null;
                _endDate = null;
              });
              context.read<AdminInvoicesCubit>().clearFilters();
            }
          : null,
    );
  }

  Widget _buildErrorView(BuildContext context, String? message) {
    return AdminEmptyState(
      icon: Icons.cloud_off_rounded,
      color: AppUIConstants.error,
      title: message ?? 'Failed to load invoices',
      actionLabel: 'Retry',
      onAction: () => context.read<AdminInvoicesCubit>().loadInvoices(),
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
                      Text('PG', style: AppUIConstants.bodyLg),
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
                        dropdownColor: AppUIConstants.surfaceMuted,
                        hint: const Text('All PGs'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('All PGs'),
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
        deleteIcon: const Icon(Icons.close_rounded, size: 16),
        onDeleted: onRemove,
        backgroundColor: AppUIConstants.primarySoft,
        labelStyle: AppUIConstants.bodySm.copyWith(
          color: AppUIConstants.primaryLight,
          fontWeight: FontWeight.w600,
        ),
        deleteIconColor: AppUIConstants.primaryLight,
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
    return PremiumCard(
      margin: const EdgeInsets.only(bottom: AppUIConstants.spacingMd),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PremiumStatusPill(
                invoice.invoiceNumber,
                color: AppUIConstants.primaryLight,
              ),
              const Spacer(),
              Text(
                invoice.formattedAmount,
                style: AppUIConstants.headingSm.copyWith(
                  color: AppUIConstants.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppUIConstants.spacingMd),
          _DetailRow(
            icon: Icons.person_outline_rounded,
            label: invoice.studentName,
            subtitle: invoice.studentPhone,
          ),
          const SizedBox(height: AppUIConstants.spacingSm),
          _DetailRow(
            icon: Icons.apartment_rounded,
            label: invoice.libraryName,
            subtitle: invoice.formattedBillingMonth,
          ),
          const SizedBox(height: AppUIConstants.spacingSm),
          _DetailRow(
            icon: Icons.bed_outlined,
            label: 'Bed ${invoice.seatNumber}',
            subtitle: invoice.sessionTiming,
          ),
          const SizedBox(height: AppUIConstants.spacingMd),
          const Divider(color: AppUIConstants.divider, height: 1),
          const SizedBox(height: AppUIConstants.spacingSm),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 14,
                color: AppUIConstants.textTertiary,
              ),
              const SizedBox(width: 6),
              Text(
                DateFormat('MMM d, yyyy').format(invoice.generatedAt),
                style: AppUIConstants.caption,
              ),
              const Spacer(),
              _RoundAction(
                icon: Icons.download_rounded,
                color: AppUIConstants.primaryLight,
                tooltip: 'Download',
                onTap: onDownload,
              ),
              const SizedBox(width: 8),
              _RoundAction(
                icon: Icons.share_rounded,
                color: AppUIConstants.primaryLight,
                tooltip: 'Share',
                onTap: onShare,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppUIConstants.surfaceMuted,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, color: color, size: 19),
          ),
        ),
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
