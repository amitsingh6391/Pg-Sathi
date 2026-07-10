import 'package:equatable/equatable.dart';

/// Represents a subscription pricing tier based on seat count.
/// Pricing is determined solely by total seats owned.
class SubscriptionPlan extends Equatable {
  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.minSeats,
    required this.maxSeats,
    required this.monthlyPrice,
  });

  final String id;
  final String name;
  final int minSeats;
  final int maxSeats; // Use -1 for unlimited
  final double monthlyPrice;

  /// Checks if this plan applies to the given seat count.
  bool appliesTo(int seatCount) {
    if (maxSeats == -1) {
      return seatCount >= minSeats;
    }
    return seatCount >= minSeats && seatCount <= maxSeats;
  }

  @override
  List<Object?> get props => [id, name, minSeats, maxSeats, monthlyPrice];

  /// Predefined pricing tiers.
  /// Updated: January 2026 (Revised)
  static const List<SubscriptionPlan> pricingTiers = [
    SubscriptionPlan(
      id: 'tier_149',
      name: 'Starter',
      minSeats: 1,
      maxSeats: 49,
      monthlyPrice: 149,
    ),
    SubscriptionPlan(
      id: 'tier_249',
      name: 'Basic',
      minSeats: 50,
      maxSeats: 99,
      monthlyPrice: 249,
    ),
    SubscriptionPlan(
      id: 'tier_299',
      name: 'Growth',
      minSeats: 100,
      maxSeats: 149,
      monthlyPrice: 299,
    ),
    SubscriptionPlan(
      id: 'tier_349',
      name: 'Professional',
      minSeats: 150,
      maxSeats: 199,
      monthlyPrice: 349,
    ),
    SubscriptionPlan(
      id: 'tier_399',
      name: 'Advanced',
      minSeats: 200,
      maxSeats: 249,
      monthlyPrice: 399,
    ),
    SubscriptionPlan(
      id: 'tier_449',
      name: 'Business',
      minSeats: 250,
      maxSeats: 299,
      monthlyPrice: 449,
    ),
    SubscriptionPlan(
      id: 'tier_499',
      name: 'Premium',
      minSeats: 300,
      maxSeats: 349,
      monthlyPrice: 499,
    ),
    SubscriptionPlan(
      id: 'tier_699',
      name: 'Enterprise',
      minSeats: 350,
      maxSeats: -1, // Unlimited
      monthlyPrice: 699,
    ),
  ];

  /// Gets the appropriate plan for a given seat count.
  /// If seatCount is 0 or less, returns the starter tier (tier_149).
  static SubscriptionPlan getPlanForSeats(int seatCount) {
    // Handle edge case: 0 or negative seats should show starter plan
    if (seatCount <= 0) {
      return pricingTiers.first; // tier_149
    }
    
    for (final plan in pricingTiers) {
      if (plan.appliesTo(seatCount)) {
        return plan;
      }
    }
    // Fallback to enterprise for any edge case
    return pricingTiers.last;
  }

  /// Duration discount percentages.
  static const Map<int, double> durationDiscounts = {
    1: 0.0, // No discount for 1 month
    3: 0.0, // No discount for 3 months
    6: 0.0, // No discount for 6 months
    12: 5.0, // 5% discount for 12 months
  };

  /// Gets discount percentage for a duration.
  static double getDiscountForDuration(int months) {
    return durationDiscounts[months] ?? 0.0;
  }

  /// Available subscription durations in months.
  static const List<int> availableDurations = [1, 3, 6, 12];

  /// UPI Payment Details
  static const String upiId = 'pgsathi@slc';
  static const String supportWhatsApp = '+919548582776';
  static const String supportEmail = 'service@pgsathi.in';
  static const String appName = 'PG Sathi';

  /// Razorpay Keys
  static const String razorpayLiveKey = 'rzp_live_ozPULXLDgca7CR';
  static const String razorpayTestKey = 'rzp_test_1iFdsz611tIZeV';
  static const double razorpayChargePercent = 2.5; // 2.5% transaction charge

  /// Trial period in days (legacy - not used in freemium model).
  static const int trialDays = 3;

  /// Free tier seat limit (freemium model).
  /// Owners can assign up to this many seats without paying.
  static const int freeSeatsLimit = 7;
}
