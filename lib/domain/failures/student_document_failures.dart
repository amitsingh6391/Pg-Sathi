import '../core/failure.dart';

/// Failures related to Student Document operations.
class StudentDocumentFailure extends Failure {
  const StudentDocumentFailure({String? message})
    : super(message: message ?? 'Student document operation failed');
}

class StudentDocumentLimitExceededFailure extends Failure {
  const StudentDocumentLimitExceededFailure({String? message})
    : super(message: message ?? 'Maximum 2 documents allowed');
}

class StudentDocumentNotFoundFailure extends Failure {
  const StudentDocumentNotFoundFailure({String? message})
    : super(message: message ?? 'Student document not found');
}


