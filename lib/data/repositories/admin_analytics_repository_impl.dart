import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../domain/core/failure.dart';
import '../../domain/entities/admin_dashboard_data.dart';
import '../../domain/entities/admin_dashboard_stats.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/library_summary.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/user_activity_detail.dart';
import '../../domain/entities/user_activity_stats.dart';
import '../../domain/repositories/admin_analytics_repository.dart';
import '../failures/data_failures.dart';
import '../mappers/invoice_mapper.dart';
import '../models/invoice_dto.dart';

part 'admin_analytics_broadcast_impl.dart';
part 'admin_analytics_details_impl.dart';

/// Firestore implementation of AdminAnalyticsRepository.
/// Provides read-only access to platform-wide analytics.
///
/// Split into three files for maintainability:
/// - This file: dashboard data, user activity stats, invoices, hourly activity
/// - [_BroadcastTargetResolver]: notification target ID resolution
/// - [_ActivityDetailResolver]: hourly active user and timeline drill-downs
class AdminAnalyticsRepositoryImpl implements AdminAnalyticsRepository {
  AdminAnalyticsRepositoryImpl({required this.firestore})
      : _broadcastResolver = _BroadcastTargetResolver(firestore),
        _detailResolver = _ActivityDetailResolver(firestore);

  final FirebaseFirestore firestore;
  final _BroadcastTargetResolver _broadcastResolver;
  final _ActivityDetailResolver _detailResolver;

  CollectionReference<Map<String, dynamic>> get _librariesRef =>
      firestore.collection('libraries');

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _membershipsRef =>
      firestore.collection('memberships');

  CollectionReference<Map<String, dynamic>> get _subscriptionsRef =>
      firestore.collection('subscriptions');

  CollectionReference<Map<String, dynamic>> get _invoicesRef =>
      firestore.collection(InvoiceDto.collectionName);

  CollectionReference<Map<String, dynamic>> get _slotsRef =>
      firestore.collection('slots');

  CollectionReference<Map<String, dynamic>> get _sessionsRef =>
      firestore.collection('user_sessions');

  @override
  Future<Either<Failure, AdminDashboardData>> getDashboardData() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final sevenDaysAgo = today.subtract(const Duration(days: 7));
      final thirtyDaysAgo = today.subtract(const Duration(days: 30));

      // Single batch of reads — shared across stats and library summaries.
      // Previously getDashboardStats() and getLibraryAnalytics() each read
      // libraries, owners, and memberships independently (9 reads total).
      // Now we read each collection once (5 reads total, saving ~33%).
      final results = await Future.wait([
        _librariesRef.get(),
        _usersRef.where('role', isEqualTo: 'owner').get(),
        _membershipsRef.where('status', isEqualTo: 'active').get(),
        _subscriptionsRef.where('status', isEqualTo: 'active').get(),
        _slotsRef.where('isActive', isEqualTo: true).get(),
      ]);

      final librariesSnapshot = results[0];
      final ownersSnapshot = results[1];
      final membershipsSnapshot = results[2];
      final subscriptionsSnapshot = results[3];
      final slotsSnapshot = results[4];

      // --- Derive AdminDashboardStats ---
      final stats = _buildDashboardStats(
        librariesSnapshot: librariesSnapshot,
        membershipsSnapshot: membershipsSnapshot,
        ownersSnapshot: ownersSnapshot,
        today: today,
        sevenDaysAgo: sevenDaysAgo,
        thirtyDaysAgo: thirtyDaysAgo,
        now: now,
      );

      // --- Derive LibrarySummaries ---
      final summaries = _buildLibrarySummaries(
        librariesSnapshot: librariesSnapshot,
        ownersSnapshot: ownersSnapshot,
        membershipsSnapshot: membershipsSnapshot,
        subscriptionsSnapshot: subscriptionsSnapshot,
        slotsSnapshot: slotsSnapshot,
      );

