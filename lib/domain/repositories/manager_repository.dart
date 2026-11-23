import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/manager_access.dart';

/// Owner-side management of branch managers.
abstract class ManagerRepository {
  /// Gives [phone] access to [libraryId]. Takes effect on their next sign-in.
  Future<Either<Failure, void>> inviteManager({
    required String phone,
    required String ownerId,
    required String libraryId,
  });

  /// Pending invites and active managers of [ownerId].
  Future<Either<Failure, List<ManagerAccess>>> getManagers(String ownerId);

  /// Removes access; pending invites are deleted, active managers lose access.
  Future<Either<Failure, void>> revokeManager(ManagerAccess access);
}
