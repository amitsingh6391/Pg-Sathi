import '../core/failure.dart';

/// Failures related to User operations.
class UserNotFoundFailure extends Failure {
  const UserNotFoundFailure({String? message})
    : super(message: message ?? 'User not found');
}

class UserAlreadyExistsFailure extends Failure {
  const UserAlreadyExistsFailure({String? message})
    : super(message: message ?? 'User already exists');
}

class InvalidUserDataFailure extends Failure {
  const InvalidUserDataFailure({String? message})
    : super(message: message ?? 'Invalid user data');
}

class UnauthorizedUserFailure extends Failure {
  const UnauthorizedUserFailure({String? message})
    : super(message: message ?? 'User is not authorized for this action');
}
