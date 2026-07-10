import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:pg_manager/data/failures/data_failures.dart';
import 'package:pg_manager/domain/core/failure.dart';
import 'package:pg_manager/domain/entities/user.dart';
import 'package:pg_manager/domain/entities/user_session.dart';
import 'package:pg_manager/domain/repositories/user_session_repository.dart';

/// Implementation of UserSessionRepository using Firestore.
class UserSessionRepositoryImpl implements UserSessionRepository {
  UserSessionRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _sessionsRef =>
      _firestore.collection('user_sessions');

  @override
  Future<Either<Failure, UserSession>> startSession({
    required String userId,
    required UserRole role,
    String? deviceId,
  }) async {
    try {
      final now = DateTime.now();
      final sessionData = {
        'userId': userId,
        'startTime': Timestamp.fromDate(now),
        'lastActiveTime': Timestamp.fromDate(now),
        'role': _roleToString(role),
        'deviceId': deviceId,
        'endTime': null,
      };

      final docRef = await _sessionsRef.add(sessionData);

      final session = UserSession(
        id: docRef.id,
        userId: userId,
        startTime: now,
        lastActiveTime: now,
        role: role,
        deviceId: deviceId,
      );

      return Right(session);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to start session: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateLastActive(String sessionId) async {
    try {
      await _sessionsRef.doc(sessionId).update({
        'lastActiveTime': Timestamp.fromDate(DateTime.now()),
      });
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to update session: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> endSession(String sessionId) async {
    try {
      final now = DateTime.now();
      await _sessionsRef.doc(sessionId).update({
        'endTime': Timestamp.fromDate(now),
        'lastActiveTime': Timestamp.fromDate(now),
      });
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to end session: $e'));
    }
  }

  @override
  Future<Either<Failure, List<UserSession>>> getUserSessions({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final snapshot = await _sessionsRef
          .where('userId', isEqualTo: userId)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('startTime', descending: true)
          .get();

      final sessions = snapshot.docs
          .map((doc) => _sessionFromDoc(doc))
          .whereType<UserSession>()
          .toList();

      return Right(sessions);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get user sessions: $e'));
    }
  }

  @override
  Future<Either<Failure, List<UserSession>>> getStudentSessions({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final snapshot = await _sessionsRef
          .where('role', isEqualTo: 'student')
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      final sessions = snapshot.docs
          .map((doc) => _sessionFromDoc(doc))
          .whereType<UserSession>()
          .toList();

      return Right(sessions);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get student sessions: $e'));
    }
  }

  @override
  Future<Either<Failure, List<UserSession>>> getOwnerSessions({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final snapshot = await _sessionsRef
          .where('role', isEqualTo: 'owner')
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      final sessions = snapshot.docs
          .map((doc) => _sessionFromDoc(doc))
          .whereType<UserSession>()
          .toList();

      return Right(sessions);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get owner sessions: $e'));
    }
  }

  @override
  Future<Either<Failure, UserSession?>> getActiveSession(String userId) async {
    try {
      final snapshot = await _sessionsRef
          .where('userId', isEqualTo: userId)
          .where('endTime', isEqualTo: null)
          .orderBy('startTime', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return const Right(null);
      }

      final session = _sessionFromDoc(snapshot.docs.first);
      return Right(session);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get active session: $e'));
    }
  }

  // ============================================================
  // Private Helpers
  // ============================================================

  UserSession? _sessionFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      final data = doc.data();
      if (data == null) return null;

      final startTime = (data['startTime'] as Timestamp?)?.toDate();
      if (startTime == null) return null;

      return UserSession(
        id: doc.id,
        userId: data['userId'] as String,
        startTime: startTime,
        endTime: (data['endTime'] as Timestamp?)?.toDate(),
        lastActiveTime: (data['lastActiveTime'] as Timestamp?)?.toDate(),
        role: _parseUserRole(data['role'] as String?),
        deviceId: data['deviceId'] as String?,
      );
    } catch (e) {
      return null;
    }
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

  String _roleToString(UserRole role) {
    switch (role) {
      case UserRole.student:
        return 'student';
      case UserRole.owner:
        return 'owner';
      case UserRole.admin:
        return 'admin';
    }
  }
}
