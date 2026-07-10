import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/invoice.dart';
import '../repositories/invoice_repository.dart';

/// Use case for getting all invoices for a library owner.
class GetInvoicesForOwner
    implements UseCase<List<Invoice>, GetInvoicesForOwnerParams> {
  const GetInvoicesForOwner({required this.invoiceRepository});

  final InvoiceRepository invoiceRepository;

  @override
  Future<Either<Failure, List<Invoice>>> call(
    GetInvoicesForOwnerParams params,
  ) async {
    return invoiceRepository.getInvoicesForOwner(params.ownerId);
  }
}

/// Parameters for GetInvoicesForOwner use case.
class GetInvoicesForOwnerParams extends Equatable {
  const GetInvoicesForOwnerParams({required this.ownerId});

  final String ownerId;

  @override
  List<Object?> get props => [ownerId];
}
