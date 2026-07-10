import 'package:dartz/dartz.dart';

import '../core/failure.dart';

/// Abstract payment gateway interface.
/// Implemented by data layer for online payment processing.
/// Domain layer depends on this abstraction, not concrete implementation.
abstract class PaymentGateway {
  /// Creates an order in the payment gateway.
  /// Returns the gateway order ID.
  Future<Either<Failure, PaymentOrder>> createOrder({
    required double amount,
    required String currency,
    required String receiptId,
    Map<String, dynamic>? notes,
  });

  /// Verifies a payment signature from the gateway.
  Future<Either<Failure, bool>> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  });
}

/// Represents a payment order from the gateway.
class PaymentOrder {
  const PaymentOrder({
    required this.orderId,
    required this.amount,
    required this.currency,
    this.isLocalOrder = false,
  });

  final String orderId;
  final double amount;
  final String currency;

  /// True if this is a local order reference (MVP mode without server).
  /// False if this is a real payment gateway order created via server API.
  final bool isLocalOrder;
}
