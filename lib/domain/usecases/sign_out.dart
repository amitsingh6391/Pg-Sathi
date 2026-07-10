import 'package:dartz/dartz.dart';

import '../core/core.dart';
import '../repositories/auth_repository.dart';

/// Use case for signing out the current user.
class SignOut implements UseCase<void, NoParams> {
  const SignOut({required this.authRepository});

  final AuthRepository authRepository;

  @override
  Future<Either<Failure, void>> call(NoParams params) async {
    return authRepository.signOut();
  }
}
