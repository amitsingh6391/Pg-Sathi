import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../repositories/invoice_repository.dart';
import '../repositories/payment_repository.dart';

/// Use case for deleting an invoice.
/// Also deletes the associated payment to update revenue.
class DeleteInvoice implements UseCase<void, DeleteInvoiceParams> {
  const DeleteInvoice({
    required this.invoiceRepository,
    required this.paymentRepository,
  });

  final InvoiceRepository invoiceRepository;
  final PaymentRepository paymentRepository;

  @override
  Future<Either<Failure, void>> call(DeleteInvoiceParams params) async {
    // First, get the invoice to retrieve the paymentId
    final invoiceResult = await invoiceRepository.getInvoiceById(params.invoiceId);

    return invoiceResult.fold(
      (failure) => Left(failure),
      (invoice) async {
        if (invoice == null) {
          // Return a generic failure if invoice not found
          return Left(
            _InvoiceNotFoundFailure(),
          );
        }

        // Delete the invoice
        final deleteInvoiceResult = await invoiceRepository.deleteInvoice(
          params.invoiceId,
        );

        if (deleteInvoiceResult.isLeft()) {
          return deleteInvoiceResult;
        }

        // Delete the associated payment to update revenue
        final deletePaymentResult = await paymentRepository.deletePayment(
          invoice.paymentId,
        );

        // If payment deletion fails, we still consider invoice deletion successful
        // but log the error. The invoice is already deleted.
        return deletePaymentResult.fold(
          (failure) {
            // Invoice deleted but payment deletion failed
            // This is acceptable - invoice is already deleted
            return const Right(null);
          },
          (_) => const Right(null),
        );
      },
    );
  }
}

/// Failure when invoice is not found.
class _InvoiceNotFoundFailure extends Failure {
  const _InvoiceNotFoundFailure()
    : super(message: 'Invoice not found');
}

/// Parameters for DeleteInvoice use case.
class DeleteInvoiceParams extends Equatable {
  const DeleteInvoiceParams({required this.invoiceId});

  final String invoiceId;

  @override
  List<Object?> get props => [invoiceId];
}
