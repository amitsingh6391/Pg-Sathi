import 'dart:ui' show Rect;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../data/services/invoice_pdf_service.dart';
import '../../../data/services/review_prompt_service.dart';
import '../../../domain/entities/invoice.dart';
import '../../../domain/usecases/delete_invoice.dart';
import '../../../domain/usecases/get_invoices_for_owner.dart';
import 'owner_invoice_state.dart';

/// Cubit for managing owner invoices with advanced filtering.
class OwnerInvoiceCubit extends Cubit<OwnerInvoiceState> {
  OwnerInvoiceCubit({
    required this.getInvoicesForOwner,
    required this.pdfService,
    required this.deleteInvoice,
  }) : super(const OwnerInvoiceState());

  final GetInvoicesForOwner getInvoicesForOwner;
  final InvoicePdfService pdfService;
  final DeleteInvoice deleteInvoice;

  /// Load all invoices for an owner.
  Future<void> loadInvoices(String ownerId) async {
    emit(state.copyWith(status: OwnerInvoiceStatus.loading));

    final result = await getInvoicesForOwner(
      GetInvoicesForOwnerParams(ownerId: ownerId),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: OwnerInvoiceStatus.error,
          errorMessage: failure.message ?? 'Failed to load invoices',
        ),
      ),
      (invoices) {
        // Extract unique students and months for filtering
        final students = _extractUniqueStudents(invoices);
        final months = _extractUniqueMonths(invoices);

        emit(
          state.copyWith(
            status: OwnerInvoiceStatus.loaded,
            allInvoices: invoices,
            filteredInvoices: invoices,
            students: students,
            availableMonths: months,
          ),
        );
      },
    );
  }

  /// Filter by student.
  void filterByStudent(String? studentId) {
    emit(
      state.copyWith(
        selectedStudentId: studentId,
        clearStudentId: studentId == null,
      ),
    );
    _applyFilters();
  }

  /// Filter by month.
  void filterByMonth(String? billingMonth) {
    emit(
      state.copyWith(
        selectedMonth: billingMonth,
        clearMonth: billingMonth == null,
      ),
    );
    _applyFilters();
  }

  /// Search by student name or phone.
  void search(String query) {
    emit(state.copyWith(searchQuery: query));
    _applyFilters();
  }

  /// Search by invoice ID.
  void searchInvoiceId(String invoiceId) {
    emit(state.copyWith(invoiceIdSearch: invoiceId));
    _applyFilters();
  }

  /// Filter by date range.
  void filterByDateRange(DateTime? start, DateTime? end) {
    emit(
      state.copyWith(
        dateRangeStart: start,
        dateRangeEnd: end,
        clearDateRangeStart: start == null,
        clearDateRangeEnd: end == null,
      ),
    );
    _applyFilters();
  }

  /// Filter by payment status.
  void filterByPaymentStatus(InvoicePaymentFilter filter) {
    emit(state.copyWith(paymentFilter: filter));
    _applyFilters();
  }

  /// Clear all filters.
  void clearFilters() {
    emit(
      state.copyWith(
        clearStudentId: true,
        clearMonth: true,
        searchQuery: '',
        invoiceIdSearch: '',
        clearDateRangeStart: true,
        clearDateRangeEnd: true,
        paymentFilter: InvoicePaymentFilter.all,
        filteredInvoices: state.allInvoices,
      ),
    );
  }

  void _applyFilters() {
    var filtered = state.allInvoices;

    // Filter by student
    if (state.selectedStudentId != null) {
      filtered = filtered
          .where((inv) => inv.studentId == state.selectedStudentId)
          .toList();
    }

    // Filter by search query (name or phone)
    if (state.searchQuery.isNotEmpty) {
      final query = state.searchQuery.toLowerCase();
      filtered = filtered.where((inv) {
        return inv.studentName.toLowerCase().contains(query) ||
            inv.studentPhone.contains(query);
      }).toList();
    }

    // Filter by invoice ID
    if (state.invoiceIdSearch.isNotEmpty) {
      final query = state.invoiceIdSearch.toLowerCase();
      filtered = filtered.where((inv) {
        return inv.invoiceNumber.toLowerCase().contains(query) ||
            inv.id.toLowerCase().contains(query);
      }).toList();
    }

    // Filter by month
    if (state.selectedMonth != null) {
      filtered = filtered
          .where((inv) => inv.billingMonth == state.selectedMonth)
          .toList();
    }

    // Filter by date range
    if (state.dateRangeStart != null) {
      filtered = filtered.where((inv) {
        return !inv.paymentDate.isBefore(state.dateRangeStart!);
      }).toList();
    }
    if (state.dateRangeEnd != null) {
      final endOfDay = DateTime(
        state.dateRangeEnd!.year,
        state.dateRangeEnd!.month,
        state.dateRangeEnd!.day,
        23,
        59,
        59,
      );
      filtered = filtered.where((inv) {
        return !inv.paymentDate.isAfter(endOfDay);
      }).toList();
    }

    // Filter by payment status
    // Note: All invoices in the system are paid since they're generated after payment
    // This filter is for future extension when we support pending invoices
    switch (state.paymentFilter) {
      case InvoicePaymentFilter.paid:
        // All invoices are currently paid
        break;
      case InvoicePaymentFilter.pending:
        // No pending invoices currently
        filtered = [];
        break;
      case InvoicePaymentFilter.all:
        break;
    }

    emit(state.copyWith(filteredInvoices: filtered));
  }

  List<StudentInfo> _extractUniqueStudents(List<Invoice> invoices) {
    final studentMap = <String, StudentInfo>{};
    for (final inv in invoices) {
      if (!studentMap.containsKey(inv.studentId)) {
        studentMap[inv.studentId] = StudentInfo(
          id: inv.studentId,
          name: inv.studentName,
          phone: inv.studentPhone,
        );
      }
    }
    final students = studentMap.values.toList();
    students.sort((a, b) => a.name.compareTo(b.name));
    return students;
  }

  List<String> _extractUniqueMonths(List<Invoice> invoices) {
    final months = invoices.map((inv) => inv.billingMonth).toSet().toList();
    months.sort((a, b) => b.compareTo(a)); // Newest first
    return months;
  }

  /// Download and open a PDF invoice.
  Future<void> downloadInvoice(Invoice invoice) async {
    emit(
      state.copyWith(
        status: OwnerInvoiceStatus.downloading,
        downloadingInvoiceId: invoice.id,
      ),
    );

    try {
      await pdfService.generateAndOpen(invoice);

      sl<ReviewPromptService>().recordPositiveAction();

      emit(
        state.copyWith(
          status: OwnerInvoiceStatus.loaded,
          downloadingInvoiceId: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: OwnerInvoiceStatus.error,
          errorMessage: 'Failed to download invoice: ${e.toString()}',
          downloadingInvoiceId: null,
        ),
      );
    }
  }

  /// Share a PDF invoice.
  /// [shareOrigin] is needed for iPad to show share sheet properly.
  Future<void> shareInvoice(Invoice invoice, {Rect? shareOrigin}) async {
    emit(
      state.copyWith(
        status: OwnerInvoiceStatus.downloading,
        downloadingInvoiceId: invoice.id,
      ),
    );

    try {
      await pdfService.generateAndShare(invoice, shareOrigin: shareOrigin);
      emit(
        state.copyWith(
          status: OwnerInvoiceStatus.loaded,
          downloadingInvoiceId: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: OwnerInvoiceStatus.error,
          errorMessage: 'Failed to share invoice: ${e.toString()}',
          downloadingInvoiceId: null,
        ),
      );
    }
  }

  /// Shares an invoice PDF directly to WhatsApp with student's phone number.
  /// On Android: Opens WhatsApp to specific contact. On iOS: Opens share sheet.
  Future<void> shareInvoiceToWhatsApp(Invoice invoice, {Rect? shareOrigin}) async {
    emit(
      state.copyWith(
        status: OwnerInvoiceStatus.downloading,
        downloadingInvoiceId: invoice.id,
      ),
    );

    try {
      await pdfService.shareToWhatsApp(invoice, shareOrigin: shareOrigin);
      emit(
        state.copyWith(
          status: OwnerInvoiceStatus.loaded,
          downloadingInvoiceId: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: OwnerInvoiceStatus.error,
          errorMessage: 'Failed to share via WhatsApp: ${e.toString()}',
          downloadingInvoiceId: null,
        ),
      );
    }
  }

  /// Delete an invoice.
  Future<void> deleteInvoiceById(String invoiceId, String ownerId) async {
    emit(state.copyWith(status: OwnerInvoiceStatus.loading));

    final result = await deleteInvoice(
      DeleteInvoiceParams(invoiceId: invoiceId),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: OwnerInvoiceStatus.error,
          errorMessage: failure.message ?? 'Failed to delete invoice',
        ),
      ),
      (_) {
        // Remove the deleted invoice from both lists
        final updatedAllInvoices = state.allInvoices
            .where((inv) => inv.id != invoiceId)
            .toList();
        final updatedFilteredInvoices = state.filteredInvoices
            .where((inv) => inv.id != invoiceId)
            .toList();

        // Re-extract students and months after deletion
        final students = _extractUniqueStudents(updatedAllInvoices);
        final months = _extractUniqueMonths(updatedAllInvoices);

        emit(
          state.copyWith(
            status: OwnerInvoiceStatus.loaded,
            allInvoices: updatedAllInvoices,
            filteredInvoices: updatedFilteredInvoices,
            students: students,
            availableMonths: months,
          ),
        );
      },
    );
  }
}
