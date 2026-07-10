import 'package:dartz/dartz.dart';

import '../core/core.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// Use case for getting the currently authenticated user.
///
/// Returns the user if authenticated, null otherwise.
class GetCurrentUser implements UseCase<User?, NoParams> {
  const GetCurrentUser({required this.authRepository});

  final AuthRepository authRepository;

  @override
  Future<Either<Failure, User?>> call(NoParams params) async {
    return authRepository.getCurrentUser();
  }
}
