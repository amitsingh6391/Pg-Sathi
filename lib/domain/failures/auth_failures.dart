import '../core/failure.dart';

/// Failures related to authentication operations.

class InvalidPhoneNumberFailure extends Failure {
  const InvalidPhoneNumberFailure({String? message})
    : super(message: message ?? 'Invalid phone number format');
}

class OtpSendFailure extends Failure {
  const OtpSendFailure({String? message})
    : super(message: message ?? 'Failed to send OTP');
}

class InvalidOtpFailure extends Failure {
  const InvalidOtpFailure({String? message})
    : super(message: message ?? 'Invalid OTP');
}

class OtpExpiredFailure extends Failure {
  const OtpExpiredFailure({String? message})
    : super(message: message ?? 'OTP has expired');
}

class NotAuthenticatedFailure extends Failure {
  const NotAuthenticatedFailure({String? message})
    : super(message: message ?? 'User is not authenticated');
}

class AuthSessionExpiredFailure extends Failure {
  const AuthSessionExpiredFailure({String? message})
    : super(message: message ?? 'Authentication session has expired');
}

class TooManyRequestsFailure extends Failure {
  const TooManyRequestsFailure({String? message})
    : super(message: message ?? 'Too many requests. Please try again later');
}
