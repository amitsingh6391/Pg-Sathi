import '../core/failure.dart';

/// Failures related to Seat operations.
class SeatNotFoundFailure extends Failure {
  const SeatNotFoundFailure({String? message})
    : super(message: message ?? 'Seat not found');
}

class SeatAlreadyOccupiedFailure extends Failure {
  const SeatAlreadyOccupiedFailure({String? message})
    : super(message: message ?? 'Seat is already occupied');
}

class SeatNotAvailableFailure extends Failure {
  const SeatNotAvailableFailure({String? message})
    : super(message: message ?? 'Seat is not available');
}

class SeatAlreadyAssignedToUserFailure extends Failure {
  const SeatAlreadyAssignedToUserFailure({String? message})
    : super(message: message ?? 'User already has a seat assigned');
}

class NoAvailableSeatsFailure extends Failure {
  const NoAvailableSeatsFailure({String? message})
    : super(message: message ?? 'No available seats');
}
