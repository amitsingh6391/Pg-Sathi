import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../../domain/core/failure.dart';
import '../../domain/entities/admin_action.dart';
import '../failures/data_failures.dart';
import '../../domain/entities/admin_alert.dart';
import '../../domain/entities/admin_note.dart';
import '../../domain/entities/churn_data.dart';
import '../../domain/entities/pricing_experiment.dart';
import '../../domain/entities/revenue_stats.dart';
import '../../domain/entities/subscription_plan.dart';
import '../../domain/repositories/admin_intelligence_repository.dart';

/// Firebase implementation of [AdminIntelligenceRepository].
class AdminIntelligenceRepositoryImpl implements AdminIntelligenceRepository {
  AdminIntelligenceRepositoryImpl({required this.firestore});

  final FirebaseFirestore firestore;
  final _uuid = const Uuid();

  // Collection references
  CollectionReference get _subscriptions =>
      firestore.collection('subscriptions');
  CollectionReference get _libraries => firestore.collection('libraries');
  CollectionReference get _adminActions =>
      firestore.collection('admin_actions');
  CollectionReference get _experiments =>
      firestore.collection('pricing_experiments');
  CollectionReference get _alerts => firestore.collection('admin_alerts');
  CollectionReference get _notes => firestore.collection('admin_notes');

  // ============================================================================
  // Revenue Intelligence
  // ============================================================================

  @override
  Future<Either<Failure, RevenueStats>> getRevenueStats() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekAgo = todayStart.subtract(const Duration(days: 7));
      final monthStart = DateTime(now.year, now.month, 1);

      // Fetch active + expired/cancelled subscriptions in parallel
      // so lifetime revenue includes historical data.
      final results = await Future.wait([
        _subscriptions.where('status', isEqualTo: 'active').get(),
        _subscriptions.where('status', isEqualTo: 'expired').get(),
        _subscriptions.where('status', isEqualTo: 'cancelled').get(),
      ]);

      final activeSnapshot = results[0];
      final expiredSnapshot = results[1];
      final cancelledSnapshot = results[2];

      final allDocs = [
        ...activeSnapshot.docs,
        ...expiredSnapshot.docs,
        ...cancelledSnapshot.docs,
      ];

      double todayRevenue = 0;
      double weekRevenue = 0;
      double monthRevenue = 0;
      double lifetimeRevenue = 0;
      double mrr = 0;
      double listPriceMrr = 0;

      final planRevenue = <String, PlanRevenueBreakdown>{};
      final seatSlabs = <String, SeatSlabBreakdown>{};
      final paidLibraryIds = <String>{};
      final activeLibraryIds = <String>{};
      final expiredLibraryIds = <String>{};

      final dailyRevenueMap = <DateTime, double>{};
      for (int i = 6; i >= 0; i--) {
        final d = todayStart.subtract(Duration(days: i));
        dailyRevenueMap[d] = 0.0;
      }
      final sevenDayWindowStart = todayStart.subtract(const Duration(days: 6));

      final libraryFirstSubscriptionDate = <String, DateTime>{};
      final monthlyNewLibrariesMap = <String, Set<String>>{};

      final prevMonthStart = DateTime(now.year, now.month - 1, 1);
      final prevMonthKey =
          '${prevMonthStart.year}-${prevMonthStart.month.toString().padLeft(2, '0')}';
      final currMonthKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';

      final monthlyRevenueMap = <String, double>{};

