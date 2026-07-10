import '../core/failure.dart';

/// Failures related to Library operations.
class LibraryNotFoundFailure extends Failure {
  const LibraryNotFoundFailure({String? message})
    : super(message: message ?? 'Library not found');
}

class LibraryAlreadyExistsFailure extends Failure {
  const LibraryAlreadyExistsFailure({String? message})
    : super(message: message ?? 'Library already exists');
}

class LibraryInactiveFailure extends Failure {
  const LibraryInactiveFailure({String? message})
    : super(message: message ?? 'Library is inactive');
}

class InvalidLibraryDataFailure extends Failure {
  const InvalidLibraryDataFailure({String? message})
    : super(message: message ?? 'Invalid library data');
}

class LibraryFullFailure extends Failure {
  const LibraryFullFailure({String? message})
    : super(message: message ?? 'Library has no available seats');
}

class LibraryPhotoLimitExceededFailure extends Failure {
  const LibraryPhotoLimitExceededFailure({String? message})
    : super(message: message ?? 'Maximum 5 photos allowed');
}

class LibraryPhotoUploadFailure extends Failure {
  const LibraryPhotoUploadFailure({String? message})
    : super(message: message ?? 'Failed to upload photo');
}

class LibraryPhotoDeleteFailure extends Failure {
  const LibraryPhotoDeleteFailure({String? message})
    : super(message: message ?? 'Failed to delete photo');
}
