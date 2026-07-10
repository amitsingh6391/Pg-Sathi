part of 'admin_invoices_cubit.dart';

/// Status for admin invoices operations.
enum AdminInvoicesStatus { initial, loading, loaded, error }

/// State for admin invoice access.
class AdminInvoicesState extends Equatable {
  const AdminInvoicesState({
    this.status = AdminInvoicesStatus.initial,
    this.invoices = const [],
    this.filteredInvoices = const [],
    this.availableLibraries = const [],
    this.selectedLibraryId,
    this.selectedOwnerId,
    this.startDate,
    this.endDate,
    this.searchQuery = '',
    this.errorMessage,
  });

  final AdminInvoicesStatus status;
  final List<Invoice> invoices;
  final List<Invoice> filteredInvoices;
  final List<LibrarySummary> availableLibraries;
  final String? selectedLibraryId;
  final String? selectedOwnerId;
  final DateTime? startDate;
  final DateTime? endDate;
  final String searchQuery;
  final String? errorMessage;

  /// Whether data is currently loading.
  bool get isLoading => status == AdminInvoicesStatus.loading;

  /// Whether there was an error.
  bool get hasError => status == AdminInvoicesStatus.error;

  /// Whether data is loaded.
  bool get isLoaded => status == AdminInvoicesStatus.loaded;

  /// Total amount of filtered invoices.
  double get totalAmount {
    return filteredInvoices.fold(
      0.0,
      (sum, invoice) => sum + invoice.amountPaid,
    );
  }

  /// Invoices filtered by search query.
  List<Invoice> get searchedInvoices {
    if (searchQuery.isEmpty) return filteredInvoices;

    final query = searchQuery.toLowerCase();
    return filteredInvoices.where((invoice) {
      return invoice.invoiceNumber.toLowerCase().contains(query) ||
          invoice.studentName.toLowerCase().contains(query) ||
          invoice.libraryName.toLowerCase().contains(query) ||
          invoice.studentPhone.contains(query);
    }).toList();
  }

  /// Gets the selected library name.
  String? get selectedLibraryName {
    if (selectedLibraryId == null) return null;
    final library = availableLibraries.where(
      (l) => l.libraryId == selectedLibraryId,
    );
    return library.isNotEmpty ? library.first.libraryName : null;
  }

  AdminInvoicesState copyWith({
    AdminInvoicesStatus? status,
    List<Invoice>? invoices,
    List<Invoice>? filteredInvoices,
    List<LibrarySummary>? availableLibraries,
    String? selectedLibraryId,
    String? selectedOwnerId,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
    String? errorMessage,
  }) {
    return AdminInvoicesState(
      status: status ?? this.status,
      invoices: invoices ?? this.invoices,
      filteredInvoices: filteredInvoices ?? this.filteredInvoices,
      availableLibraries: availableLibraries ?? this.availableLibraries,
      selectedLibraryId: selectedLibraryId,
      selectedOwnerId: selectedOwnerId,
      startDate: startDate,
      endDate: endDate,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    invoices,
    filteredInvoices,
    availableLibraries,
    selectedLibraryId,
    selectedOwnerId,
    startDate,
    endDate,
    searchQuery,
    errorMessage,
  ];
}
