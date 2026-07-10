import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/invoice.dart';

/// Repository interface for Invoice operations.
abstract class InvoiceRepository {
  /// Creates a new invoice.
  /// Returns the created invoice.
  Future<Either<Failure, Invoice>> createInvoice(Invoice invoice);

  /// Gets an invoice by ID.
  Future<Either<Failure, Invoice?>> getInvoiceById(String invoiceId);

  /// Gets invoice by membership ID and billing month.
  /// Used to check if invoice already exists.
  Future<Either<Failure, Invoice?>> getInvoiceByMembershipAndMonth({
    required String membershipId,
    required String billingMonth,
  });

  /// Gets invoice by payment ID.
  /// Used to check if invoice already exists for a specific payment.
  Future<Either<Failure, Invoice?>> getInvoiceByPaymentId(String paymentId);

  /// Gets all invoices for a student.
  /// Returns invoices sorted by generated date (newest first).
  Future<Either<Failure, List<Invoice>>> getInvoicesForStudent(
    String studentId,
  );

  /// Gets all invoices for a library owner.
  /// Returns invoices sorted by generated date (newest first).
  Future<Either<Failure, List<Invoice>>> getInvoicesForOwner(String ownerId);

  /// Gets all invoices for a specific library.
  Future<Either<Failure, List<Invoice>>> getInvoicesForLibrary(
    String libraryId,
  );

  /// Generates the next invoice number.
  Future<Either<Failure, String>> generateInvoiceNumber(String libraryId);

  /// Batch updates invoices to link them to a user ID.
  /// Updates invoices where studentId matches the phone number.
  /// Used when student logs in and invoices need to be linked.
  Future<Either<Failure, void>> batchLinkInvoicesToUser({
    required String phoneNumber,
    required String userId,
  });

  /// Gets invoices by membership IDs.
  /// Used to find invoices for synced memberships.
  Future<Either<Failure, List<Invoice>>> getInvoicesByMembershipIds(
    List<String> membershipIds,
  );

  /// Deletes an invoice by ID.
  Future<Either<Failure, void>> deleteInvoice(String invoiceId);

  /// Updates an invoice.
  /// Used when membership details change (dates, seat, etc.).
  Future<Either<Failure, Invoice>> updateInvoice(Invoice invoice);
}
