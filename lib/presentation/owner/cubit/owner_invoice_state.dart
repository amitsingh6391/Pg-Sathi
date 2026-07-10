import 'package:equatable/equatable.dart';

import '../../../domain/entities/invoice.dart';

/// Status for owner invoice operations.
enum OwnerInvoiceStatus { initial, loading, loaded, downloading, error }

/// Payment status filter options.
enum InvoicePaymentFilter { all, paid, pending }

/// Simple student info for filtering.
class StudentInfo extends Equatable {
  const StudentInfo({required this.id, required this.name, this.phone = ''});

  final String id;
  final String name;
  final String phone;

  @override
  List<Object?> get props => [id, name, phone];
}

/// State for OwnerInvoiceCubit.
/// Enhanced with advanced filtering options.
class OwnerInvoiceState extends Equatable {
  const OwnerInvoiceState({
    this.status = OwnerInvoiceStatus.initial,
    this.allInvoices = const [],
    this.filteredInvoices = const [],
    this.students = const [],
    this.availableMonths = const [],
    this.selectedStudentId,
    this.selectedMonth,
    this.searchQuery = '',
    this.invoiceIdSearch = '',
    this.dateRangeStart,
    this.dateRangeEnd,
    this.paymentFilter = InvoicePaymentFilter.all,
    this.errorMessage,
    this.downloadingInvoiceId,
  });

  final OwnerInvoiceStatus status;
  final List<Invoice> allInvoices;
  final List<Invoice> filteredInvoices;
  final List<StudentInfo> students;
  final List<String> availableMonths;
  final String? selectedStudentId;
  final String? selectedMonth;
  final String searchQuery;
  final String invoiceIdSearch;
  final DateTime? dateRangeStart;
  final DateTime? dateRangeEnd;
  final InvoicePaymentFilter paymentFilter;
  final String? errorMessage;
  final String? downloadingInvoiceId;

  bool get isLoading => status == OwnerInvoiceStatus.loading;
  bool get isLoaded => status == OwnerInvoiceStatus.loaded;
  bool get isDownloading => status == OwnerInvoiceStatus.downloading;
  bool get isError => status == OwnerInvoiceStatus.error;
  bool get hasInvoices => filteredInvoices.isNotEmpty;

  bool get hasFilters =>
      selectedStudentId != null ||
      selectedMonth != null ||
      searchQuery.isNotEmpty ||
      invoiceIdSearch.isNotEmpty ||
      dateRangeStart != null ||
      dateRangeEnd != null ||
      paymentFilter != InvoicePaymentFilter.all;

  int get activeFilterCount {
    var count = 0;
    if (selectedStudentId != null) count++;
    if (selectedMonth != null) count++;
    if (searchQuery.isNotEmpty) count++;
    if (invoiceIdSearch.isNotEmpty) count++;
    if (dateRangeStart != null || dateRangeEnd != null) count++;
    if (paymentFilter != InvoicePaymentFilter.all) count++;
    return count;
  }

  bool isDownloadingInvoice(String invoiceId) =>
      isDownloading && downloadingInvoiceId == invoiceId;

  /// Get selected student name for display.
  String? get selectedStudentName {
    if (selectedStudentId == null) return null;
    final student = students.cast<StudentInfo?>().firstWhere(
      (s) => s?.id == selectedStudentId,
      orElse: () => null,
    );
    return student?.name;
  }

  /// Get matching students for search query.
  List<StudentInfo> get matchingStudents {
    if (searchQuery.isEmpty) return [];
    final query = searchQuery.toLowerCase();
    return students
        .where((s) {
          return s.name.toLowerCase().contains(query) ||
              s.phone.contains(query);
        })
        .take(5)
        .toList();
  }

  /// Format month for display.
  String formatMonth(String billingMonth) {
    final parts = billingMonth.split('-');
    if (parts.length != 2) return billingMonth;

    final year = parts[0];
    final month = int.tryParse(parts[1]) ?? 1;

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[month - 1]} $year';
  }

  OwnerInvoiceState copyWith({
    OwnerInvoiceStatus? status,
    List<Invoice>? allInvoices,
    List<Invoice>? filteredInvoices,
    List<StudentInfo>? students,
    List<String>? availableMonths,
    String? selectedStudentId,
    bool clearStudentId = false,
    String? selectedMonth,
    bool clearMonth = false,
    String? searchQuery,
    String? invoiceIdSearch,
    DateTime? dateRangeStart,
    bool clearDateRangeStart = false,
    DateTime? dateRangeEnd,
    bool clearDateRangeEnd = false,
    InvoicePaymentFilter? paymentFilter,
    String? errorMessage,
    String? downloadingInvoiceId,
  }) {
    return OwnerInvoiceState(
      status: status ?? this.status,
      allInvoices: allInvoices ?? this.allInvoices,
      filteredInvoices: filteredInvoices ?? this.filteredInvoices,
      students: students ?? this.students,
      availableMonths: availableMonths ?? this.availableMonths,
      selectedStudentId: clearStudentId
          ? null
          : (selectedStudentId ?? this.selectedStudentId),
      selectedMonth: clearMonth ? null : (selectedMonth ?? this.selectedMonth),
      searchQuery: searchQuery ?? this.searchQuery,
      invoiceIdSearch: invoiceIdSearch ?? this.invoiceIdSearch,
      dateRangeStart: clearDateRangeStart
          ? null
          : (dateRangeStart ?? this.dateRangeStart),
      dateRangeEnd: clearDateRangeEnd
          ? null
          : (dateRangeEnd ?? this.dateRangeEnd),
      paymentFilter: paymentFilter ?? this.paymentFilter,
      errorMessage: errorMessage ?? this.errorMessage,
      downloadingInvoiceId: downloadingInvoiceId,
    );
  }

  @override
  List<Object?> get props => [
    status,
    allInvoices,
    filteredInvoices,
    students,
    availableMonths,
    selectedStudentId,
    selectedMonth,
    searchQuery,
    invoiceIdSearch,
    dateRangeStart,
    dateRangeEnd,
    paymentFilter,
    errorMessage,
    downloadingInvoiceId,
  ];
}
