import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:intl/intl.dart';
import 'package:pg_manager/domain/core/failure.dart';

import '../failures/data_failures.dart';
import '../../domain/entities/whatsapp_reminder.dart';
import '../../domain/repositories/whatsapp_reminder_repository.dart';

/// Firestore implementation of WhatsAppReminderRepository.
class WhatsAppReminderRepositoryImpl implements WhatsAppReminderRepository {
  const WhatsAppReminderRepositoryImpl({required this.firestore});

  final FirebaseFirestore firestore;

  @override
  Future<Either<Failure, List<WhatsAppReminder>>> getExpiringReminders({
    required String libraryId,
    required int daysThreshold,
  }) async {
    try {
      final now = DateTime.now();
      // Use now (not today at 00:00) to match push notification logic
      // Push notifications use DateTime.now() directly

      // Get all active memberships for the library
      // We'll filter by daysRemaining in memory to match push notification logic
      final snapshot = await firestore
          .collection('memberships')
          .where('libraryId', isEqualTo: libraryId)
          .where('status', isEqualTo: 'active')
          .get();

      // Filter memberships by expiry date first
      final expiringMemberships = <DocumentSnapshot<Map<String, dynamic>>>[];
      final today = DateTime(now.year, now.month, now.day);

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final endDateValue = data['endDate'];
        if (endDateValue == null || endDateValue is! Timestamp) continue;

        final endDate = endDateValue.toDate();
        final isExpired = now.isAfter(endDate);
        final daysRemaining = isExpired ? 0 : endDate.difference(now).inDays;

        if (daysRemaining > 0 && daysRemaining <= daysThreshold) {
          expiringMemberships.add(doc);
        }
      }

      if (expiringMemberships.isEmpty) {
        return const Right([]);
      }

      // Batch fetch all required data in parallel
      final userIds = expiringMemberships
          .map((doc) => doc.data()?['userId'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toSet()
          .toList();

      final libraryIds = expiringMemberships
          .map((doc) => doc.data()?['libraryId'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toSet()
          .toList();

      // Fetch users and libraries in parallel
      final results = await Future.wait([
        _batchFetchUsers(userIds),
        _batchFetchLibraries(libraryIds),
        _batchFetchReminderLogs(expiringMemberships, now),
      ]);

      final usersMap = results[0] as Map<String, Map<String, dynamic>>;
      final librariesMap = results[1] as Map<String, String>;
      final logsMap = results[2] as Map<String, int>;

      // Build reminders using cached data
      final reminders = <WhatsAppReminder>[];
      for (final doc in expiringMemberships) {
        final reminder = _buildReminderFromCache(
          doc,
          today,
          usersMap,
          librariesMap,
          logsMap,
        );
        if (reminder != null) {
          reminders.add(reminder);
        }
      }

      reminders.sort((a, b) => a.daysUntilExpiry.compareTo(b.daysUntilExpiry));

      return Right(reminders);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to load reminders: $e'));
    }
  }

  /// Batch fetches users in parallel (batches of 10 due to Firestore limit).
  Future<Map<String, Map<String, dynamic>>> _batchFetchUsers(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) return {};

    final usersMap = <String, Map<String, dynamic>>{};
    const batchSize = 10;

    // Fetch in parallel batches
    final futures = <Future<void>>[];
    for (var i = 0; i < userIds.length; i += batchSize) {
      final batch = userIds.skip(i).take(batchSize).toList();
      futures.add(
        firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get()
            .then((snapshot) {
          for (final doc in snapshot.docs) {
            usersMap[doc.id] = doc.data();
          }
        }),
      );
    }

    await Future.wait(futures);
    return usersMap;
  }

  /// Batch fetches libraries in parallel (batches of 10 due to Firestore limit).
  Future<Map<String, String>> _batchFetchLibraries(
    List<String> libraryIds,
  ) async {
    if (libraryIds.isEmpty) return {};

    final librariesMap = <String, String>{};
    const batchSize = 10;

    // Fetch in parallel batches
    final futures = <Future<void>>[];
    for (var i = 0; i < libraryIds.length; i += batchSize) {
      final batch = libraryIds.skip(i).take(batchSize).toList();
      futures.add(
        firestore
            .collection('libraries')
            .where(FieldPath.documentId, whereIn: batch)
            .get()
            .then((snapshot) {
          for (final doc in snapshot.docs) {
            final data = doc.data();
            librariesMap[doc.id] = (data['name'] as String?) ?? 'Library';
          }
        }),
      );
    }

    await Future.wait(futures);
    return librariesMap;
  }

  /// Batch fetches reminder logs in parallel.
  Future<Map<String, int>> _batchFetchReminderLogs(
    List<DocumentSnapshot<Map<String, dynamic>>> memberships,
    DateTime now,
  ) async {
    if (memberships.isEmpty) return {};

    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final logIds = memberships
        .map((doc) => '${doc.id}_$todayStr')
        .toList();

    const batchSize = 10;
    final logsMap = <String, int>{};

    // Fetch in parallel batches
    final futures = <Future<void>>[];
    for (var i = 0; i < logIds.length; i += batchSize) {
      final batch = logIds.skip(i).take(batchSize).toList();
      futures.add(
        firestore
            .collection('whatsapp_reminder_logs')
            .where(FieldPath.documentId, whereIn: batch)
            .get()
            .then((snapshot) {
          for (final doc in snapshot.docs) {
            logsMap[doc.id] = (doc.data()['count'] ?? 0) as int;
          }
        }),
      );
    }

    await Future.wait(futures);
    return logsMap;
  }

  /// Builds reminder from cached data (much faster than sequential fetches).
  WhatsAppReminder? _buildReminderFromCache(
    DocumentSnapshot<Map<String, dynamic>> membershipDoc,
    DateTime today,
    Map<String, Map<String, dynamic>> usersMap,
    Map<String, String> librariesMap,
    Map<String, int> logsMap,
  ) {
    final data = membershipDoc.data();
    if (data == null) return null;

    final userId = data['userId'] as String?;
    final membershipPhone = data['phoneNumber'] as String?;
    final membershipName = data['studentName'] as String?;

    // Get user data from cache
    String? phone;
    String? studentName;
    String? studentId;

    if (userId != null && usersMap.containsKey(userId)) {
      final userData = usersMap[userId]!;
      phone = userData['phone'] as String?;
      studentName = userData['name'] as String?;
      studentId = userId;
    }

    // Fallback to membership data
    phone = phone ?? membershipPhone;
    studentName = studentName ?? membershipName;
    studentId = studentId ?? membershipDoc.id;

    // Must have a phone number
    phone = phone?.trim();
    if (phone == null || phone.isEmpty) {
      return null;
    }

    final expiryDate = (data['endDate'] as Timestamp).toDate();
    final daysUntil = expiryDate.difference(today).inDays;

    final libraryId = data['libraryId'] as String?;
    final libraryName = (libraryId != null && librariesMap.containsKey(libraryId))
        ? librariesMap[libraryId]!
        : 'Library';

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final logKey = '${membershipDoc.id}_$todayStr';
    final todayCount = logsMap[logKey] ?? 0;

    return WhatsAppReminder(
      studentId: studentId,
      studentName: studentName ?? 'Student',
      studentPhone: phone,
      membershipId: membershipDoc.id,
      expiryDate: expiryDate,
      libraryName: libraryName,
      daysUntilExpiry: daysUntil,
      todayReminderCount: todayCount,
    );
  }

  @override
  Future<Either<Failure, void>> logReminderSent({
    required String membershipId,
  }) async {
    try {
      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);

      await firestore
          .collection('whatsapp_reminder_logs')
          .doc('${membershipId}_$today')
          .set({
            'sentAt': FieldValue.serverTimestamp(),
            'count': FieldValue.increment(1),
            'date': today,
          }, SetOptions(merge: true));

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to log reminder: $e'));
    }
  }

  /// Batch logs multiple reminders (optimized for bulk operations).
  Future<Either<Failure, void>> batchLogRemindersSent({
    required List<String> membershipIds,
  }) async {
    try {
      if (membershipIds.isEmpty) {
        return const Right(null);
      }

      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);
      final batch = firestore.batch();
      final logsRef = firestore.collection('whatsapp_reminder_logs');

      for (final membershipId in membershipIds) {
        final logDoc = logsRef.doc('${membershipId}_$today');
        batch.set(logDoc, {
          'sentAt': FieldValue.serverTimestamp(),
          'count': FieldValue.increment(1),
          'date': today,
        }, SetOptions(merge: true));
      }

      await batch.commit();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to batch log reminders: $e'));
    }
  }
}
