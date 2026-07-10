import '../core/failure.dart';

/// Base class for payment-related failures.
abstract class PaymentFailure extends Failure {
  const PaymentFailure({super.message = 'Payment operation failed'});
}

/// Payment not found.
class PaymentNotFoundFailure extends PaymentFailure {
  const PaymentNotFoundFailure({super.message = 'Payment not found'});
}

/// Payment already processed (cannot retry).
class PaymentAlreadyProcessedFailure extends PaymentFailure {
  const PaymentAlreadyProcessedFailure({
    super.message = 'Payment has already been processed',
  });
}

/// Payment expired.
class PaymentExpiredFailure extends PaymentFailure {
  const PaymentExpiredFailure({
    super.message = 'Payment has expired. Please try again.',
  });
}

/// Payment gateway error.
class PaymentGatewayFailure extends PaymentFailure {
  const PaymentGatewayFailure({super.message = 'Payment gateway error'});
}

/// Payment verification failed.
class PaymentVerificationFailure extends PaymentFailure {
  const PaymentVerificationFailure({
    super.message = 'Payment verification failed',
  });
}

/// Reservation not found.
class ReservationNotFoundFailure extends PaymentFailure {
  const ReservationNotFoundFailure({super.message = 'Reservation not found'});
}

/// Reservation already exists for seat+slot.
class ReservationAlreadyExistsFailure extends PaymentFailure {
  const ReservationAlreadyExistsFailure({
    super.message = 'This seat and slot is already reserved',
  });
}

/// Invalid payment amount.
class InvalidPaymentAmountFailure extends PaymentFailure {
  const InvalidPaymentAmountFailure({super.message = 'Invalid payment amount'});
}

/// Payment validation failed.
class PaymentValidationFailure extends PaymentFailure {
  const PaymentValidationFailure({super.message = 'Payment validation failed'});
}
