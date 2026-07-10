import 'package:equatable/equatable.dart';

/// Comprehensive revenue statistics for admin intelligence.
class RevenueStats extends Equatable {
  const RevenueStats({
    required this.todayRevenue,
    required this.weekRevenue,
    required this.monthRevenue,
    required this.lifetimeRevenue,
    this.monthlyData = const [],
    this.monthlySubscriptionData = const [],
    this.dailyRevenueData = const [],
    this.mrr = 0.0,
    this.listPriceMrr = 0.0,
    required this.planWiseBreakdown,
    required this.seatSlabBreakdown,
    required this.freeTrialLibraries,
    required this.paidLibraries,
    this.activeSubscriptions = 0,
    this.churnedLibraries = 0,
    this.thisMonthSubscriptions = 0,
    this.lastMonthSubscriptions = 0,
    required this.upcomingRenewals,
    required this.failedRenewals,
    required this.revenueAtRisk,
    required this.generatedAt,
  });

  const RevenueStats.empty()
    : todayRevenue = 0.0,
      weekRevenue = 0.0,
      monthRevenue = 0.0,
      lifetimeRevenue = 0.0,
      monthlyData = const [],
      monthlySubscriptionData = const [],
      dailyRevenueData = const [],
      mrr = 0.0,
      listPriceMrr = 0.0,
      planWiseBreakdown = const [],
      seatSlabBreakdown = const [],
      freeTrialLibraries = 0,
      paidLibraries = 0,
      activeSubscriptions = 0,
      churnedLibraries = 0,
      thisMonthSubscriptions = 0,
      lastMonthSubscriptions = 0,
      upcomingRenewals = const UpcomingRenewals.empty(),
      failedRenewals = const [],
      revenueAtRisk = 0.0,
      generatedAt = null;

  final double todayRevenue;
  final double weekRevenue;
  final double monthRevenue;
  final double lifetimeRevenue;

  /// Monthly revenue data points (last 12 months) for trend chart.
  final List<MonthlyRevenuePoint> monthlyData;
  
  /// Monthly subscription counts (last 12 months) for growth chart.
  final List<MonthlySubscriptionPoint> monthlySubscriptionData;

  /// Trailing 7 days of revenue, oldest first. Always 7 entries; days with
  /// no payments are 0. Sourced from real `approvedAt` timestamps.
  final List<DailyRevenuePoint> dailyRevenueData;

  /// Net MRR: \u03A3 (finalAmount / durationInMonths) over active, non-bypassed
  /// subscriptions. Post-discount run-rate \u2014 what's billed today.
  final double mrr;

  /// List-Price MRR: \u03A3 baseMonthlyPrice over the same set. Pre-discount
  /// run-rate \u2014 what would be billed at renewal at full plan price.
  final double listPriceMrr;

  /// Revenue breakdown by subscription plan.
  final List<PlanRevenueBreakdown> planWiseBreakdown;

  /// Revenue breakdown by seat count slabs.
  final List<SeatSlabBreakdown> seatSlabBreakdown;

  final int freeTrialLibraries;
  
  /// Libraries that have ever made a payment (lifetime).
  final int paidLibraries;
  
  /// Libraries with currently active subscription (endDate in future).
  final int activeSubscriptions;
  
  /// Libraries that churned (expired/cancelled, not active anymore).
  final int churnedLibraries;
  
  /// New subscriptions this month.
  final int thisMonthSubscriptions;
  
  /// New subscriptions last month.
  final int lastMonthSubscriptions;
  
  /// Subscription growth % (this month vs last month).
  double get subscriptionGrowthPercent {
    if (lastMonthSubscriptions == 0) return thisMonthSubscriptions > 0 ? 100.0 : 0.0;
    return ((thisMonthSubscriptions - lastMonthSubscriptions) / lastMonthSubscriptions) * 100;
  }

  final UpcomingRenewals upcomingRenewals;
  final List<FailedRenewal> failedRenewals;

  /// Revenue at risk = renewals soon + inactive libraries.
  final double revenueAtRisk;

  final DateTime? generatedAt;

  /// Total libraries count.
  int get totalLibraries => freeTrialLibraries + paidLibraries;

  /// Conversion rate from trial to paid.
  double get conversionRate {
    if (totalLibraries == 0) return 0.0;
    return (paidLibraries / totalLibraries) * 100;
  }

  @override
  List<Object?> get props => [
    todayRevenue,
    weekRevenue,
    monthRevenue,
    lifetimeRevenue,
    monthlyData,
    monthlySubscriptionData,
    dailyRevenueData,
    mrr,
    listPriceMrr,
    planWiseBreakdown,
    seatSlabBreakdown,
    freeTrialLibraries,
    paidLibraries,
    activeSubscriptions,
    churnedLibraries,
    thisMonthSubscriptions,
    lastMonthSubscriptions,
    upcomingRenewals,
    failedRenewals,
    revenueAtRisk,
    generatedAt,
  ];
}

