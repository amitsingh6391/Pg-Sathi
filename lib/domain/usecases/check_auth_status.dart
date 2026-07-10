import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// Use case for checking authentication status on app start.
///
/// Returns the authenticated user or null.
/// Device binding is not enforced - multiple users can share a device.
class CheckAuthStatus implements UseCase<AuthStatus, CheckAuthStatusParams> {
  const CheckAuthStatus({required this.authRepository});

  final AuthRepository authRepository;

  @override
  Future<Either<Failure, AuthStatus>> call(CheckAuthStatusParams params) async {
    final currentUserResult = await authRepository.getCurrentUser();

    return currentUserResult.fold((failure) => Left(failure), (user) {
      if (user == null) {
        return const Right(AuthStatus.notAuthenticated());
      }
      return Right(AuthStatus.authenticated(user));
    });
  }
}

/// Parameters for CheckAuthStatus use case.
class CheckAuthStatusParams extends Equatable {
  const CheckAuthStatusParams();

  @override
  List<Object?> get props => [];
}

/// Result of authentication status check.
class AuthStatus extends Equatable {
  const AuthStatus._({required this.isAuthenticated, this.user});

  const AuthStatus.authenticated(User user)
    : this._(isAuthenticated: true, user: user);

  const AuthStatus.notAuthenticated() : this._(isAuthenticated: false);

  final bool isAuthenticated;
  final User? user;

  @override
  List<Object?> get props => [isAuthenticated, user];
}