      for (final doc in allDocs) {
        final data = doc.data() as Map<String, dynamic>;
        final amount = (data['finalAmount'] as num?)?.toDouble() ?? 0;
        if (amount <= 0) continue;

        // Prefer admin-verified timestamp; legacy rows only have createdAt.
        final approvedAt = (data['approvedAt'] as Timestamp?)?.toDate();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final revenueDate = approvedAt ?? createdAt;
        final planId = data['planId'] as String? ?? 'unknown';
        final planName = data['planName'] as String? ?? 'Standard';
        final seatCount = data['seatCount'] as int? ?? 0;
        final status = data['status'] as String? ?? '';
        final libraryId = data['libraryId'] as String? ?? '';

        // status='active' alone is unreliable \u2014 the lapse cron may not have
        // run yet, so an "active" sub past its endDate is really expired.
        final endDate = (data['endDate'] as Timestamp?)?.toDate();
        final isTrulyActive = status == 'active' &&
            endDate != null &&
            !endDate.isBefore(now);

        lifetimeRevenue += amount;

        if (libraryId.isNotEmpty) {
          paidLibraryIds.add(libraryId);
          if (revenueDate != null) {
            if (!libraryFirstSubscriptionDate.containsKey(libraryId) ||
                revenueDate.isBefore(libraryFirstSubscriptionDate[libraryId]!)) {
              libraryFirstSubscriptionDate[libraryId] = revenueDate;
            }
          }
        }

        if (revenueDate != null) {
          if (!revenueDate.isBefore(todayStart)) todayRevenue += amount;
          if (!revenueDate.isBefore(weekAgo)) weekRevenue += amount;
          if (!revenueDate.isBefore(monthStart)) monthRevenue += amount;

          final monthKey =
              '${revenueDate.year}-${revenueDate.month.toString().padLeft(2, '0')}';
          monthlyRevenueMap[monthKey] =
              (monthlyRevenueMap[monthKey] ?? 0) + amount;
        }

        _accumulatePlanRevenue(planRevenue, planId, planName, amount);

        if (libraryId.isNotEmpty) {
          if (isTrulyActive) {
            _accumulateSeatSlab(seatSlabs, seatCount, amount);
            activeLibraryIds.add(libraryId);
          } else if (status == 'expired' || status == 'cancelled' ||
                     (status == 'active' && endDate != null && endDate.isBefore(now))) {
            expiredLibraryIds.add(libraryId);
          }
        }

        // Per-day buckets and MRR exclude admin bypasses \u2014 they're
        // operationally active but \u20B90 of cash, so counting them inflates both.
        final isAdminBypassed = data['isAdminBypassed'] as bool? ?? false;

        if (!isAdminBypassed && revenueDate != null &&
            !revenueDate.isBefore(sevenDayWindowStart)) {
          final dayKey =
              DateTime(revenueDate.year, revenueDate.month, revenueDate.day);
          if (dailyRevenueMap.containsKey(dayKey)) {
            dailyRevenueMap[dayKey] = dailyRevenueMap[dayKey]! + amount;
          }
        }

        if (!isAdminBypassed && isTrulyActive) {
          // Normalise to per-month so a \u20B9597 quarterly plan = \u20B9199 MRR.
          final durationInMonths =
              (data['durationInMonths'] as num?)?.toInt() ?? 1;
          final months = durationInMonths > 0 ? durationInMonths : 1;
          mrr += amount / months;

          // List MRR uses the plan tier's full price, ignoring all discounts.
          // Fallback for legacy docs missing baseMonthlyPrice.
          final storedBase = (data['baseMonthlyPrice'] as num?)?.toDouble();
          final listMonthly = (storedBase != null && storedBase > 0)
              ? storedBase
              : SubscriptionPlan.getPlanForSeats(seatCount).monthlyPrice;
          listPriceMrr += listMonthly;
        }
      }

      final sortedDays = dailyRevenueMap.keys.toList()..sort();
      final dailyRevenueData = sortedDays
          .map((d) => DailyRevenuePoint(date: d, revenue: dailyRevenueMap[d]!))
          .toList(growable: false);

      for (final entry in libraryFirstSubscriptionDate.entries) {
        final firstDate = entry.value;
        final monthKey =
            '${firstDate.year}-${firstDate.month.toString().padLeft(2, '0')}';
        monthlyNewLibrariesMap.putIfAbsent(monthKey, () => <String>{});
        monthlyNewLibrariesMap[monthKey]!.add(entry.key);
      }

      final paidCount = paidLibraryIds.length;
      final activeCount = activeLibraryIds.length;
      final churnedCount = expiredLibraryIds.difference(activeLibraryIds).length;

      final thisMonthNewLibraries = monthlyNewLibrariesMap[currMonthKey]?.length ?? 0;
      final lastMonthNewLibraries = monthlyNewLibrariesMap[prevMonthKey]?.length ?? 0;

      final monthlyData = _buildMonthlyDataPoints(monthlyRevenueMap, now);
      final monthlySubscriptionData = _buildMonthlySubscriptionPoints(monthlyNewLibrariesMap, now);

      final trialSnapshot =
          await _libraries.where('isOnTrial', isEqualTo: true).get();
      final freeTrialCount = trialSnapshot.docs.length;

      final upcomingRenewals = await getUpcomingRenewals();
      final failedRenewals = await getFailedRenewals();

      double revenueAtRisk = 0;
      upcomingRenewals.fold((l) => null, (r) {
        for (final renewal in r.next7Days) {
          if (renewal.isAtRisk) revenueAtRisk += renewal.renewalAmount;
        }
      });

