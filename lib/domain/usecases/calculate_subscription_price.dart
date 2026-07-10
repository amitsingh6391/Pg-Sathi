import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/subscription_plan.dart';
import '../failures/subscription_failures.dart';

/// Result of subscription price calculation.
class SubscriptionPriceResult extends Equatable {
  const SubscriptionPriceResult({
    required this.plan,
    required this.seatCount,
    required this.durationInMonths,
    required this.baseMonthlyPrice,
    required this.grossAmount,
    required this.discountPercent,
    required this.discountAmount,
    required this.finalAmount,
    this.adminDiscountPercent,
    this.adminDiscountAmount,
  });

  final SubscriptionPlan plan;
  final int seatCount;
  final int durationInMonths;
  final double baseMonthlyPrice;
  final double grossAmount;
  final double discountPercent; // Duration discount
  final double discountAmount; // Duration discount amount
  final double finalAmount;
  final double? adminDiscountPercent; // Admin-applied discount
  final double? adminDiscountAmount; // Admin discount amount

  @override
  List<Object?> get props => [
    plan,
    seatCount,
    durationInMonths,
    baseMonthlyPrice,
    grossAmount,
    discountPercent,
    discountAmount,
    finalAmount,
    adminDiscountPercent,
    adminDiscountAmount,
  ];
}

/// Use case for calculating subscription price based on seats and duration.
///
/// Pricing Rules (Updated January 2026 - Revised):
/// - 1-49 seats → ₹149/month
/// - 50-99 seats → ₹249/month
/// - 100-149 seats → ₹299/month
/// - 150-199 seats → ₹349/month
/// - 200-249 seats → ₹399/month
/// - 250-299 seats → ₹449/month
/// - 300-349 seats → ₹499/month
/// - 350+ seats → ₹699/month
///
/// Duration Discounts:
/// - 12 months → 5% discount
///
/// Free Trial: 3 days
class CalculateSubscriptionPrice
    implements
        UseCase<SubscriptionPriceResult, CalculateSubscriptionPriceParams> {
  const CalculateSubscriptionPrice();

  @override
  Future<Either<Failure, SubscriptionPriceResult>> call(
    CalculateSubscriptionPriceParams params,
  ) async {
    // Validate seat count
    if (params.seatCount <= 0) {
      return const Left(InvalidSeatCountFailure());
    }

    // Validate duration
    if (!SubscriptionPlan.availableDurations.contains(
      params.durationInMonths,
    )) {
      return const Left(InvalidDurationFailure());
    }

    // Get plan based on seat count (for default pricing)
    final plan = SubscriptionPlan.getPlanForSeats(params.seatCount);

    // Add custom library price to default plan price (if provided)
    final baseMonthlyPrice =
        plan.monthlyPrice + (params.customLibraryPrice ?? 0);

    // Calculate gross amount (before discount)
    final grossAmount = baseMonthlyPrice * params.durationInMonths;

    // Get discount for duration
    final discountPercent = SubscriptionPlan.getDiscountForDuration(
      params.durationInMonths,
    );

    // Calculate duration discount amount
    final discountAmount = grossAmount * (discountPercent / 100);

    // Calculate amount after duration discount
    var finalAmount = grossAmount - discountAmount;

    // Apply admin discount if provided and valid
    double? adminDiscountPercent;
    double? adminDiscountAmount;
    if (params.adminDiscountPercent != null &&
        params.adminDiscountPercent! > 0) {
      adminDiscountPercent = params.adminDiscountPercent;
      adminDiscountAmount = finalAmount * (adminDiscountPercent! / 100);
      finalAmount = finalAmount - adminDiscountAmount;
    }

    return Right(
      SubscriptionPriceResult(
        plan: plan,
        seatCount: params.seatCount,
        durationInMonths: params.durationInMonths,
        baseMonthlyPrice: baseMonthlyPrice,
        grossAmount: grossAmount,
        discountPercent: discountPercent,
        discountAmount: discountAmount,
        finalAmount: finalAmount,
        adminDiscountPercent: adminDiscountPercent,
        adminDiscountAmount: adminDiscountAmount,
      ),
    );
  }
}

/// Parameters for CalculateSubscriptionPrice use case.
class CalculateSubscriptionPriceParams extends Equatable {
  const CalculateSubscriptionPriceParams({
    required this.seatCount,
    required this.durationInMonths,
    this.customLibraryPrice,
    this.adminDiscountPercent,
  });

  final int seatCount;
  final int durationInMonths;

  /// Custom monthly price for specific library (overrides default tier pricing)
  final double? customLibraryPrice;

  /// Admin-applied discount percentage (from Library.activeDiscountPercent)
  final double? adminDiscountPercent;

  @override
  List<Object?> get props => [
    seatCount,
    durationInMonths,
    customLibraryPrice,
    adminDiscountPercent,
  ];
}
