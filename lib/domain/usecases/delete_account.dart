import 'package:dartz/dartz.dart';

import '../core/core.dart';
import '../repositories/auth_repository.dart';

/// Use case for permanently deleting the current user's account.
class DeleteAccount implements UseCase<void, NoParams> {
  const DeleteAccount({required this.authRepository});

  final AuthRepository authRepository;

  @override
  Future<Either<Failure, void>> call(NoParams params) async {
    return authRepository.deleteAccount();
  }
}
