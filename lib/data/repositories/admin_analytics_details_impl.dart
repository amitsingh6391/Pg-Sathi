part of 'admin_analytics_repository_impl.dart';

class _ActivityDetailResolver {
  const _ActivityDetailResolver(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _librariesRef =>
      _firestore.collection('libraries');

  CollectionReference<Map<String, dynamic>> get _membershipsRef =>
      _firestore.collection('memberships');

  CollectionReference<Map<String, dynamic>> get _sessionsRef =>
      _firestore.collection('user_sessions');

  Future<Either<Failure, List<UserActivityDetail>>> getHourlyActiveUsers({
    required DateTime date,
    required int hour,
  }) async {
    try {
      final dayStart = DateTime(date.year, date.month, date.day);
      final hourStart = dayStart.add(Duration(hours: hour));
      final hourEnd = hourStart.add(const Duration(hours: 1));

      final snapshot = await _sessionsRef
          .where(
            'startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(hourStart),
          )
          .where('startTime', isLessThan: Timestamp.fromDate(hourEnd))
          .orderBy('startTime', descending: false)
          .get();

      if (snapshot.docs.isEmpty) return const Right([]);

      final sessionsByUser = <String, List<Map<String, dynamic>>>{};
      final userRoles = <String, String>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String?;
        final startTimeTs = data['startTime'] as Timestamp?;
        final endTimeTs = data['endTime'] as Timestamp?;
        final roleStr = data['role'] as String?;

        if (userId == null || startTimeTs == null) continue;

        sessionsByUser.putIfAbsent(userId, () => []).add({
          'startTime': startTimeTs.toDate(),
          'endTime': endTimeTs?.toDate(),
        });
        userRoles[userId] = roleStr ?? 'student';
      }

      final uniqueUserIds = sessionsByUser.keys.toList();
      final userDocs = await Future.wait(
        uniqueUserIds.map((id) => _usersRef.doc(id).get()),
      );

      final userDataMap = <String, Map<String, dynamic>>{};
      for (var i = 0; i < userDocs.length; i++) {
        if (userDocs[i].exists) {
          userDataMap[uniqueUserIds[i]] = userDocs[i].data()!;
        }
      }

      final libraryMap = await _resolveUserLibraries(
        uniqueUserIds: uniqueUserIds,
        userRoles: userRoles,
      );

      return Right(
        _buildActivityDetails(
          sessionsByUser: sessionsByUser,
          userRoles: userRoles,
          userDataMap: userDataMap,
          libraryMap: libraryMap,
        ),
      );
    } catch (e) {
      return Left(
        ServerFailure(message: 'Failed to get hourly active users: $e'),
      );
    }
  }

