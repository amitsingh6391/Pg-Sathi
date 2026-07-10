import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/invoice.dart';
import '../../../domain/entities/library_summary.dart';
import '../../../domain/usecases/get_admin_invoices.dart';

part 'admin_invoices_state.dart';

/// Cubit for managing admin invoice access.
/// Provides read-only access to all invoices with filters.
class AdminInvoicesCubit extends Cubit<AdminInvoicesState> {
  AdminInvoicesCubit({required this.getAdminInvoices})
    : super(const AdminInvoicesState());

  final GetAdminInvoices getAdminInvoices;

  /// Loads all invoices without filters.
  Future<void> loadInvoices() async {
    emit(state.copyWith(status: AdminInvoicesStatus.loading));

    final result = await getAdminInvoices(const GetAdminInvoicesParams());

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: AdminInvoicesStatus.error,
          errorMessage: failure.message ?? 'Failed to load invoices',
        ),
      ),
      (invoices) => emit(
        state.copyWith(
          status: AdminInvoicesStatus.loaded,
          invoices: invoices,
          filteredInvoices: invoices,
        ),
      ),
    );
  }

  /// Loads invoices with filters.
  Future<void> loadInvoicesWithFilters({
    String? libraryId,
    String? ownerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    emit(state.copyWith(status: AdminInvoicesStatus.loading));

    final result = await getAdminInvoices(
      GetAdminInvoicesParams(
        libraryId: libraryId,
        ownerId: ownerId,
        startDate: startDate,
        endDate: endDate,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: AdminInvoicesStatus.error,
          errorMessage: failure.message ?? 'Failed to load invoices',
        ),
      ),
      (invoices) => emit(
        state.copyWith(
          status: AdminInvoicesStatus.loaded,
          invoices: invoices,
          filteredInvoices: invoices,
          selectedLibraryId: libraryId,
          selectedOwnerId: ownerId,
          startDate: startDate,
          endDate: endDate,
        ),
      ),
    );
  }

  /// Sets available libraries for filter dropdown.
  void setAvailableLibraries(List<LibrarySummary> libraries) {
    emit(state.copyWith(availableLibraries: libraries));
  }

  /// Applies library filter.
  void filterByLibrary(String? libraryId) {
    if (libraryId == null || libraryId.isEmpty) {
      emit(
        state.copyWith(
          selectedLibraryId: null,
          filteredInvoices: _applyFilters(
            invoices: state.invoices,
            startDate: state.startDate,
            endDate: state.endDate,
          ),
        ),
      );
    } else {
      emit(
        state.copyWith(
          selectedLibraryId: libraryId,
          filteredInvoices: _applyFilters(
            invoices: state.invoices,
            libraryId: libraryId,
            startDate: state.startDate,
            endDate: state.endDate,
          ),
        ),
      );
    }
  }

  /// Applies date range filter.
  void filterByDateRange(DateTime? startDate, DateTime? endDate) {
    emit(
      state.copyWith(
        startDate: startDate,
        endDate: endDate,
        filteredInvoices: _applyFilters(
          invoices: state.invoices,
          libraryId: state.selectedLibraryId,
          startDate: startDate,
          endDate: endDate,
        ),
      ),
    );
  }

  /// Clears all filters.
  void clearFilters() {
    emit(
      state.copyWith(
        selectedLibraryId: null,
        selectedOwnerId: null,
        startDate: null,
        endDate: null,
        filteredInvoices: state.invoices,
      ),
    );
  }

  /// Applies search query to filtered invoices.
  void searchInvoices(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  /// Applies all filters to invoice list.
  List<Invoice> _applyFilters({
    required List<Invoice> invoices,
    String? libraryId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    var filtered = invoices;

    if (libraryId != null && libraryId.isNotEmpty) {
      filtered = filtered.where((i) => i.libraryId == libraryId).toList();
    }

    if (startDate != null) {
      filtered = filtered
          .where(
            (i) =>
                i.generatedAt.isAfter(startDate) ||
                i.generatedAt.isAtSameMomentAs(startDate),
          )
          .toList();
    }

    if (endDate != null) {
      final endOfDay = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        23,
        59,
        59,
      );
      filtered = filtered
          .where(
            (i) =>
                i.generatedAt.isBefore(endOfDay) ||
                i.generatedAt.isAtSameMomentAs(endOfDay),
          )
          .toList();
    }

    return filtered;
  }
}
