import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import '../core/core.dart';
import '../entities/referral.dart';
import '../entities/subscription.dart';
import '../entities/subscription_plan.dart';
import '../failures/subscription_failures.dart';
import '../repositories/referral_repository.dart';
import '../repositories/subscription_repository.dart';

/// Use case for creating a new subscription (pending payment).
/// Supports custom per-library pricing for revenue optimization.
class CreateSubscription
    implements UseCase<Subscription, CreateSubscriptionParams> {
  const CreateSubscription({
    required this.subscriptionRepository,
    this.referralRepository,
  });

  final SubscriptionRepository subscriptionRepository;
  final ReferralRepository? referralRepository;

  @override
  Future<Either<Failure, Subscription>> call(
    CreateSubscriptionParams params,
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
        params.baseMonthlyPriceOverride ??
        plan.monthlyPrice + (params.customLibraryPrice ?? 0);

    // Calculate pricing
    final grossAmount = baseMonthlyPrice * params.durationInMonths;
    final discountPercent =
        params.discountPercentOverride ??
        SubscriptionPlan.getDiscountForDuration(params.durationInMonths);
    final discountAmount = grossAmount * (discountPercent / 100);
    var finalAmount =
        params.finalAmountOverride ?? grossAmount - discountAmount;

    // Apply admin discount if provided
    double? adminDiscountPercent;
    double? adminDiscountAmount;
    if (params.adminDiscountPercent != null &&
        params.adminDiscountPercent! > 0) {
      adminDiscountPercent = params.adminDiscountPercent;
      adminDiscountAmount = finalAmount * (adminDiscountPercent! / 100);
      finalAmount = finalAmount - adminDiscountAmount;
    }

    // Apply coupon if provided
    double? couponDiscount;
    if (params.couponCode != null && params.couponCode!.isNotEmpty) {
      final couponResult = await subscriptionRepository.getCouponByCode(
        params.couponCode!,
      );

      final coupon = couponResult.fold((_) => null, (c) => c);

      if (coupon != null && coupon.isValid(DateTime.now())) {
        couponDiscount = coupon.discountPercent;
        final couponDiscountAmount = finalAmount * (couponDiscount / 100);
        finalAmount = finalAmount - couponDiscountAmount;

        // Increment coupon usage
        await subscriptionRepository.updateCoupon(coupon.incrementUsage());
      }
    }

    // Apply referral discount (15%) if provided
    if (params.referralCode != null &&
        params.referralCode!.isNotEmpty &&
        referralRepository != null) {
      final referralResult = await referralRepository!.getReferralByCode(
        params.referralCode!.trim().toUpperCase(),
      );

      final referral = referralResult.fold((_) => null, (r) => r);
      if (referral != null && referral.isActive) {
        const referralDiscountPercent = 15.0;
        final referralDiscountAmount =
            finalAmount * (referralDiscountPercent / 100);
        finalAmount = finalAmount - referralDiscountAmount;

        // Create a pending redemption record
        final redemption = ReferralRedemption(
          id: const Uuid().v4(),
          referralCode: referral.code,
          referrerId: referral.ownerId,
          refereeId: params.ownerId,
          status: ReferralRedemptionStatus.pending,
          createdAt: DateTime.now(),
        );
        await referralRepository!.createRedemption(redemption);

        // Increment referral redemption count
        await referralRepository!.updateReferral(
          referral.incrementRedemption(),
        );
      }
    }

    // Calculate dates (will be updated when approved)
    final now = DateTime.now();
    final startDate = now;
    final endDate = DateTime(
      now.year,
      now.month + params.durationInMonths,
      now.day,
    );

    // Create subscription in pending status
    // Use the plan's maxSeats as the seat limit, not the current seat count
    // For Enterprise tier (maxSeats = -1), use a very large number for unlimited
    final effectiveSeatLimit =
        params.seatLimitOverride ??
        (plan.maxSeats == -1 ? 999999 : plan.maxSeats);

    final subscription = Subscription(
      id: const Uuid().v4(),
      ownerId: params.ownerId,
      libraryId: params.libraryId,
      seatCount: effectiveSeatLimit,
      planId: params.planIdOverride ?? plan.id,
      baseMonthlyPrice: baseMonthlyPrice,
      durationInMonths: params.durationInMonths,
      discountPercent: discountPercent,
      finalAmount: finalAmount,
      startDate: startDate,
      endDate: endDate,
      status: SubscriptionStatus.pending,
      couponCode: params.couponCode,
      couponDiscount: couponDiscount,
      adminDiscountPercent: adminDiscountPercent,
      adminDiscountAmount: adminDiscountAmount,
      createdAt: now,
      updatedAt: now,
    );

    return subscriptionRepository.createSubscription(subscription);
  }
}

/// Parameters for CreateSubscription use case.
class CreateSubscriptionParams extends Equatable {
  const CreateSubscriptionParams({
    required this.ownerId,
    required this.libraryId,
    required this.seatCount,
    required this.durationInMonths,
    this.couponCode,
    this.customLibraryPrice,
    this.adminDiscountPercent,
    this.referralCode,
    this.planIdOverride,
    this.baseMonthlyPriceOverride,
    this.finalAmountOverride,
    this.discountPercentOverride,
    this.seatLimitOverride,
  });

  final String ownerId;
  final String libraryId;
  final int seatCount;
  final int durationInMonths;
  final String? couponCode;
  final double? customLibraryPrice;
  final double? adminDiscountPercent;
  final String? referralCode;
  final String? planIdOverride;
  final double? baseMonthlyPriceOverride;
  final double? finalAmountOverride;
  final double? discountPercentOverride;
  final int? seatLimitOverride;

  @override
  List<Object?> get props => [
    ownerId,
    libraryId,
    seatCount,
    durationInMonths,
    couponCode,
    customLibraryPrice,
    adminDiscountPercent,
    referralCode,
    planIdOverride,
    baseMonthlyPriceOverride,
    finalAmountOverride,
    discountPercentOverride,
    seatLimitOverride,
  ];
}
