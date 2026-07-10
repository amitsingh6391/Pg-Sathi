import 'package:equatable/equatable.dart';

import '../../../domain/entities/invoice.dart';

/// Status for invoice operations.
enum InvoiceStatus { initial, loading, loaded, downloading, error }

/// State for InvoiceCubit.
class InvoiceState extends Equatable {
  const InvoiceState({
    this.status = InvoiceStatus.initial,
    this.invoices = const [],
    this.errorMessage,
    this.downloadingInvoiceId,
  });

  final InvoiceStatus status;
  final List<Invoice> invoices;
  final String? errorMessage;
  final String? downloadingInvoiceId;

  bool get isLoading => status == InvoiceStatus.loading;
  bool get isLoaded => status == InvoiceStatus.loaded;
  bool get isDownloading => status == InvoiceStatus.downloading;
  bool get isError => status == InvoiceStatus.error;
  bool get hasInvoices => invoices.isNotEmpty;

  bool isDownloadingInvoice(String invoiceId) =>
      isDownloading && downloadingInvoiceId == invoiceId;

  InvoiceState copyWith({
    InvoiceStatus? status,
    List<Invoice>? invoices,
    String? errorMessage,
    String? downloadingInvoiceId,
  }) {
    return InvoiceState(
      status: status ?? this.status,
      invoices: invoices ?? this.invoices,
      errorMessage: errorMessage ?? this.errorMessage,
      downloadingInvoiceId: downloadingInvoiceId,
    );
  }

  @override
  List<Object?> get props => [
    status,
    invoices,
    errorMessage,
    downloadingInvoiceId,
  ];
}