      return Right(
        RevenueStats(
          todayRevenue: todayRevenue,
          weekRevenue: weekRevenue,
          monthRevenue: monthRevenue,
          lifetimeRevenue: lifetimeRevenue,
          monthlyData: monthlyData,
          monthlySubscriptionData: monthlySubscriptionData,
          dailyRevenueData: dailyRevenueData,
          mrr: mrr,
          listPriceMrr: listPriceMrr,
          planWiseBreakdown: planRevenue.values.toList(),
          seatSlabBreakdown: seatSlabs.values.toList(),
          freeTrialLibraries: freeTrialCount,
          paidLibraries: paidCount,
          activeSubscriptions: activeCount,
          churnedLibraries: churnedCount,
          thisMonthSubscriptions: thisMonthNewLibraries,
          lastMonthSubscriptions: lastMonthNewLibraries,
          upcomingRenewals: upcomingRenewals.getOrElse(
            () => const UpcomingRenewals.empty(),
          ),
          failedRenewals: failedRenewals.getOrElse(() => []),
          revenueAtRisk: revenueAtRisk,
          generatedAt: DateTime.now(),
        ),
      );
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get revenue stats: $e'));
    }
  }

  /// Accumulates revenue into a plan-wise breakdown map.
  void _accumulatePlanRevenue(
    Map<String, PlanRevenueBreakdown> map,
    String planId,
    String planName,
    double amount,
  ) {
    if (map.containsKey(planId)) {
      final existing = map[planId]!;
      map[planId] = PlanRevenueBreakdown(
        planId: planId,
        planName: planName,
        revenue: existing.revenue + amount,
        subscriptionCount: existing.subscriptionCount + 1,
      );
    } else {
      map[planId] = PlanRevenueBreakdown(
        planId: planId,
        planName: planName,
        revenue: amount,
        subscriptionCount: 1,
      );
    }
  }

  /// Accumulates revenue into a seat-slab breakdown map.
  void _accumulateSeatSlab(
    Map<String, SeatSlabBreakdown> map,
    int seatCount,
    double amount,
  ) {
    final slabKey = _getSeatSlabKey(seatCount);
    if (map.containsKey(slabKey)) {
      final existing = map[slabKey]!;
      map[slabKey] = SeatSlabBreakdown(
        slabLabel: existing.slabLabel,
        minSeats: existing.minSeats,
        maxSeats: existing.maxSeats,
        revenue: existing.revenue + amount,
        libraryCount: existing.libraryCount + 1,
      );
    } else {
      map[slabKey] = _createSeatSlab(slabKey, amount);
    }
  }

  /// Builds a sorted list of [MonthlyRevenuePoint] for the last 12 months.
  List<MonthlyRevenuePoint> _buildMonthlyDataPoints(
    Map<String, double> revenueMap,
    DateTime now,
  ) {
    final points = <MonthlyRevenuePoint>[];
    for (int i = 11; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final key =
          '${monthDate.year}-${monthDate.month.toString().padLeft(2, '0')}';
      points.add(MonthlyRevenuePoint(
        date: monthDate,
        revenue: revenueMap[key] ?? 0,
      ));
    }
    return points;
  }

  /// Builds a sorted list of [MonthlySubscriptionPoint] for the last 12 months.
  List<MonthlySubscriptionPoint> _buildMonthlySubscriptionPoints(
    Map<String, Set<String>> subscriptionMap,
    DateTime now,
  ) {
    final points = <MonthlySubscriptionPoint>[];
    for (int i = 11; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final key =
          '${monthDate.year}-${monthDate.month.toString().padLeft(2, '0')}';
      points.add(MonthlySubscriptionPoint(
        date: monthDate,
        count: subscriptionMap[key]?.length ?? 0,
      ));
    }
    return points;
  }

  String _getSeatSlabKey(int seats) {
    if (seats <= 20) return '1-20';
    if (seats <= 50) return '21-50';
    if (seats <= 100) return '51-100';
    return '100+';
  }

  SeatSlabBreakdown _createSeatSlab(String key, double revenue) {
    switch (key) {
      case '1-20':
        return SeatSlabBreakdown(
          slabLabel: key,
          minSeats: 1,
          maxSeats: 20,
          revenue: revenue,
          libraryCount: 1,
        );
      case '21-50':
        return SeatSlabBreakdown(
          slabLabel: key,
          minSeats: 21,
          maxSeats: 50,
          revenue: revenue,
          libraryCount: 1,
        );
      case '51-100':
        return SeatSlabBreakdown(
          slabLabel: key,
          minSeats: 51,
          maxSeats: 100,
          revenue: revenue,
          libraryCount: 1,
        );
      default:
        return SeatSlabBreakdown(
          slabLabel: key,
          minSeats: 101,
          maxSeats: null,
          revenue: revenue,
          libraryCount: 1,
        );
    }
  }

  @override
  Future<Either<Failure, List<PlanRevenueBreakdown>>>
  getPlanWiseRevenue() async {
    final stats = await getRevenueStats();
    return stats.fold((l) => Left(l), (r) => Right(r.planWiseBreakdown));
  }

  @override
  Future<Either<Failure, List<SeatSlabBreakdown>>> getSeatSlabRevenue() async {
    final stats = await getRevenueStats();
    return stats.fold((l) => Left(l), (r) => Right(r.seatSlabBreakdown));
  }

  @override
  Future<Either<Failure, UpcomingRenewals>> getUpcomingRenewals() async {
    try {
      final now = DateTime.now();
      final in7Days = now.add(const Duration(days: 7));
      final in15Days = now.add(const Duration(days: 15));
      final in30Days = now.add(const Duration(days: 30));

      final snapshot = await _subscriptions
          .where('status', isEqualTo: 'active')
          .where('endDate', isLessThanOrEqualTo: Timestamp.fromDate(in30Days))
          .get();

      final next7 = <RenewalInfo>[];
      final next15 = <RenewalInfo>[];
      final next30 = <RenewalInfo>[];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final endDate = (data['endDate'] as Timestamp).toDate();

        final renewal = RenewalInfo(
          subscriptionId: doc.id,
          libraryId: data['libraryId'] as String? ?? '',
          libraryName: data['libraryName'] as String? ?? 'Unknown',
          ownerName: data['ownerName'] as String? ?? 'Unknown',
          renewalDate: endDate,
          renewalAmount: (data['finalAmount'] as num?)?.toDouble() ?? 0,
          isAtRisk: false, // Would check library activity
        );

        if (endDate.isBefore(in7Days)) {
          next7.add(renewal);
        } else if (endDate.isBefore(in15Days)) {
          next15.add(renewal);
        } else {
          next30.add(renewal);
        }
      }

      return Right(
        UpcomingRenewals(
          next7Days: next7,
          next15Days: next15,
          next30Days: next30,
        ),
      );
    } catch (e) {
      return Left(
        ServerFailure(message: 'Failed to get upcoming renewals: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, List<FailedRenewal>>> getFailedRenewals() async {
    try {
      final snapshot = await _subscriptions
          .where('status', isEqualTo: 'expired')
          .orderBy('endDate', descending: true)
          .limit(50)
          .get();

      final renewals = <FailedRenewal>[];
      final now = DateTime.now();

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final endDate = (data['endDate'] as Timestamp).toDate();

        renewals.add(
          FailedRenewal(
            subscriptionId: doc.id,
            libraryId: data['libraryId'] as String? ?? '',
            libraryName: data['libraryName'] as String? ?? 'Unknown',
            ownerName: data['ownerName'] as String? ?? 'Unknown',
            ownerPhone: data['ownerPhone'] as String? ?? '',
            expiredDate: endDate,
            missedAmount: (data['finalAmount'] as num?)?.toDouble() ?? 0,
            daysSinceExpiry: now.difference(endDate).inDays,
          ),
        );
      }

      return Right(renewals);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get failed renewals: $e'));
    }
  }

  // ============================================================================
  // Churn & Retention
  // ============================================================================

  @override
  Future<Either<Failure, ChurnData>> getChurnData() async {
    try {
      final atRiskResult = await getAtRiskLibraries();

      return atRiskResult.fold((l) => Left(l), (libraries) {
        final inactive7 = libraries
            .where(
              (l) =>
                  l.daysInactive != null &&
                  l.daysInactive! >= 7 &&
                  l.daysInactive! < 14,
            )
            .toList();
        final inactive14 = libraries
            .where(
              (l) =>
                  l.daysInactive != null &&
                  l.daysInactive! >= 14 &&
                  l.daysInactive! < 30,
            )
            .toList();
        final inactive30 = libraries
            .where((l) => l.daysInactive != null && l.daysInactive! >= 30)
            .toList();
        final trialExpired = libraries
            .where((l) => l.riskReasons.contains(RiskReason.trialExpired))
            .toList();
        final lowUsage = libraries
            .where((l) => l.riskReasons.contains(RiskReason.lowUsage))
            .toList();

        return Right(
          ChurnData(
            inactiveLibraries: InactiveLibraries(
              inactive7Days: inactive7,
              inactive14Days: inactive14,
              inactive30Days: inactive30,
            ),
            trialExpiredUnpaid: trialExpired,
            lowUsageLibraries: lowUsage,
            generatedAt: DateTime.now(),
          ),
        );
      });
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get churn data: $e'));
    }
  }

  @override
  Future<Either<Failure, List<AtRiskLibrary>>> getAtRiskLibraries() async {
    try {
      // This is a simplified implementation
      // In production, you'd query attendance data to determine inactivity
      final snapshot = await _libraries.get();
      final atRisk = <AtRiskLibrary>[];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final lastActivity = (data['lastActivityAt'] as Timestamp?)?.toDate();
        final now = DateTime.now();

        int? daysInactive;
        final reasons = <RiskReason>[];

        if (lastActivity != null) {
          daysInactive = now.difference(lastActivity).inDays;
          if (daysInactive >= 30) {
            reasons.add(RiskReason.inactive30Days);
          } else if (daysInactive >= 14) {
            reasons.add(RiskReason.inactive14Days);
          } else if (daysInactive >= 7) {
            reasons.add(RiskReason.inactive7Days);
          }
        }

        if (reasons.isNotEmpty) {
          atRisk.add(
            AtRiskLibrary(
              libraryId: doc.id,
              libraryName: data['name'] as String? ?? 'Unknown',
              ownerId: data['ownerId'] as String? ?? '',
              ownerName: data['ownerName'] as String? ?? 'Unknown',
              ownerPhone: data['ownerPhone'] as String? ?? '',
              retentionScore: _calculateRetentionScore(daysInactive),
              riskReasons: reasons,
              lastActivityDate: lastActivity,
              subscriptionEndDate: (data['subscriptionEndDate'] as Timestamp?)
                  ?.toDate(),
              monthlyRevenue: (data['monthlyRevenue'] as num?)?.toDouble() ?? 0,
              daysInactive: daysInactive,
            ),
          );
        }
      }

      return Right(atRisk);
    } catch (e) {
      return Left(
        ServerFailure(message: 'Failed to get at-risk libraries: $e'),
      );
    }
  }

  RetentionScore _calculateRetentionScore(int? daysInactive) {
    if (daysInactive == null || daysInactive < 7) return RetentionScore.high;
    if (daysInactive < 14) return RetentionScore.medium;
    return RetentionScore.low;
  }

  // ============================================================================
  // Admin Actions - Implementation continues in next part
  // ============================================================================

  @override
  Future<Either<Failure, void>> suspendLibrary(
    SuspendLibraryRequest request,
  ) async {
    try {
      await _libraries.doc(request.libraryId).update({
        'isSuspended': true,
        'suspendedAt': FieldValue.serverTimestamp(),
        'suspendedBy': request.adminId,
        'suspensionReason': request.reason,
      });

      await _logAdminAction(
        type: AdminActionType.suspendLibrary,
        libraryId: request.libraryId,
        adminId: request.adminId,
        details: 'Suspended library',
        reason: request.reason,
      );

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to suspend library: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> unsuspendLibrary({
    required String libraryId,
    required String reason,
    required String adminId,
  }) async {
    try {
      await _libraries.doc(libraryId).update({
        'isSuspended': false,
        'suspendedAt': null,
        'suspendedBy': null,
        'suspensionReason': null,
      });

      await _logAdminAction(
        type: AdminActionType.unsuspendLibrary,
        libraryId: libraryId,
        adminId: adminId,
        details: 'Unsuspended library',
        reason: reason,
      );

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to unsuspend library: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> extendTrial(ExtendTrialRequest request) async {
    try {
      final libDoc = await _libraries.doc(request.libraryId).get();
      if (!libDoc.exists) {
        return const Left(ServerFailure(message: 'Library not found'));
      }

      final data = libDoc.data() as Map<String, dynamic>?;
      final ownerId = data?['ownerId'] as String?;
      if (ownerId == null) {
        return const Left(ServerFailure(message: 'Library has no owner'));
      }

      // Get current trial from owner_trials collection
      final ownerTrialsRef = firestore.collection('owner_trials');
      final trialDoc = await ownerTrialsRef.doc(ownerId).get();

      DateTime currentEnd;
      DateTime startDate;

      if (trialDoc.exists) {
        final trialData = trialDoc.data() as Map<String, dynamic>;
        currentEnd = (trialData['endDate'] as Timestamp).toDate();
        startDate = (trialData['startDate'] as Timestamp).toDate();
      } else {
        // No trial exists - use library creation date or now
        final libraryCreatedAt =
            (data?['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        startDate = libraryCreatedAt;
        currentEnd = libraryCreatedAt.add(const Duration(days: 7));
      }

      final newEnd = currentEnd.add(Duration(days: request.extensionDays));

      // Update owner_trials collection (this is what the app reads from)
      await ownerTrialsRef.doc(ownerId).set({
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(newEnd),
        'isUsed': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also update libraries collection for consistency
      await _libraries.doc(request.libraryId).update({
        'trialEndDate': Timestamp.fromDate(newEnd),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _logAdminAction(
        type: AdminActionType.extendTrial,
        libraryId: request.libraryId,
        adminId: request.adminId,
        details: 'Extended trial by ${request.extensionDays} days',
        reason: request.reason,
        previousValue: currentEnd.toIso8601String(),
        newValue: newEnd.toIso8601String(),
      );

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to extend trial: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> applyDiscount(
    ApplyDiscountRequest request,
  ) async {
    try {
      await _libraries.doc(request.libraryId).update({
        'customDiscount': {
          'percent': request.discountPercent,
          'validUntil': Timestamp.fromDate(request.validUntil),
          'appliedBy': request.adminId,
          'appliedAt': FieldValue.serverTimestamp(),
        },
      });

      await _logAdminAction(
        type: AdminActionType.applyDiscount,
        libraryId: request.libraryId,
        adminId: request.adminId,
        details: 'Applied ${request.discountPercent}% discount',
        reason: request.reason,
      );

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to apply discount: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> removeDiscount(
    RemoveDiscountRequest request,
  ) async {
    try {
      await _libraries.doc(request.libraryId).update({
        'customDiscount': FieldValue.delete(),
      });

      await _logAdminAction(
        type: AdminActionType.removeDiscount,
        libraryId: request.libraryId,
        adminId: request.adminId,
        details: 'Removed custom discount',
        reason: request.reason,
      );

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to remove discount: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> markPaymentReceived(
    ManualPaymentRequest request,
  ) async {
    try {
      await _subscriptions.doc(request.subscriptionId).update({
        'status': 'active',
        'manualPayment': {
          'amount': request.amount,
          'method': request.paymentMethod,
          'transactionId': request.transactionId,
          'notes': request.notes,
          'markedBy': request.adminId,
          'markedAt': FieldValue.serverTimestamp(),
        },
      });

      await _logAdminAction(
        type: AdminActionType.manualPayment,
        libraryId: '', // Get from subscription
        adminId: request.adminId,
        details:
            'Marked payment of ₹${request.amount} via ${request.paymentMethod}',
      );

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to mark payment: $e'));
    }
  }

  @override
  Future<Either<Failure, LibrarySuspensionStatus>> getSuspensionStatus(
    String libraryId,
  ) async {
    try {
      final doc = await _libraries.doc(libraryId).get();
      final data = doc.data() as Map<String, dynamic>?;

      return Right(
        LibrarySuspensionStatus(
          libraryId: libraryId,
          isSuspended: data?['isSuspended'] as bool? ?? false,
          suspendedAt: (data?['suspendedAt'] as Timestamp?)?.toDate(),
          suspendedBy: data?['suspendedBy'] as String?,
          suspensionReason: data?['suspensionReason'] as String?,
        ),
      );
    } catch (e) {
      return Left(
        ServerFailure(message: 'Failed to get suspension status: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, List<AdminAction>>> getAdminActions({
    String? libraryId,
    AdminActionType? actionType,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    try {
      Query query = _adminActions.orderBy('performedAt', descending: true);

      if (libraryId != null) {
        query = query.where('libraryId', isEqualTo: libraryId);
      }
      if (actionType != null) {
        query = query.where('type', isEqualTo: actionType.name);
      }

      final snapshot = await query.limit(limit).get();

      final actions = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return AdminAction(
          id: doc.id,
          type: AdminActionType.values.firstWhere(
            (t) => t.name == data['type'],
            orElse: () => AdminActionType.addNote,
          ),
          libraryId: data['libraryId'] as String? ?? '',
          libraryName: data['libraryName'] as String? ?? '',
          performedBy: data['performedBy'] as String? ?? '',
          performedAt: (data['performedAt'] as Timestamp).toDate(),
          details: data['details'] as String? ?? '',
          reason: data['reason'] as String?,
          previousValue: data['previousValue'] as String?,
          newValue: data['newValue'] as String?,
        );
      }).toList();

      return Right(actions);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get admin actions: $e'));
    }
  }

  Future<void> _logAdminAction({
    required AdminActionType type,
    required String libraryId,
    required String adminId,
    required String details,
    String? reason,
    String? previousValue,
    String? newValue,
  }) async {
    await _adminActions.add({
      'type': type.name,
      'libraryId': libraryId,
      'performedBy': adminId,
      'performedAt': FieldValue.serverTimestamp(),
      'details': details,
      'reason': reason,
      'previousValue': previousValue,
      'newValue': newValue,
    });
  }

  // Remaining methods implementation (experiments, alerts, notes)
  // would follow similar patterns...

  @override
  Future<Either<Failure, PricingExperiment>> createExperiment(
    CreateExperimentRequest request,
  ) async {
    try {
      final id = _uuid.v4();
      final experiment = PricingExperiment(
        id: id,
        name: request.name,
        description: request.description,
        type: request.type,
        status: ExperimentStatus.draft,
        createdAt: DateTime.now(),
        createdBy: request.adminId,
        targetLibraryIds: request.targetLibraryIds,
        metrics: const ExperimentMetrics.empty(),
        trialDurationDays: request.trialDurationDays,
        discountPercent: request.discountPercent,
        startDate: request.startDate,
        endDate: request.endDate,
      );

      await _experiments.doc(id).set({
        'name': experiment.name,
        'description': experiment.description,
        'type': experiment.type.name,
        'status': experiment.status.name,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': experiment.createdBy,
        'targetLibraryIds': experiment.targetLibraryIds,
        'trialDurationDays': experiment.trialDurationDays,
        'discountPercent': experiment.discountPercent,
      });

      return Right(experiment);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to create experiment: $e'));
    }
  }

  @override
  Future<Either<Failure, List<PricingExperiment>>> getExperiments({
    ExperimentStatus? status,
  }) async {
    try {
      Query query = _experiments.orderBy('createdAt', descending: true);
      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      final snapshot = await query.get();
      final experiments = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return PricingExperiment(
          id: doc.id,
          name: data['name'] as String? ?? '',
          description: data['description'] as String? ?? '',
          type: ExperimentType.values.firstWhere((t) => t.name == data['type']),
          status: ExperimentStatus.values.firstWhere(
            (s) => s.name == data['status'],
          ),
          createdAt: (data['createdAt'] as Timestamp).toDate(),
          createdBy: data['createdBy'] as String? ?? '',
          targetLibraryIds: List<String>.from(data['targetLibraryIds'] ?? []),
          metrics: const ExperimentMetrics.empty(),
          trialDurationDays: data['trialDurationDays'] as int?,
          discountPercent: (data['discountPercent'] as num?)?.toDouble(),
        );
      }).toList();

      return Right(experiments);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get experiments: $e'));
    }
  }

  @override
  Future<Either<Failure, PricingExperiment>> getExperimentById(
    String id,
  ) async {
    final result = await getExperiments();
    return result.fold((l) => Left(l), (experiments) {
      final exp = experiments.where((e) => e.id == id).firstOrNull;
      if (exp == null) {
        return Left(
          const DocumentNotFoundFailure(message: 'Experiment not found'),
        );
      }
      return Right(exp);
    });
  }

  @override
  Future<Either<Failure, void>> updateExperimentStatus({
    required String experimentId,
    required ExperimentStatus status,
    required String adminId,
  }) async {
    try {
      await _experiments.doc(experimentId).update({
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to update experiment: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> addLibrariesToExperiment({
    required String experimentId,
    required List<String> libraryIds,
  }) async {
    try {
      await _experiments.doc(experimentId).update({
        'targetLibraryIds': FieldValue.arrayUnion(libraryIds),
      });
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to add libraries: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> removeLibrariesFromExperiment({
    required String experimentId,
    required List<String> libraryIds,
  }) async {
    try {
      await _experiments.doc(experimentId).update({
        'targetLibraryIds': FieldValue.arrayRemove(libraryIds),
      });
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to remove libraries: $e'));
    }
  }

  // Alerts
  @override
  Future<Either<Failure, AlertsSummary>> getAlertsSummary() async {
    try {
      final snapshot = await _alerts
          .where('isRead', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      int critical = 0, warning = 0, info = 0;
      final alerts = <AdminAlert>[];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final severity = AlertSeverity.values.firstWhere(
          (s) => s.name == data['severity'],
          orElse: () => AlertSeverity.info,
        );

        switch (severity) {
          case AlertSeverity.critical:
            critical++;
          case AlertSeverity.warning:
            warning++;
          case AlertSeverity.info:
            info++;
        }

        alerts.add(_parseAlert(doc));
      }

      return Right(
        AlertsSummary(
          totalUnread: snapshot.docs.length,
          criticalCount: critical,
          warningCount: warning,
          infoCount: info,
          recentAlerts: alerts,
        ),
      );
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get alerts summary: $e'));
    }
  }

  AdminAlert _parseAlert(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdminAlert(
      id: doc.id,
      type: AlertType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => AlertType.systemHealth,
      ),
      severity: AlertSeverity.values.firstWhere(
        (s) => s.name == data['severity'],
        orElse: () => AlertSeverity.info,
      ),
      title: data['title'] as String? ?? '',
      message: data['message'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isRead: data['isRead'] as bool? ?? false,
      libraryId: data['libraryId'] as String?,
      libraryName: data['libraryName'] as String?,
    );
  }

  @override
  Future<Either<Failure, List<AdminAlert>>> getAlerts({
    AlertType? type,
    AlertSeverity? severity,
    bool? isRead,
    int limit = 50,
  }) async {
    try {
      Query query = _alerts.orderBy('createdAt', descending: true);
      if (type != null) query = query.where('type', isEqualTo: type.name);
      if (severity != null) {
        query = query.where('severity', isEqualTo: severity.name);
      }
      if (isRead != null) query = query.where('isRead', isEqualTo: isRead);

      final snapshot = await query.limit(limit).get();
      return Right(snapshot.docs.map(_parseAlert).toList());
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get alerts: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> markAlertAsRead(String alertId) async {
    try {
      await _alerts.doc(alertId).update({'isRead': true});
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to mark alert: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> markAllAlertsAsRead() async {
    try {
      final batch = firestore.batch();
      final snapshot = await _alerts.where('isRead', isEqualTo: false).get();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to mark alerts: $e'));
    }
  }

  @override
  Future<Either<Failure, List<AdminAlert>>> generateAlerts() async {
    // This would be called by a Cloud Function
    return const Right([]);
  }

  // Notes
  @override
  Future<Either<Failure, AdminNote>> createNote(
    CreateNoteRequest request,
  ) async {
    try {
      final id = _uuid.v4();
      final note = AdminNote(
        id: id,
        libraryId: request.libraryId,
        content: request.content,
        createdBy: request.adminId,
        createdAt: DateTime.now(),
        followUpDate: request.followUpDate,
        tags: request.tags,
      );

      await _notes.doc(id).set({
        'libraryId': note.libraryId,
        'content': note.content,
        'createdBy': note.createdBy,
        'createdAt': FieldValue.serverTimestamp(),
        'followUpDate': note.followUpDate != null
            ? Timestamp.fromDate(note.followUpDate!)
            : null,
        'tags': note.tags,
        'isPinned': false,
      });

      return Right(note);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to create note: $e'));
    }
  }

  @override
  Future<Either<Failure, AdminNote>> updateNote(
    UpdateNoteRequest request,
  ) async {
    try {
      await _notes.doc(request.noteId).update({
        'content': request.content,
        'updatedAt': FieldValue.serverTimestamp(),
        if (request.followUpDate != null)
          'followUpDate': Timestamp.fromDate(request.followUpDate!),
        if (request.isPinned != null) 'isPinned': request.isPinned,
        if (request.tags != null) 'tags': request.tags,
      });

      final doc = await _notes.doc(request.noteId).get();
      return Right(_parseNote(doc));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to update note: $e'));
    }
  }

  AdminNote _parseNote(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdminNote(
      id: doc.id,
      libraryId: data['libraryId'] as String? ?? '',
      content: data['content'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      followUpDate: (data['followUpDate'] as Timestamp?)?.toDate(),
      isPinned: data['isPinned'] as bool? ?? false,
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  @override
  Future<Either<Failure, void>> deleteNote(String noteId) async {
    try {
      await _notes.doc(noteId).delete();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to delete note: $e'));
    }
  }

  @override
  Future<Either<Failure, List<AdminNote>>> getNotesForLibrary(
    String libraryId,
  ) async {
    try {
      final snapshot = await _notes
          .where('libraryId', isEqualTo: libraryId)
          .orderBy('createdAt', descending: true)
          .get();
      return Right(snapshot.docs.map(_parseNote).toList());
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get notes: $e'));
    }
  }

  @override
  Future<Either<Failure, LibraryNotesSummary>> getNotesSummary(
    String libraryId,
  ) async {
    final result = await getNotesForLibrary(libraryId);
    return result.fold((l) => Left(l), (notes) {
      final now = DateTime.now();
      return Right(
        LibraryNotesSummary(
          libraryId: libraryId,
          totalNotes: notes.length,
          pinnedNotes: notes.where((n) => n.isPinned).length,
          upcomingFollowUps: notes
              .where(
                (n) => n.followUpDate != null && n.followUpDate!.isAfter(now),
              )
              .length,
          overdueFollowUps: notes.where((n) => n.isFollowUpDue).length,
          latestNote: notes.isNotEmpty ? notes.first : null,
        ),
      );
    });
  }

  @override
  Future<Either<Failure, List<AdminNote>>> getNotesWithFollowUps({
    bool overdueOnly = false,
  }) async {
    try {
      final snapshot = await _notes
          .where('followUpDate', isNull: false)
          .orderBy('followUpDate')
          .get();

      var notes = snapshot.docs.map(_parseNote).toList();
      if (overdueOnly) {
        notes = notes.where((n) => n.isFollowUpDue).toList();
      }
      return Right(notes);
    } catch (e) {
      return Left(
        ServerFailure(message: 'Failed to get notes with follow-ups: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> toggleNotePin(String noteId) async {
    try {
      final doc = await _notes.doc(noteId).get();
      final isPinned =
          (doc.data() as Map<String, dynamic>?)?['isPinned'] as bool? ?? false;
      await _notes.doc(noteId).update({'isPinned': !isPinned});
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to toggle pin: $e'));
    }
  }
}
