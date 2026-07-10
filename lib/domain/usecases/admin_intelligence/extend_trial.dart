import 'package:dartz/dartz.dart';

import '../../../data/failures/data_failures.dart';
import '../../core/core.dart';
import '../../entities/admin_action.dart';
import '../../repositories/admin_intelligence_repository.dart';

/// Use case for extending a library's trial period.
class ExtendTrial implements UseCase<void, ExtendTrialRequest> {
  const ExtendTrial({required this.repository});

  final AdminIntelligenceRepository repository;

  @override
  Future<Either<Failure, void>> call(ExtendTrialRequest params) {
    // Validate max 7 days extension
    if (params.extensionDays > 7) {
      return Future.value(
        Left(
          const ValidationFailure(message: 'Extension cannot exceed 7 days'),
        ),
      );
    }
    return repository.extendTrial(params);
  }
}
