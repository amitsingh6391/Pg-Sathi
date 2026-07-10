import 'package:dartz/dartz.dart';

import '../../core/core.dart';
import '../../entities/admin_action.dart';
import '../../repositories/admin_intelligence_repository.dart';

/// Use case for suspending a library.
class SuspendLibrary implements UseCase<void, SuspendLibraryRequest> {
  const SuspendLibrary({required this.repository});

  final AdminIntelligenceRepository repository;

  @override
  Future<Either<Failure, void>> call(SuspendLibraryRequest params) {
    return repository.suspendLibrary(params);
  }
}

/// Use case for unsuspending a library.
class UnsuspendLibrary implements UseCase<void, UnsuspendLibraryParams> {
  const UnsuspendLibrary({required this.repository});

  final AdminIntelligenceRepository repository;

  @override
  Future<Either<Failure, void>> call(UnsuspendLibraryParams params) {
    return repository.unsuspendLibrary(
      libraryId: params.libraryId,
      reason: params.reason,
      adminId: params.adminId,
    );
  }
}

class UnsuspendLibraryParams {
  const UnsuspendLibraryParams({
    required this.libraryId,
    required this.reason,
    required this.adminId,
  });

  final String libraryId;
  final String reason;
  final String adminId;
}
