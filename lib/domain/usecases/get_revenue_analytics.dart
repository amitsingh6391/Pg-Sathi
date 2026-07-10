import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/payment.dart';
import '../repositories/payment_repository.dart';

/// Single data point for time-series charts.
class EarningsDataPoint extends Equatable {
  const EarningsDataPoint({
    required this.date,
    required this.amount,
    this.onlineAmount = 0,
    this.upiAmount = 0,
    this.cashAmount = 0,
  });

  final DateTime date;
  final double amount;
  final double onlineAmount;
  final double upiAmount;
  final double cashAmount;

  @override
  List<Object?> get props => [
    date,
    amount,
    onlineAmount,
    upiAmount,
    cashAmount,
  ];
}

/// Revenue analytics data for a library.
class RevenueAnalytics extends Equatable {
  const RevenueAnalytics({
    required this.todayEarnings,
    required this.monthEarnings,
    required this.yearEarnings,
    required this.allTimeEarnings,
    required this.pendingCashCount,
    required this.pendingUpiCount,
    required this.onlinePaymentsTotal,
    required this.cashPaymentsTotal,
    required this.upiPaymentsTotal,
    required this.recentPayments,
    required this.dailyData,
    required this.monthlyData,
  });

  /// Today's total earnings (completed payments).
  final double todayEarnings;

  /// This month's total earnings (completed payments).
  final double monthEarnings;

  /// This year's total earnings.
  final double yearEarnings;

  /// All time earnings.
  final double allTimeEarnings;

  /// Count of pending cash payments awaiting approval.
  final int pendingCashCount;

  /// Count of pending UPI payments awaiting approval.
  final int pendingUpiCount;

  /// Total pending approvals.
  int get totalPendingApprovals => pendingCashCount + pendingUpiCount;

  /// Total earnings from online payments this month.
  final double onlinePaymentsTotal;

  /// Total earnings from cash payments this month.
  final double cashPaymentsTotal;

  /// Total earnings from UPI payments this month.
  final double upiPaymentsTotal;

  /// Recent completed payments (for trend display).
  final List<Payment> recentPayments;

  /// Daily earnings data (last 30 days).
  final List<EarningsDataPoint> dailyData;

  /// Monthly earnings data (last 12 months).
  final List<EarningsDataPoint> monthlyData;

  /// Payment distribution percentages.
  double get onlinePercentage =>
      monthEarnings > 0 ? (onlinePaymentsTotal / monthEarnings) * 100 : 0;
  double get cashPercentage =>
      monthEarnings > 0 ? (cashPaymentsTotal / monthEarnings) * 100 : 0;
  double get upiPercentage =>
      monthEarnings > 0 ? (upiPaymentsTotal / monthEarnings) * 100 : 0;

  @override
  List<Object?> get props => [
    todayEarnings,
    monthEarnings,
    yearEarnings,
    allTimeEarnings,
    pendingCashCount,
    pendingUpiCount,
    onlinePaymentsTotal,
    cashPaymentsTotal,
    upiPaymentsTotal,
    recentPayments,
    dailyData,
    monthlyData,
  ];
}

