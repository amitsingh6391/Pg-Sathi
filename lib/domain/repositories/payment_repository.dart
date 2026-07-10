import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/payment.dart';

/// Repository interface for Payment aggregate.
abstract class PaymentRepository {
  /// Creates a new payment record.
  Future<Either<Failure, Payment>> createPayment(Payment payment);

  /// Retrieves a payment by ID.
  Future<Either<Failure, Payment>> getPaymentById(String paymentId);

  /// Retrieves payment by membership ID.
  Future<Either<Failure, Payment?>> getPaymentByMembershipId(
    String membershipId,
  );

  /// Retrieves all payments for a membership ID.
  /// Returns list of payments sorted by creation date (oldest first).
  /// Used to calculate cumulative payments for partial payment tracking.
  Future<Either<Failure, List<Payment>>> getPaymentsByMembershipId(
    String membershipId,
  );

  /// Retrieves pending payments by membership ID.
  Future<Either<Failure, Payment?>> getPendingPaymentByMembershipId(
    String membershipId,
  );

  /// Updates a payment record.
  Future<Either<Failure, Payment>> updatePayment(Payment payment);

  /// Retrieves all expired pending payments.
  Future<Either<Failure, List<Payment>>> getExpiredPendingPayments(
    DateTime currentTime,
  );

  /// Retrieves all pending cash payments for a library.
  /// Used by owner to see payments awaiting approval.
  Future<Either<Failure, List<Payment>>> getPendingCashPayments(
    String libraryId,
  );

  /// Retrieves all pending payments requiring approval (cash + UPI).
  /// Used by owner to see all payments awaiting approval.
  Future<Either<Failure, List<Payment>>> getPendingApprovalPayments(
    String libraryId,
  );

  /// Retrieves completed payments for a library within a date range.
  /// Used for revenue analytics.
  Future<Either<Failure, List<Payment>>> getCompletedPayments({
    required String libraryId,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Retrieves all payments for a library.
  /// Used for admin operations.
  Future<Either<Failure, List<Payment>>> getPaymentsByLibraryId(
    String libraryId,
  );

  /// Deletes a payment by ID.
  /// Used for admin cleanup operations.
  Future<Either<Failure, void>> deletePayment(String paymentId);
}
