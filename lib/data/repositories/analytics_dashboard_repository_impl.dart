import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/analytics_summary.dart';
import '../../domain/repositories/analytics_dashboard_repository.dart';

/// Firestore implementation of analytics dashboard repository.
class AnalyticsDashboardRepositoryImpl implements AnalyticsDashboardRepository {
  final FirebaseFirestore _firestore;

  AnalyticsDashboardRepositoryImpl(this._firestore);

  @override
  Future<Map<String, int>> getEventCounts({
    String? role,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('analytics_events');

      if (role != null) {
        query = query.where('role', isEqualTo: role);
      }
      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: endDate);
      }

      final snapshot = await query.get();
      final counts = <String, int>{};

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final eventName = data['event_name'] as String?;
        if (eventName != null) {
          counts[eventName] = (counts[eventName] ?? 0) + 1;
        }
      }

      return counts;
    } catch (e) {
      return {};
    }
  }

  @override
  Future<Map<String, int>> getPlatformCounts({
    String? role,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('analytics_events');

      if (role != null) {
        query = query.where('role', isEqualTo: role);
      }
      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: endDate);
      }

      final snapshot = await query.get();
      final counts = <String, int>{};

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final platform = data['platform'] as String?;
        if (platform != null) {
          counts[platform] = (counts[platform] ?? 0) + 1;
        }
      }

      return counts;
    } catch (e) {
      return {};
    }
  }

  @override
  Future<Map<String, int>> getRoleCounts({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('analytics_events');

      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: endDate);
      }

      final snapshot = await query.get();
      final counts = <String, int>{};

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final role = data['role'] as String?;
        if (role != null) {
          counts[role] = (counts[role] ?? 0) + 1;
        }
      }

      return counts;
    } catch (e) {
      return {};
    }
  }

  @override
  Stream<List<AnalyticsSummary>> getRecentEvents({int limit = 10}) {
    return _firestore
        .collection('analytics_events')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return AnalyticsSummary(
          eventName: data['event_name'] as String? ?? 'unknown',
          userId: data['user_id'] as String?,
          role: data['role'] as String?,
          libraryId: data['library_id'] as String?,
          platform: data['platform'] as String?,
          parameters: (data['parameters'] as Map<String, dynamic>?) ?? {},
          timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
    });
  }
}
