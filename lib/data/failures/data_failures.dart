import '../../domain/core/failure.dart';

/// Firebase/network related failures for data layer.

class ServerFailure extends Failure {
  const ServerFailure({String? message})
    : super(message: message ?? 'Server error occurred');
}

class CacheFailure extends Failure {
  const CacheFailure({String? message})
    : super(message: message ?? 'Cache error occurred');
}

class NetworkFailure extends Failure {
  const NetworkFailure({String? message})
    : super(message: message ?? 'Network error occurred');
}

class DocumentNotFoundFailure extends Failure {
  const DocumentNotFoundFailure({String? message})
    : super(message: message ?? 'Document not found');
}

class PermissionDeniedFailure extends Failure {
  const PermissionDeniedFailure({String? message})
    : super(message: message ?? 'Permission denied');
}

class InvalidDataFailure extends Failure {
  const InvalidDataFailure({String? message})
    : super(message: message ?? 'Invalid data format');
}

class UnknownFailure extends Failure {
  const UnknownFailure({String? message})
    : super(message: message ?? 'An unknown error occurred');
}

class ValidationFailure extends Failure {
  const ValidationFailure({String? message})
    : super(message: message ?? 'Validation failed');
}