  Future<Either<Failure, List<UserActivityTimeline>>> getUserActivityDetails({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final dayStart =
          DateTime(startDate.year, startDate.month, startDate.day);
      final dayEnd = DateTime(endDate.year, endDate.month, endDate.day)
          .add(const Duration(days: 1));

      final snapshot = await _sessionsRef
          .where('userId', isEqualTo: userId)
          .where(
            'startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart),
          )
          .where('startTime', isLessThan: Timestamp.fromDate(dayEnd))
          .orderBy('startTime', descending: false)
          .get();

      final userDoc = await _usersRef.doc(userId).get();
      if (!userDoc.exists) {
        return const Left(ServerFailure(message: 'User not found'));
      }

      final userData = userDoc.data()!;
      final userName = userData['name'] as String? ?? 'Unknown User';
      final roleStr = userData['role'] as String?;
      final role = _parseUserRole(roleStr);

      final libraryInfo = await _resolveLibraryForUser(
        userId: userId,
        role: role,
      );

      final sessionsByDate = <DateTime, List<UserActivityDetail>>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final startTimeTs = data['startTime'] as Timestamp?;
        final endTimeTs = data['endTime'] as Timestamp?;

        if (startTimeTs == null) continue;

        final startTime = startTimeTs.toDate();
        final sessionDate =
            DateTime(startTime.year, startTime.month, startTime.day);

        sessionsByDate.putIfAbsent(sessionDate, () => []).add(
          UserActivityDetail(
            userId: userId,
            userName: userName,
            role: role,
            checkInTime: startTime,
            checkOutTime: endTimeTs?.toDate(),
            libraryName: libraryInfo?['name'],
            libraryId: libraryInfo?['id'],
          ),
        );
      }

      final timelines = sessionsByDate.entries.map((entry) {
        final totalDuration = entry.value.fold<int>(
          0,
          (total, session) => total + session.currentDurationMinutes,
        );
        return UserActivityTimeline(
          date: entry.key,
          sessions: entry.value,
          totalDuration: totalDuration,
        );
      }).toList();

      timelines.sort((a, b) => b.date.compareTo(a.date));
      return Right(timelines);
    } catch (e) {
      return Left(
        ServerFailure(message: 'Failed to get user activity details: $e'),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<Map<String, Map<String, String>>> _resolveUserLibraries({
    required List<String> uniqueUserIds,
    required Map<String, String> userRoles,
  }) async {
    final studentIds = uniqueUserIds
        .where((id) => _parseUserRole(userRoles[id]).name == 'student')
        .toList();
    final ownerIds = uniqueUserIds
        .where((id) => _parseUserRole(userRoles[id]).name == 'owner')
        .toList();

    final memberships = studentIds.isNotEmpty
        ? await Future.wait(
            studentIds.map(
              (userId) => _membershipsRef
                  .where('userId', isEqualTo: userId)
                  .where('status', isEqualTo: 'active')
                  .limit(1)
                  .get(),
            ),
          )
        : <QuerySnapshot<Map<String, dynamic>>>[];

    final ownerLibraries = ownerIds.isNotEmpty
        ? await Future.wait(
            ownerIds.map(
              (ownerId) => _librariesRef
                  .where('ownerId', isEqualTo: ownerId)
                  .limit(1)
                  .get(),
            ),
          )
        : <QuerySnapshot<Map<String, dynamic>>>[];

    final userLibraryMap = <String, Map<String, String>>{};

    // Collect unique library IDs from student memberships first,
    // then batch-fetch all library docs at once (avoids N+1).
    final studentLibraryIds = <String, String>{}; // studentId → libraryId
    for (var i = 0; i < studentIds.length; i++) {
      if (memberships[i].docs.isNotEmpty) {
        final libraryId =
            memberships[i].docs.first.data()['libraryId'] as String?;
        if (libraryId != null) {
          studentLibraryIds[studentIds[i]] = libraryId;
        }
      }
    }

    final uniqueLibIds = studentLibraryIds.values.toSet().toList();
    final libraryNameMap = <String, String>{}; // libraryId → name

    // Batch fetch library docs using whereIn (max 10 per batch)
    for (var start = 0; start < uniqueLibIds.length; start += 10) {
      final batch = uniqueLibIds.skip(start).take(10).toList();
      final snapshot = await _librariesRef
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (final doc in snapshot.docs) {
        libraryNameMap[doc.id] = doc.data()['name'] as String? ?? 'Unknown';
      }
    }

    // Map students to their library info
    for (final entry in studentLibraryIds.entries) {
      final name = libraryNameMap[entry.value];
      if (name != null) {
        userLibraryMap[entry.key] = {'id': entry.value, 'name': name};
      }
    }

    for (var i = 0; i < ownerIds.length; i++) {
      if (ownerLibraries[i].docs.isNotEmpty) {
        final data = ownerLibraries[i].docs.first.data();
        userLibraryMap[ownerIds[i]] = {
          'id': ownerLibraries[i].docs.first.id,
          'name': data['name'] as String? ?? 'Unknown',
        };
      }
    }

    return userLibraryMap;
  }

  Future<Map<String, String>?> _resolveLibraryForUser({
    required String userId,
    required UserRole role,
  }) async {
    if (role == UserRole.student) {
      final membershipSnapshot = await _membershipsRef
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (membershipSnapshot.docs.isNotEmpty) {
        final libraryId =
            membershipSnapshot.docs.first.data()['libraryId'] as String?;
        if (libraryId != null) {
          final libraryDoc = await _librariesRef.doc(libraryId).get();
          if (libraryDoc.exists) {
            return {
              'id': libraryId,
              'name': libraryDoc.data()?['name'] as String? ?? 'Unknown',
            };
          }
        }
      }
    } else if (role == UserRole.owner) {
      final librarySnapshot = await _librariesRef
          .where('ownerId', isEqualTo: userId)
          .limit(1)
          .get();

      if (librarySnapshot.docs.isNotEmpty) {
        final data = librarySnapshot.docs.first.data();
        return {
          'id': librarySnapshot.docs.first.id,
          'name': data['name'] as String? ?? 'Unknown',
        };
      }
    }
    return null;
  }

  List<UserActivityDetail> _buildActivityDetails({
    required Map<String, List<Map<String, dynamic>>> sessionsByUser,
    required Map<String, String> userRoles,
    required Map<String, Map<String, dynamic>> userDataMap,
    required Map<String, Map<String, String>> libraryMap,
  }) {
    final details = <UserActivityDetail>[];

    for (final userId in sessionsByUser.keys) {
      final userData = userDataMap[userId];
      if (userData == null) continue;

      final sessions = sessionsByUser[userId]!;
      final role = _parseUserRole(userRoles[userId]);
      final userName = userData['name'] as String? ?? 'Unknown User';
      final libraryInfo = libraryMap[userId];

      DateTime earliestCheckIn = sessions.first['startTime'];
      DateTime? latestCheckOut = sessions.first['endTime'];

      for (final session in sessions) {
        final checkIn = session['startTime'] as DateTime;
        final checkOut = session['endTime'] as DateTime?;

        if (checkIn.isBefore(earliestCheckIn)) earliestCheckIn = checkIn;

        if (checkOut != null) {
          if (latestCheckOut == null || checkOut.isAfter(latestCheckOut)) {
            latestCheckOut = checkOut;
          }
        } else {
          latestCheckOut = null;
        }
      }

      details.add(
        UserActivityDetail(
          userId: userId,
          userName: userName,
          role: role,
          checkInTime: earliestCheckIn,
          checkOutTime: latestCheckOut,
          libraryName: libraryInfo?['name'],
          libraryId: libraryInfo?['id'],
          sessionCount: sessions.length,
        ),
      );
    }

    details.sort((a, b) => a.checkInTime.compareTo(b.checkInTime));
    return details;
  }

  UserRole _parseUserRole(String? roleStr) {
    if (roleStr == null) return UserRole.student;
    switch (roleStr) {
      case 'student':
        return UserRole.student;
      case 'owner':
        return UserRole.owner;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.student;
    }
  }
}