/// Use case for getting revenue analytics for a library.
class GetRevenueAnalytics
    implements UseCase<RevenueAnalytics, GetRevenueAnalyticsParams> {
  const GetRevenueAnalytics({required this.paymentRepository});

  final PaymentRepository paymentRepository;

  @override
  Future<Either<Failure, RevenueAnalytics>> call(
    GetRevenueAnalyticsParams params,
  ) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);
    final yearStart = DateTime(now.year, 1, 1);
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    // Optimized: Fetch payments in parallel with appropriate date filters
    // For all-time stats, we still need all payments, but we can optimize
    // by fetching recent payments separately for daily/monthly data
    final allPaymentsFuture = paymentRepository.getCompletedPayments(
      libraryId: params.libraryId,
    );
    final recentPaymentsFuture = paymentRepository.getCompletedPayments(
      libraryId: params.libraryId,
      startDate: thirtyDaysAgo,
      endDate: now,
    );
    final pendingFuture = paymentRepository.getPendingApprovalPayments(
      params.libraryId,
    );

    final results = await Future.wait([
      allPaymentsFuture,
      recentPaymentsFuture,
      pendingFuture,
    ]);

    final allPaymentsResult = results[0];
    final recentPaymentsResult = results[1];
    final pendingResult = results[2];

    return allPaymentsResult.fold((failure) => Left(failure), (allPayments) {
      final pendingPayments = pendingResult.fold(
        (_) => <Payment>[],
        (payments) => payments,
      );

      // Calculate all-time earnings
      final allTimeEarnings = allPayments.fold<double>(
        0,
        (sum, p) => sum + p.amount,
      );

      // Filter for year
      final yearPayments = allPayments
          .where((p) => p.updatedAt != null && p.updatedAt!.isAfter(yearStart))
          .toList();
      final yearEarnings = yearPayments.fold<double>(
        0,
        (sum, p) => sum + p.amount,
      );

      // Filter for month
      final monthPayments = allPayments
          .where((p) => p.updatedAt != null && p.updatedAt!.isAfter(monthStart))
          .toList();
      final monthEarnings = monthPayments.fold<double>(
        0,
        (sum, p) => sum + p.amount,
      );

      // Calculate today's earnings
      final todayPayments = allPayments
          .where((p) => p.updatedAt != null && p.updatedAt!.isAfter(todayStart))
          .toList();
      final todayEarnings = todayPayments.fold<double>(
        0,
        (sum, p) => sum + p.amount,
      );

      // Count pending by type
      final pendingCashCount = pendingPayments
          .where((p) => p.mode == PaymentMode.cash)
          .length;
      final pendingUpiCount = pendingPayments
          .where((p) => p.mode == PaymentMode.upi)
          .length;

      // Calculate earnings by payment mode (this month)
      // Online payments are no longer supported - set to 0
      double onlineTotal = 0;
      double cashTotal = 0;
      double upiTotal = 0;

      for (final payment in monthPayments) {
        switch (payment.mode) {
          case PaymentMode.online:
            // Online payments deprecated - count as 0
            break;
          case PaymentMode.cash:
            cashTotal += payment.amount;
          case PaymentMode.upi:
            upiTotal += payment.amount;
        }
      }

      // Use recent payments for daily data (optimized: only last 30 days)
      final recentPayments = recentPaymentsResult.fold(
        (_) => <Payment>[],
        (payments) => payments,
      );
      final dailyData = _generateDailyData(recentPayments, thirtyDaysAgo, now);

      // Generate monthly data (last 12 months) - use all payments for accuracy
      final monthlyData = _generateMonthlyData(allPayments, now);

      // Sort recent payments by date (newest first)
      final sortedPayments = [...allPayments]
        ..sort((a, b) {
          if (a.updatedAt == null && b.updatedAt == null) return 0;
          if (a.updatedAt == null) return 1;
          if (b.updatedAt == null) return -1;
          return b.updatedAt!.compareTo(a.updatedAt!);
        });

      return Right(
        RevenueAnalytics(
          todayEarnings: todayEarnings,
          monthEarnings: monthEarnings,
          yearEarnings: yearEarnings,
          allTimeEarnings: allTimeEarnings,
          pendingCashCount: pendingCashCount,
          pendingUpiCount: pendingUpiCount,
          onlinePaymentsTotal: onlineTotal,
          cashPaymentsTotal: cashTotal,
          upiPaymentsTotal: upiTotal,
          recentPayments: sortedPayments.take(10).toList(),
          dailyData: dailyData,
          monthlyData: monthlyData,
        ),
      );
    });
  }

  /// Generates daily earnings data for the last 30 days.
  List<EarningsDataPoint> _generateDailyData(
    List<Payment> payments,
    DateTime startDate,
    DateTime endDate,
  ) {
    final data = <EarningsDataPoint>[];
    var currentDate = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    while (!currentDate.isAfter(end)) {
      final nextDate = currentDate.add(const Duration(days: 1));

      final dayPayments = payments.where(
        (p) =>
            p.updatedAt != null &&
            p.updatedAt!.isAfter(currentDate) &&
            p.updatedAt!.isBefore(nextDate),
      );

      double total = 0;
      double online = 0;
      double upi = 0;
      double cash = 0;

      for (final p in dayPayments) {
        total += p.amount;
        switch (p.mode) {
          case PaymentMode.online:
            // Online payments deprecated - count as 0
            break;
          case PaymentMode.upi:
            upi += p.amount;
          case PaymentMode.cash:
            cash += p.amount;
        }
      }

      data.add(
        EarningsDataPoint(
          date: currentDate,
          amount: total,
          onlineAmount: online,
          upiAmount: upi,
          cashAmount: cash,
        ),
      );

      currentDate = nextDate;
    }

    return data;
  }

  /// Generates monthly earnings data for the last 12 months.
  List<EarningsDataPoint> _generateMonthlyData(
    List<Payment> payments,
    DateTime now,
  ) {
    final data = <EarningsDataPoint>[];

    for (int i = 11; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final nextMonth = DateTime(now.year, now.month - i + 1, 1);

      final monthPayments = payments.where(
        (p) =>
            p.updatedAt != null &&
            p.updatedAt!.isAfter(monthDate) &&
            p.updatedAt!.isBefore(nextMonth),
      );

      double total = 0;
      double online = 0;
      double upi = 0;
      double cash = 0;

      for (final p in monthPayments) {
        total += p.amount;
        switch (p.mode) {
          case PaymentMode.online:
            // Online payments deprecated - count as 0
            break;
          case PaymentMode.upi:
            upi += p.amount;
          case PaymentMode.cash:
            cash += p.amount;
        }
      }

      data.add(
        EarningsDataPoint(
          date: monthDate,
          amount: total,
          onlineAmount: online,
          upiAmount: upi,
          cashAmount: cash,
        ),
      );
    }

    return data;
  }
}

/// Parameters for GetRevenueAnalytics use case.
class GetRevenueAnalyticsParams extends Equatable {
  const GetRevenueAnalyticsParams({required this.libraryId});

  final String libraryId;

  @override
  List<Object?> get props => [libraryId];
}
