import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/user.dart';

/// Repository interface for User aggregate.
abstract class UserRepository {
  /// Creates a new user.
  Future<Either<Failure, User>> createUser(User user);

  /// Retrieves a user by ID.
  Future<Either<Failure, User>> getUserById(String userId);

  /// Retrieves a user by email.
  Future<Either<Failure, User?>> getUserByEmail(String email);

  /// Retrieves a user by phone number.
  Future<Either<Failure, User?>> getUserByPhone(String phone);

  /// Updates user information.
  Future<Either<Failure, User>> updateUser(User user);

  /// Gets multiple users by their IDs.
  /// Returns a map of userId -> User for found users.
  Future<Either<Failure, Map<String, User>>> getUsersByIds(
    List<String> userIds,
  );

  /// Checks if a user exists.
  Future<Either<Failure, bool>> userExists(String userId);

  /// Gets all users with a specific role.
  Future<Either<Failure, List<User>>> getUsersByRole(UserRole role);

  /// Deletes a user by ID.
  Future<Either<Failure, void>> deleteUser(String userId);
}
