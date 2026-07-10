import '../core/failure.dart';

/// Failures related to Membership operations.
class MembershipNotFoundFailure extends Failure {
  const MembershipNotFoundFailure({String? message})
    : super(message: message ?? 'Membership not found');
}

class MembershipExpiredFailure extends Failure {
  const MembershipExpiredFailure({String? message})
    : super(message: message ?? 'Membership has expired');
}

class MembershipInactiveFailure extends Failure {
  const MembershipInactiveFailure({String? message})
    : super(message: message ?? 'Membership is inactive');
}

class MembershipAlreadyExistsFailure extends Failure {
  const MembershipAlreadyExistsFailure({String? message})
    : super(
        message: message ?? 'Active membership already exists for this user',
      );
}

class InvalidMembershipDataFailure extends Failure {
  const InvalidMembershipDataFailure({String? message})
    : super(message: message ?? 'Invalid membership data');
}

class MembershipNotActiveFailure extends Failure {
  const MembershipNotActiveFailure({String? message})
    : super(message: message ?? 'Membership is not active');
}

class StudentNotFoundFailure extends Failure {
  const StudentNotFoundFailure({String? message})
    : super(message: message ?? 'Student not found with the provided details');
}

class InvalidExpiryDateFailure extends Failure {
  const InvalidExpiryDateFailure({String? message})
    : super(message: message ?? 'Expiry date must be in the future');
}