/// Single data point for daily revenue (last 7 days chart).
class DailyRevenuePoint extends Equatable {
  const DailyRevenuePoint({required this.date, required this.revenue});

  /// Day at 00:00 (no time component).
  final DateTime date;
  final double revenue;

  @override
  List<Object?> get props => [date, revenue];
}

/// Single data point for monthly revenue trend chart.
class MonthlyRevenuePoint extends Equatable {
  const MonthlyRevenuePoint({
    required this.date,
    required this.revenue,
  });

  final DateTime date;
  final double revenue;

  @override
  List<Object?> get props => [date, revenue];
}

/// Single data point for monthly subscription count chart.
class MonthlySubscriptionPoint extends Equatable {
  const MonthlySubscriptionPoint({
    required this.date,
    required this.count,
  });

  final DateTime date;
  final int count;

  @override
  List<Object?> get props => [date, count];
}

/// Revenue breakdown by subscription plan.
class PlanRevenueBreakdown extends Equatable {
  const PlanRevenueBreakdown({
    required this.planId,
    required this.planName,
    required this.revenue,
    required this.subscriptionCount,
  });

  final String planId;
  final String planName;
  final double revenue;
  final int subscriptionCount;

  double get averageRevenue =>
      subscriptionCount > 0 ? revenue / subscriptionCount : 0;

  @override
  List<Object?> get props => [planId, planName, revenue, subscriptionCount];
}

/// Revenue breakdown by seat count slabs.
class SeatSlabBreakdown extends Equatable {
  const SeatSlabBreakdown({
    required this.slabLabel,
    required this.minSeats,
    required this.maxSeats,
    required this.revenue,
    required this.libraryCount,
  });

  final String slabLabel; // e.g., "1-20", "21-50", "51-100", "100+"
  final int minSeats;
  final int? maxSeats;
  final double revenue;
  final int libraryCount;

  @override
  List<Object?> get props => [
    slabLabel,
    minSeats,
    maxSeats,
    revenue,
    libraryCount,
  ];
}

/// Upcoming renewals categorized by time window.
class UpcomingRenewals extends Equatable {
  const UpcomingRenewals({
    required this.next7Days,
    required this.next15Days,
    required this.next30Days,
  });

  const UpcomingRenewals.empty()
    : next7Days = const [],
      next15Days = const [],
      next30Days = const [];

  final List<RenewalInfo> next7Days;
  final List<RenewalInfo> next15Days;
  final List<RenewalInfo> next30Days;

  int get totalCount =>
      next7Days.length + next15Days.length + next30Days.length;

  double get totalRevenue {
    double sum = 0;
    for (final r in next7Days) {
      sum += r.renewalAmount;
    }
    for (final r in next15Days) {
      sum += r.renewalAmount;
    }
    for (final r in next30Days) {
      sum += r.renewalAmount;
    }
    return sum;
  }

  @override
  List<Object?> get props => [next7Days, next15Days, next30Days];
}

/// Information about an upcoming renewal.
class RenewalInfo extends Equatable {
  const RenewalInfo({
    required this.subscriptionId,
    required this.libraryId,
    required this.libraryName,
    required this.ownerName,
    required this.renewalDate,
    required this.renewalAmount,
    required this.isAtRisk,
  });

  final String subscriptionId;
  final String libraryId;
  final String libraryName;
  final String ownerName;
  final DateTime renewalDate;
  final double renewalAmount;
  final bool isAtRisk; // True if library is inactive

  int get daysUntilRenewal => renewalDate.difference(DateTime.now()).inDays;

  @override
  List<Object?> get props => [
    subscriptionId,
    libraryId,
    libraryName,
    ownerName,
    renewalDate,
    renewalAmount,
    isAtRisk,
  ];
}

/// Information about a failed or missed renewal.
class FailedRenewal extends Equatable {
  const FailedRenewal({
    required this.subscriptionId,
    required this.libraryId,
    required this.libraryName,
    required this.ownerName,
    required this.ownerPhone,
    required this.expiredDate,
    required this.missedAmount,
    required this.daysSinceExpiry,
  });

  final String subscriptionId;
  final String libraryId;
  final String libraryName;
  final String ownerName;
  final String ownerPhone;
  final DateTime expiredDate;
  final double missedAmount;
  final int daysSinceExpiry;

  @override
  List<Object?> get props => [
    subscriptionId,
    libraryId,
    libraryName,
    ownerName,
    ownerPhone,
    expiredDate,
    missedAmount,
    daysSinceExpiry,
  ];
}
