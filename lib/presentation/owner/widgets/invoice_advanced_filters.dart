import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
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
  Timer? _idDebounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _idDebounceTimer?.cancel();
    _searchController.dispose();
    _invoiceIdController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {});
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) context.read<OwnerInvoiceCubit>().search(query);
    });
  }

  void _onInvoiceIdChanged(String query) {
    _idDebounceTimer?.cancel();
    _idDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) context.read<OwnerInvoiceCubit>().searchInvoiceId(query);
    });
  }

  Future<void> _selectDateRange(BuildContext ctx) async {
    final now = DateTime.now();
    final cubit = context.read<OwnerInvoiceCubit>();
    final picked = await showDateRangePicker(
      context: ctx,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppUIConstants.primaryLight,
              onPrimary: AppUIConstants.background,
              surface: AppUIConstants.surface,
              onSurface: AppUIConstants.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      cubit.filterByDateRange(picked.start, picked.end);
    }
  }

  void _clearFilters() {
    HapticFeedback.selectionClick();
    _searchController.clear();
    _invoiceIdController.clear();
    context.read<OwnerInvoiceCubit>().clearFilters();
    setState(() {});
  }

  void _openFilterSheet() {
    HapticFeedback.selectionClick();
    final cubit = context.read<OwnerInvoiceCubit>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => BlocProvider.value(
        value: cubit,
        child: _FilterSheet(
          invoiceIdController: _invoiceIdController,
          onInvoiceIdChanged: _onInvoiceIdChanged,
          onSelectDateRange: () => _selectDateRange(sheetContext),
          onClear: () {
            _clearFilters();
            Navigator.of(sheetContext).pop();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OwnerInvoiceCubit, OwnerInvoiceState>(
      listenWhen: (p, c) => p.hasFilters && !c.hasFilters,
      listener: (context, state) {
        // Filters cleared elsewhere (e.g. app bar): reset the text fields.
        _searchController.clear();
        _invoiceIdController.clear();
      },
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.fromLTRB(
            AppUIConstants.spacingLg,
            AppUIConstants.spacingMd,
            AppUIConstants.spacingLg,
            AppUIConstants.spacingSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SearchField(
                      controller: _searchController,
                      hintText: 'Search resident name or phone',
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  const SizedBox(width: AppUIConstants.spacingSm),
                  _FilterButton(
                    count: state.activeFilterCount,
                    onTap: _openFilterSheet,
                  ),
                ],
              ),
              const SizedBox(height: AppUIConstants.spacingMd),
              _StatusSegments(
                selected: state.paymentFilter,
                onChanged: (f) {
                  HapticFeedback.selectionClick();
                  context.read<OwnerInvoiceCubit>().filterByPaymentStatus(f);
                },
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: Alignment.topLeft,
                child: _ActiveChips(state: state, onClear: _clearFilters),
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
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppUIConstants.bodyLg,
        cursorColor: AppUIConstants.primaryLight,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppUIConstants.bodySm.copyWith(
            color: AppUIConstants.textTertiary,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: AppUIConstants.textTertiary,
          ),
          suffixIcon: value.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
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
          fillColor: AppUIConstants.surface,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppUIConstants.spacingMd,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
            borderSide: const BorderSide(color: AppUIConstants.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
            borderSide: const BorderSide(color: AppUIConstants.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
            borderSide: const BorderSide(color: AppUIConstants.primaryLight),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Filter button (opens sheet) with badge
// =============================================================================

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: active
                  ? AppUIConstants.primarySoft
                  : AppUIConstants.surface,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
              border: Border.all(
                color: active
                    ? AppUIConstants.primaryLight
                    : AppUIConstants.border,
              ),
            ),
            child: Icon(
              Icons.tune_rounded,
              size: 20,
              color: active
                  ? AppUIConstants.primaryLight
                  : AppUIConstants.textSecondary,
            ),
          ),
          if (active)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppUIConstants.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Segmented payment status control
// =============================================================================

class _StatusSegments extends StatelessWidget {
  const _StatusSegments({required this.selected, required this.onChanged});

  final InvoicePaymentFilter selected;
  final ValueChanged<InvoicePaymentFilter> onChanged;

  String _label(InvoicePaymentFilter f) {
    switch (f) {
      case InvoicePaymentFilter.all:
        return 'All';
      case InvoicePaymentFilter.paid:
        return 'Paid';
      case InvoicePaymentFilter.pending:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Row(
        children: InvoicePaymentFilter.values.map((f) {
          final isSel = f == selected;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 9),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSel ? AppUIConstants.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
                ),
                child: Text(
                  _label(f),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    color: isSel ? Colors.white : AppUIConstants.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// =============================================================================
// Active filter chips (summary of what's applied)
// =============================================================================

class _ActiveChips extends StatelessWidget {
  const _ActiveChips({required this.state, required this.onClear});

  final OwnerInvoiceState state;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (!state.hasFilters) return const SizedBox(width: double.infinity);
    final fmt = DateFormat('d MMM');
    final chips = <String>[
      if (state.selectedMonth != null) state.formatMonth(state.selectedMonth!),
      if (state.dateRangeStart != null && state.dateRangeEnd != null)
        '${fmt.format(state.dateRangeStart!)} - ${fmt.format(state.dateRangeEnd!)}',
      if (state.invoiceIdSearch.isNotEmpty) '#${state.invoiceIdSearch}',
      if (state.selectedStudentName != null) state.selectedStudentName!,
    ];
    return Padding(
      padding: const EdgeInsets.only(top: AppUIConstants.spacingMd),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final c in chips)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppUIConstants.primarySoft,
                borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
              ),
              child: Text(
                c,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppUIConstants.primaryLight,
                ),
              ),
            ),
          GestureDetector(
            onTap: onClear,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                'Clear all',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppUIConstants.error,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Filter bottom sheet
// =============================================================================

class _FilterSheet extends StatelessWidget {
  const _FilterSheet({
    required this.invoiceIdController,
    required this.onInvoiceIdChanged,
    required this.onSelectDateRange,
    required this.onClear,
  });

  final TextEditingController invoiceIdController;
  final ValueChanged<String> onInvoiceIdChanged;
  final VoidCallback onSelectDateRange;
  final VoidCallback onClear;

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t.toUpperCase(), style: AppUIConstants.caption),
  );

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OwnerInvoiceCubit, OwnerInvoiceState>(
      builder: (context, state) {
        final cubit = context.read<OwnerInvoiceCubit>();
        final hasRange =
            state.dateRangeStart != null && state.dateRangeEnd != null;
        final fmt = DateFormat('d MMM yyyy');
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: AppUIConstants.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppUIConstants.radiusXl),
            ),
            border: Border(top: BorderSide(color: AppUIConstants.border)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            10,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppUIConstants.disabled,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Filter invoices',
                        style: AppUIConstants.headingMd,
                      ),
                    ),
                    if (state.hasFilters)
                      TextButton(
                        onPressed: onClear,
                        child: const Text(
                          'Reset',
                          style: TextStyle(color: AppUIConstants.error),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _label('Invoice number'),
                _SearchField(
                  controller: invoiceIdController,
                  hintText: 'e.g. INV-2026-0012',
                  onChanged: onInvoiceIdChanged,
                ),
                const SizedBox(height: 18),
                _label('Date range'),
                InkWell(
                  onTap: onSelectDateRange,
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppUIConstants.background,
                      borderRadius: BorderRadius.circular(
                        AppUIConstants.radiusMd,
                      ),
                      border: Border.all(
                        color: hasRange
                            ? AppUIConstants.primaryLight
                            : AppUIConstants.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.date_range_rounded,
                          size: 18,
                          color: AppUIConstants.primaryLight,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            hasRange
                                ? '${fmt.format(state.dateRangeStart!)}  -  ${fmt.format(state.dateRangeEnd!)}'
                                : 'Select a date range',
                            style: hasRange
                                ? AppUIConstants.bodyLg
                                : AppUIConstants.bodyMd,
                          ),
                        ),
                        if (hasRange)
                          GestureDetector(
                            onTap: () => cubit.filterByDateRange(null, null),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: AppUIConstants.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _label('Billing month'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Chip(
                      label: 'All months',
                      selected: state.selectedMonth == null,
                      onTap: () => cubit.filterByMonth(null),
                    ),
                    for (final m in state.availableMonths)
                      _Chip(
                        label: state.formatMonth(m),
                        selected: state.selectedMonth == m,
                        onTap: () => cubit.filterByMonth(m),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                _label('Payment status'),
                _StatusSegments(
                  selected: state.paymentFilter,
                  onChanged: (f) {
                    HapticFeedback.selectionClick();
                    cubit.filterByPaymentStatus(f);
                  },
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: AppUIConstants.primaryButtonStyle,
                    child: Text(
                      'Show ${state.filteredInvoices.length} invoice'
                      '${state.filteredInvoices.length == 1 ? '' : 's'}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppUIConstants.primarySoft
              : AppUIConstants.surfaceMuted,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
          border: Border.all(
            color: selected
                ? AppUIConstants.primaryLight
                : AppUIConstants.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected
                ? AppUIConstants.primaryLight
                : AppUIConstants.textSecondary,
          ),
        ),
      ),
    );
  }
}