      return Right(AdminDashboardData(stats: stats, librarySummaries: summaries));
    } catch (e) {
      return Left(
        ServerFailure(message: 'Failed to get dashboard data: $e'),
      );
    }
  }

  // ===========================================================================
  // Private helpers for getDashboardData
  // ===========================================================================

  AdminDashboardStats _buildDashboardStats({
    required QuerySnapshot<Map<String, dynamic>> librariesSnapshot,
    required QuerySnapshot<Map<String, dynamic>> membershipsSnapshot,
    required QuerySnapshot<Map<String, dynamic>> ownersSnapshot,
    required DateTime today,
    required DateTime sevenDaysAgo,
    required DateTime thirtyDaysAgo,
    required DateTime now,
  }) {
    int librariesToday = 0;
    int librariesLast7Days = 0;
    int librariesLast30Days = 0;

    for (final doc in librariesSnapshot.docs) {
      final createdAt = doc.data()['createdAt'] as Timestamp?;
      if (createdAt != null) {
        final date = createdAt.toDate();
        if (date.isAfter(today) ||
            (date.year == today.year &&
                date.month == today.month &&
                date.day == today.day)) {
          librariesToday++;
        }
        if (date.isAfter(sevenDaysAgo)) {
          librariesLast7Days++;
        }
        if (date.isAfter(thirtyDaysAgo)) {
          librariesLast30Days++;
        }
      }
    }

    return AdminDashboardStats(
      totalLibraries: librariesSnapshot.docs.length,
      librariesToday: librariesToday,
      librariesLast7Days: librariesLast7Days,
      librariesLast30Days: librariesLast30Days,
      totalActiveStudents: membershipsSnapshot.docs.length,
      totalActiveOwners: ownersSnapshot.docs.length,
      generatedAt: now,
    );
  }

  List<LibrarySummary> _buildLibrarySummaries({
    required QuerySnapshot<Map<String, dynamic>> librariesSnapshot,
    required QuerySnapshot<Map<String, dynamic>> ownersSnapshot,
    required QuerySnapshot<Map<String, dynamic>> membershipsSnapshot,
    required QuerySnapshot<Map<String, dynamic>> subscriptionsSnapshot,
    required QuerySnapshot<Map<String, dynamic>> slotsSnapshot,
  }) {
    // Owner lookup
    final ownerMap = <String, Map<String, dynamic>>{};
    for (final doc in ownersSnapshot.docs) {
      ownerMap[doc.id] = doc.data();
    }

    // Subscription lookup (latest end date per owner)
    final subscriptionMap = <String, String>{};
    final subscriptionEndDateMap = <String, DateTime>{};
    for (final doc in subscriptionsSnapshot.docs) {
      final data = doc.data();
      final ownerId = data['ownerId'] as String?;
      final status = data['status'] as String?;
      final endDate = data['endDate'] as Timestamp?;
      if (ownerId != null && status != null) {
        final currentEndDate = subscriptionEndDateMap[ownerId];
        final newEndDate = endDate?.toDate();
        if (currentEndDate == null ||
            (newEndDate != null && newEndDate.isAfter(currentEndDate))) {
          subscriptionMap[ownerId] = status;
          if (newEndDate != null) {
            subscriptionEndDateMap[ownerId] = newEndDate;
          }
        }
      }
    }

    // Membership counts per library
    final membershipCountMap = <String, int>{};
    for (final doc in membershipsSnapshot.docs) {
      final libraryId = doc.data()['libraryId'] as String?;
      if (libraryId != null) {
        membershipCountMap[libraryId] =
            (membershipCountMap[libraryId] ?? 0) + 1;
      }
    }

    // Slot capacities per library
    final slotCapacityMap = <String, int>{};
    for (final doc in slotsSnapshot.docs) {
      final data = doc.data();
      final libraryId = data['libraryId'] as String?;
      final capacity = data['capacity'] as int? ?? 0;
      if (libraryId != null) {
        slotCapacityMap[libraryId] =
            (slotCapacityMap[libraryId] ?? 0) + capacity;
      }
    }

    // Build summaries
    final summaries = <LibrarySummary>[];

    for (final doc in librariesSnapshot.docs) {
      final data = doc.data();
      final ownerId = data['ownerId'] as String?;
      if (ownerId == null) continue;

      final ownerData = ownerMap[ownerId];
      final ownerName = ownerData?['name'] as String? ?? 'Unknown';
      final ownerPhone = ownerData?['phone'] as String? ?? '';

      final totalSeats =
          slotCapacityMap[doc.id] ?? data['capacity'] as int? ?? 0;
      final activeMemberships = membershipCountMap[doc.id] ?? 0;
      final occupancyPercent =
          totalSeats > 0 ? (activeMemberships / totalSeats) * 100 : 0.0;

      final createdAtTimestamp = data['createdAt'] as Timestamp?;
      final createdAt = createdAtTimestamp?.toDate() ?? DateTime.now();

      summaries.add(
        LibrarySummary(
          libraryId: doc.id,
          libraryName: data['name'] as String? ?? 'Unknown Library',
          ownerId: ownerId,
          ownerName: ownerName,
          ownerPhone: ownerPhone,
          totalSeats: totalSeats,
          activeMemberships: activeMemberships,
          occupancyPercent: occupancyPercent,
          createdAt: createdAt,
          area: data['area'] as String?,
          subscriptionStatus: subscriptionMap[ownerId],
          subscriptionEndDate: subscriptionEndDateMap[ownerId],
        ),
      );
    }

    summaries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return summaries;
  }

  @override
  Future<Either<Failure, UserActivityStats>> getUserActivityStats() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final sevenDaysAgo = today.subtract(const Duration(days: 7));
      final fourteenDaysAgo = today.subtract(const Duration(days: 14));
      final thirtyDaysAgo = today.subtract(const Duration(days: 30));
      final tomorrowStart = today.add(const Duration(days: 1));

      // Get user sessions (actual app usage) for analysis
      final sessionsSnapshot = await _sessionsRef
          .where(
            'startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo),
          )
          .get();

      // Track unique students per time period
      final dailyStudents = <String>{};
      final weeklyStudents = <String>{};
      final monthlyStudents = <String>{};
      final yesterdayStudents = <String>{};
      final lastWeekStudents = <String>{};

      // Track hourly activity (sessions started per hour)
      final hourlySessionStarts = List<int>.filled(24, 0);
      final hourlyActiveUsers = List<Set<String>>.generate(24, (_) => {});

      // Track unique owners
      final dailyOwners = <String>{};
      final weeklyOwners = <String>{};

      for (final doc in sessionsSnapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String?;
        final roleStr = data['role'] as String?;
        final startTimeTs = data['startTime'] as Timestamp?;

        if (userId == null || startTimeTs == null) continue;

        final startTime = startTimeTs.toDate();
        final isStudent = roleStr == 'student';
        final isOwner = roleStr == 'owner';

        // Categorize by time period for students
        if (isStudent) {
          // Today
          if (startTime.isAfter(today) && startTime.isBefore(tomorrowStart)) {
            dailyStudents.add(userId);
            // Track hourly activity for today
            hourlySessionStarts[startTime.hour]++;
            hourlyActiveUsers[startTime.hour].add(userId);
          }

          // Yesterday
          if (startTime.isAfter(yesterday) && startTime.isBefore(today)) {
            yesterdayStudents.add(userId);
          }

          // Last 7 days
          if (startTime.isAfter(sevenDaysAgo)) {
            weeklyStudents.add(userId);
          }

          // 8-14 days ago
          if (startTime.isAfter(fourteenDaysAgo) &&
              startTime.isBefore(sevenDaysAgo)) {
            lastWeekStudents.add(userId);
          }

          // Last 30 days
          if (startTime.isAfter(thirtyDaysAgo)) {
            monthlyStudents.add(userId);
          }
        }

        // Track owner activity
        if (isOwner) {
          if (startTime.isAfter(today) && startTime.isBefore(tomorrowStart)) {
            dailyOwners.add(userId);
          }
          if (startTime.isAfter(sevenDaysAgo)) {
            weeklyOwners.add(userId);
          }
        }
      }

      // Build hourly activity breakdown
      final hourlyActivity = <HourlyActivity>[];
      for (int i = 0; i < 24; i++) {
        hourlyActivity.add(
          HourlyActivity(
            hour: i,
            activeUsers: hourlyActiveUsers[i].length,
            checkIns: hourlySessionStarts[i],
          ),
        );
      }

      // Find peak hours (top 3 by session starts)
      final sortedHours = List.generate(24, (i) => i)
        ..sort(
          (a, b) => hourlySessionStarts[b].compareTo(hourlySessionStarts[a]),
        );
      final peakHours = sortedHours.take(3).toList();

      // Calculate comparisons
      double? todayVsYesterday;
      if (yesterdayStudents.isNotEmpty) {
        todayVsYesterday =
            ((dailyStudents.length - yesterdayStudents.length) /
                yesterdayStudents.length) *
            100;
      }

      double? thisWeekVsLastWeek;
      if (lastWeekStudents.isNotEmpty) {
        thisWeekVsLastWeek =
            ((weeklyStudents.length - lastWeekStudents.length) /
                lastWeekStudents.length) *
            100;
      }

      return Right(
        UserActivityStats(
          dailyActiveStudents: dailyStudents.length,
          weeklyActiveStudents: weeklyStudents.length,
          monthlyActiveStudents: monthlyStudents.length,
          dailyActiveOwners: dailyOwners.length,
          weeklyActiveOwners: weeklyOwners.length,
          hourlyActivityBreakdown: hourlyActivity,
          peakHours: peakHours,
          todayVsYesterday: todayVsYesterday,
          thisWeekVsLastWeek: thisWeekVsLastWeek,
          generatedAt: now,
        ),
      );
    } catch (e) {
      return Left(
        ServerFailure(message: 'Failed to get user activity stats: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, List<Invoice>>> getInvoices({
    String? libraryId,
    String? ownerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _invoicesRef;

      if (libraryId != null) {
        query = query.where('libraryId', isEqualTo: libraryId);
      }

      if (ownerId != null) {
        query = query.where('ownerId', isEqualTo: ownerId);
      }

      if (startDate != null) {
        query = query.where(
          'generatedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'generatedAt',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      final snapshot = await query
          .orderBy('generatedAt', descending: true)
          .get();

      final invoices = snapshot.docs
          .map((doc) => InvoiceMapper.toEntity(InvoiceDto.fromFirestore(doc)))
          .toList();

      return Right(invoices);
    } catch (e) {
      // If composite index error, fall back to simpler query
      if (e.toString().contains('index')) {
        try {
          final snapshot = await _invoicesRef.get();
          var invoices = snapshot.docs
              .map(
                (doc) => InvoiceMapper.toEntity(InvoiceDto.fromFirestore(doc)),
              )
              .toList();

          // Filter in memory
          if (libraryId != null) {
            invoices = invoices.where((i) => i.libraryId == libraryId).toList();
          }
          if (ownerId != null) {
            invoices = invoices.where((i) => i.ownerId == ownerId).toList();
          }
          if (startDate != null) {
            invoices = invoices
                .where((i) => i.generatedAt.isAfter(startDate))
                .toList();
          }
          if (endDate != null) {
            invoices = invoices
                .where((i) => i.generatedAt.isBefore(endDate))
                .toList();
          }

          // Sort by date
          invoices.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));

          return Right(invoices);
        } catch (fallbackError) {
          return Left(
            ServerFailure(message: 'Failed to get invoices: $fallbackError'),
          );
        }
      }
      return Left(ServerFailure(message: 'Failed to get invoices: $e'));
    }
  }

  // ===========================================================================
  // Broadcast notification target resolution — delegated to part file
  // ===========================================================================

  @override
  Future<Either<Failure, List<String>>> getAllOwnerIds() =>
      _broadcastResolver.getAllOwnerIds();

  @override
  Future<Either<Failure, List<String>>> getAllStudentIds() =>
      _broadcastResolver.getAllStudentIds();

  @override
  Future<Either<Failure, List<String>>> getOwnerIdsForLibraries(
    List<String> libraryIds,
  ) =>
      _broadcastResolver.getOwnerIdsForLibraries(libraryIds);

  @override
  Future<Either<Failure, List<String>>> getOwnerIdsWithLibrary() =>
      _broadcastResolver.getOwnerIdsWithLibrary();

  @override
  Future<Either<Failure, List<String>>> getOwnerIdsWithoutLibrary() =>
      _broadcastResolver.getOwnerIdsWithoutLibrary();

  @override
  Future<Either<Failure, List<String>>>
      getStudentIdsWithActiveMembership() =>
          _broadcastResolver.getStudentIdsWithActiveMembership();

  @override
  Future<Either<Failure, List<String>>> getActiveStudentIds({
    Duration window = const Duration(days: 30),
  }) =>
      _broadcastResolver.getActiveStudentIds(window: window);

  @override
  Future<Either<Failure, List<String>>> getStudentIdsForLibraries(
    List<String> libraryIds,
  ) =>
      _broadcastResolver.getStudentIdsForLibraries(libraryIds);

  // ===========================================================================
  // User activity details — delegated to part file
  // ===========================================================================

  @override
  Future<Either<Failure, List<UserActivityDetail>>> getHourlyActiveUsers({
    required DateTime date,
    required int hour,
  }) =>
      _detailResolver.getHourlyActiveUsers(date: date, hour: hour);

  @override
  Future<Either<Failure, List<UserActivityTimeline>>> getUserActivityDetails({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) =>
      _detailResolver.getUserActivityDetails(
        userId: userId,
        startDate: startDate,
        endDate: endDate,
      );
}
