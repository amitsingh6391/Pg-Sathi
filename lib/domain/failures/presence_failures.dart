import '../core/failure.dart';

/// Failures related to Presence operations.
class PresenceNotFoundFailure extends Failure {
  const PresenceNotFoundFailure({String? message})
    : super(message: message ?? 'Presence record not found');
}

class AlreadyCheckedInFailure extends Failure {
  const AlreadyCheckedInFailure({String? message})
    : super(message: message ?? 'User is already checked in');
}

class NotCheckedInFailure extends Failure {
  const NotCheckedInFailure({String? message})
    : super(message: message ?? 'User is not checked in');
}

class InvalidPresenceTimeFailure extends Failure {
  const InvalidPresenceTimeFailure({String? message})
    : super(message: message ?? 'Invalid presence time');
}

class DailyPresenceAlreadyRecordedFailure extends Failure {
  const DailyPresenceAlreadyRecordedFailure({String? message})
    : super(message: message ?? 'Daily presence already recorded');
}
