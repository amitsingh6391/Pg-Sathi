import 'package:dartz/dartz.dart';

import '../../core/core.dart';
import '../../entities/churn_data.dart';
import '../../repositories/admin_intelligence_repository.dart';

/// Use case for getting churn and retention data.
class GetChurnData implements UseCase<ChurnData, NoParams> {
  const GetChurnData({required this.repository});

  final AdminIntelligenceRepository repository;

  @override
  Future<Either<Failure, ChurnData>> call(NoParams params) {
    return repository.getChurnData();
  }
}
