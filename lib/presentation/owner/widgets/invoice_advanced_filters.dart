import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/app_ui_constants.dart';
import '../cubit/owner_invoice_cubit.dart';
import '../cubit/owner_invoice_state.dart';

/// Advanced filter widget for invoices.
/// Provides search by name/phone, invoice ID, date range, and payment status.
class InvoiceAdvancedFilters extends StatefulWidget {
  const InvoiceAdvancedFilters({super.key});

  @override
  State<InvoiceAdvancedFilters> createState() => _InvoiceAdvancedFiltersState();
}

class _InvoiceAdvancedFiltersState extends State<InvoiceAdvancedFilters> {
  final _searchController = TextEditingController();
  final _invoiceIdController = TextEditingController();
  Timer? _debounceTimer;
  bool _isExpanded = false;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _invoiceIdController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      context.read<OwnerInvoiceCubit>().search(query);
    });
  }

  void _onInvoiceIdChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      context.read<OwnerInvoiceCubit>().searchInvoiceId(query);
    });
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppUIConstants.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      context.read<OwnerInvoiceCubit>().filterByDateRange(
        picked.start,
        picked.end,
      );
    }
  }

  void _clearFilters() {
    _searchController.clear();
    _invoiceIdController.clear();
    context.read<OwnerInvoiceCubit>().clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OwnerInvoiceCubit, OwnerInvoiceState>(
      builder: (context, state) {
        return Container(
          color: AppUIConstants.surface,
          child: Column(
            children: [
              // Primary Search Bar
              Padding(
                padding: const EdgeInsets.all(AppUIConstants.spacingLg),
                child: Row(
                  children: [
                    Expanded(
                      child: _SearchField(
                        controller: _searchController,
                        hintText: 'Search by name or phone...',
                        onChanged: _onSearchChanged,
                      ),
                    ),
                    const SizedBox(width: AppUIConstants.spacingSm),
                    _FilterToggleButton(
                      isExpanded: _isExpanded,
                      hasActiveFilters: state.activeFilterCount > 0,
                      filterCount: state.activeFilterCount,
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                    ),
                  ],
                ),
              ),

              // Expanded Filters
              if (_isExpanded)
                _ExpandedFilters(
                  state: state,
                  invoiceIdController: _invoiceIdController,
                  onInvoiceIdChanged: _onInvoiceIdChanged,
                  onSelectDateRange: _selectDateRange,
                  onPaymentFilterChanged: (filter) {
                    context.read<OwnerInvoiceCubit>().filterByPaymentStatus(
                      filter,
                    );
                  },
                  onMonthChanged: (month) {
                    context.read<OwnerInvoiceCubit>().filterByMonth(month);
                  },
                  onClearFilters: _clearFilters,
                ),

              // Results Summary
              _ResultsSummary(
                count: state.filteredInvoices.length,
                hasFilters: state.hasFilters,
                onClear: _clearFilters,
              ),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// Search Field
// =============================================================================

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppUIConstants.bodySm,
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 20,
          color: AppUIConstants.textSecondary,
        ),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: Icon(
                  Icons.clear_rounded,
                  size: 18,
                  color: AppUIConstants.textSecondary,
                ),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              )
            : null,
        filled: true,
        fillColor: AppUIConstants.background,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppUIConstants.spacingMd,
          vertical: AppUIConstants.spacingMd,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          borderSide: BorderSide(color: AppUIConstants.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          borderSide: BorderSide(color: AppUIConstants.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          borderSide: BorderSide(color: AppUIConstants.primary),
        ),
      ),
    );
  }
}

// =============================================================================
// Filter Toggle Button
// =============================================================================

class _FilterToggleButton extends StatelessWidget {
  const _FilterToggleButton({
    required this.isExpanded,
    required this.hasActiveFilters,
    required this.filterCount,
    required this.onTap,
  });

  final bool isExpanded;
  final bool hasActiveFilters;
  final int filterCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppUIConstants.spacingMd),
        decoration: BoxDecoration(
          color: hasActiveFilters
              ? AppUIConstants.primary.withValues(alpha: 0.1)
              : AppUIConstants.background,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          border: Border.all(
            color: hasActiveFilters
                ? AppUIConstants.primary
                : AppUIConstants.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isExpanded
                  ? Icons.filter_alt_off_rounded
                  : Icons.filter_alt_rounded,
              size: 18,
              color: hasActiveFilters
                  ? AppUIConstants.primary
                  : AppUIConstants.textSecondary,
            ),
            if (hasActiveFilters) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppUIConstants.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$filterCount',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Expanded Filters
// =============================================================================

class _ExpandedFilters extends StatelessWidget {
  const _ExpandedFilters({
    required this.state,
    required this.invoiceIdController,
    required this.onInvoiceIdChanged,
    required this.onSelectDateRange,
    required this.onPaymentFilterChanged,
    required this.onMonthChanged,
    required this.onClearFilters,
  });

  final OwnerInvoiceState state;
  final TextEditingController invoiceIdController;
  final ValueChanged<String> onInvoiceIdChanged;
  final VoidCallback onSelectDateRange;
  final ValueChanged<InvoicePaymentFilter> onPaymentFilterChanged;
  final ValueChanged<String?> onMonthChanged;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppUIConstants.spacingLg,
        0,
        AppUIConstants.spacingLg,
        AppUIConstants.spacingLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Invoice ID Search
          Text('Invoice ID', style: AppUIConstants.caption),
          const SizedBox(height: 4),
          _SearchField(
            controller: invoiceIdController,
            hintText: 'Search by invoice number...',
            onChanged: onInvoiceIdChanged,
          ),
          const SizedBox(height: AppUIConstants.spacingMd),

          // Date Range and Month Filter Row
          Row(
            children: [
              Expanded(
                child: _DateRangeButton(
                  startDate: state.dateRangeStart,
                  endDate: state.dateRangeEnd,
                  onTap: onSelectDateRange,
                ),
              ),
              const SizedBox(width: AppUIConstants.spacingSm),
              Expanded(
                child: _MonthDropdown(
                  selectedMonth: state.selectedMonth,
                  months: state.availableMonths,
                  formatMonth: state.formatMonth,
                  onChanged: onMonthChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppUIConstants.spacingMd),

          // Payment Status Filter
          Text('Payment Status', style: AppUIConstants.caption),
          const SizedBox(height: 6),
          Row(
            children: InvoicePaymentFilter.values.map((filter) {
              final isSelected = state.paymentFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FilterChip(
                  label: filter.name.toUpperCase(),
                  isSelected: isSelected,
                  onTap: () => onPaymentFilterChanged(filter),
                ),
              );
            }).toList(),
          ),

          // Clear All Button
          if (state.hasFilters) ...[
            const SizedBox(height: AppUIConstants.spacingMd),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.clear_all_rounded, size: 16),
                label: const Text('Clear All Filters'),
                style: TextButton.styleFrom(
                  foregroundColor: AppUIConstants.error,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DateRangeButton extends StatelessWidget {
  const _DateRangeButton({
    required this.startDate,
    required this.endDate,
    required this.onTap,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasSelection = startDate != null && endDate != null;
    final dateFormat = DateFormat('MMM dd');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Date Range', style: AppUIConstants.caption),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppUIConstants.spacingMd,
              vertical: AppUIConstants.spacingMd,
            ),
            decoration: BoxDecoration(
              color: AppUIConstants.background,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
              border: Border.all(color: AppUIConstants.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.date_range_rounded,
                  size: 16,
                  color: AppUIConstants.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hasSelection
                        ? '${dateFormat.format(startDate!)} - ${dateFormat.format(endDate!)}'
                        : 'Select range',
                    style: AppUIConstants.bodySm.copyWith(
                      color: hasSelection
                          ? AppUIConstants.textPrimary
                          : AppUIConstants.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthDropdown extends StatelessWidget {
  const _MonthDropdown({
    required this.selectedMonth,
    required this.months,
    required this.formatMonth,
    required this.onChanged,
  });

  final String? selectedMonth;
  final List<String> months;
  final String Function(String) formatMonth;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Month', style: AppUIConstants.caption),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppUIConstants.background,
            borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            border: Border.all(color: AppUIConstants.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedMonth,
              hint: Text('All', style: AppUIConstants.bodySm),
              isExpanded: true,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: AppUIConstants.textSecondary,
              ),
              style: AppUIConstants.bodySm.copyWith(
                color: AppUIConstants.textPrimary,
              ),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text('All Months'),
                ),
                ...months.map(
                  (m) =>
                      DropdownMenuItem(value: m, child: Text(formatMonth(m))),
                ),
              ],
              onChanged: onChanged,
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
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppUIConstants.primary
              : AppUIConstants.background,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
          border: Border.all(
            color: isSelected ? AppUIConstants.primary : AppUIConstants.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppUIConstants.textSecondary,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Results Summary
// =============================================================================

class _ResultsSummary extends StatelessWidget {
  const _ResultsSummary({
    required this.count,
    required this.hasFilters,
    required this.onClear,
  });

  final int count;
  final bool hasFilters;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppUIConstants.spacingLg,
        vertical: AppUIConstants.spacingSm,
      ),
      decoration: BoxDecoration(
        color: AppUIConstants.background,
        border: Border(top: BorderSide(color: AppUIConstants.divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$count invoice${count == 1 ? '' : 's'}${hasFilters ? ' (filtered)' : ''}',
            style: AppUIConstants.caption,
          ),
          if (hasFilters)
            TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Clear filters',
                style: TextStyle(fontSize: 11, color: AppUIConstants.primary),
              ),
            ),
        ],
      ),
    );
  }
}
