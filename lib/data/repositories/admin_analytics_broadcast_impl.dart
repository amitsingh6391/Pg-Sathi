part of 'admin_analytics_repository_impl.dart';

class _BroadcastTargetResolver {
  const _BroadcastTargetResolver(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _librariesRef =>
      _firestore.collection('libraries');

  CollectionReference<Map<String, dynamic>> get _membershipsRef =>
      _firestore.collection('memberships');

  CollectionReference<Map<String, dynamic>> get _attendanceRef =>
      _firestore.collection('attendance');

  Future<Either<Failure, List<String>>> getAllOwnerIds() async {
    try {
      final snapshot =
          await _usersRef.where('role', isEqualTo: 'owner').get();
      return Right(snapshot.docs.map((doc) => doc.id).toList());
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get owner IDs: $e'));
    }
  }

  Future<Either<Failure, List<String>>> getAllStudentIds() async {
    try {
      final snapshot =
          await _usersRef.where('role', isEqualTo: 'student').get();
      return Right(snapshot.docs.map((doc) => doc.id).toList());
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get student IDs: $e'));
    }
  }

  Future<Either<Failure, List<String>>> getOwnerIdsForLibraries(
    List<String> libraryIds,
  ) async {
    try {
      if (libraryIds.isEmpty) return const Right([]);

      final ownerIds = <String>[];
      for (var i = 0; i < libraryIds.length; i += 10) {
        final batch = libraryIds.skip(i).take(10).toList();
        final snapshot = await _librariesRef
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (final doc in snapshot.docs) {
          final ownerId = doc.data()['ownerId'] as String?;
          if (ownerId != null) ownerIds.add(ownerId);
        }
      }

      return Right(ownerIds);
    } catch (e) {
      return Left(
        ServerFailure(message: 'Failed to get owner IDs for libraries: $e'),
      );
    }
  }

  Future<Either<Failure, List<String>>> getOwnerIdsWithLibrary() async {
    try {
      final snapshot = await _librariesRef.get();
      final ownerIds = <String>{};
      for (final doc in snapshot.docs) {
        final ownerId = doc.data()['ownerId'] as String?;
        if (ownerId != null && ownerId.isNotEmpty) ownerIds.add(ownerId);
      }
      return Right(ownerIds.toList());
    } catch (e) {
      return Left(
        ServerFailure(message: 'Failed to get owners with library: $e'),
      );
    }
  }

  Future<Either<Failure, List<String>>> getOwnerIdsWithoutLibrary() async {
    try {
      final allOwnersResult = await getAllOwnerIds();
      if (allOwnersResult.isLeft()) {
        return Left(
          allOwnersResult.fold((l) => l, (_) => const ServerFailure()),
        );
      }
      final withLibraryResult = await getOwnerIdsWithLibrary();
      if (withLibraryResult.isLeft()) {
        return Left(
          withLibraryResult.fold((l) => l, (_) => const ServerFailure()),
        );
      }

      final allOwners = allOwnersResult.getOrElse(() => []);
      final withLibrary = withLibraryResult.getOrElse(() => []);
      final withoutLibrary = allOwners.toSet()..removeAll(withLibrary);
      return Right(withoutLibrary.toList());
    } catch (e) {
      return Left(
        ServerFailure(message: 'Failed to get owners without library: $e'),
      );
    }
  }

  Future<Either<Failure, List<String>>>
      getStudentIdsWithActiveMembership() async {
    try {
      final snapshot =
          await _membershipsRef.where('status', isEqualTo: 'active').get();
      final studentIds = <String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final userId = (data['userId'] ?? data['studentId']) as String?;
        if (userId != null && userId.isNotEmpty) studentIds.add(userId);
      }
      return Right(studentIds.toList());
    } catch (e) {
      return Left(
        ServerFailure(
          message: 'Failed to get students with active membership: $e',
        ),
      );
    }
  }

  Future<Either<Failure, List<String>>> getActiveStudentIds({
    Duration window = const Duration(days: 30),
  }) async {
    try {
      final since = DateTime.now().subtract(window);
      final snapshot = await _attendanceRef
          .where(
            'checkInTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(since),
          )
          .get();

      final studentIds = <String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final sessions = data['sessions'] as List<dynamic>?;
        final legacyId = (data['userId'] ?? data['studentId']) as String?;

        if (sessions != null && sessions.isNotEmpty) {
          for (final session in sessions) {
            if (session is! Map<String, dynamic>) continue;
            final sessionCheckIn = session['checkInAt'] as Timestamp?;
            if (sessionCheckIn == null) continue;
            if (sessionCheckIn.toDate().isBefore(since)) continue;
            final id = (session['userId'] ?? session['studentId'] ?? legacyId)
                as String?;
            if (id != null && id.isNotEmpty) studentIds.add(id);
          }
        } else if (legacyId != null && legacyId.isNotEmpty) {
          studentIds.add(legacyId);
        }
      }

      return Right(studentIds.toList());
    } catch (e) {
      return Left(
        ServerFailure(message: 'Failed to get active students: $e'),
      );
    }
  }

  Future<Either<Failure, List<String>>> getStudentIdsForLibraries(
    List<String> libraryIds,
  ) async {
    try {
      if (libraryIds.isEmpty) return const Right([]);

      final studentIds = <String>{};
      for (var i = 0; i < libraryIds.length; i += 10) {
        final batch = libraryIds.skip(i).take(10).toList();
        final snapshot =
            await _membershipsRef.where('libraryId', whereIn: batch).get();

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final userId = (data['userId'] ?? data['studentId']) as String?;
          if (userId != null && userId.isNotEmpty) studentIds.add(userId);
        }
      }

      return Right(studentIds.toList());
    } catch (e) {
      return Left(
        ServerFailure(
          message: 'Failed to get student IDs for libraries: $e',
        ),
      );
    }
  }
}
