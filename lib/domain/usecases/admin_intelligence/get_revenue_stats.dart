import 'package:dartz/dartz.dart';

import '../../core/core.dart';
import '../../entities/revenue_stats.dart';
import '../../repositories/admin_intelligence_repository.dart';

/// Use case for getting comprehensive revenue statistics.
class GetRevenueStats implements UseCase<RevenueStats, NoParams> {
  const GetRevenueStats({required this.repository});

  final AdminIntelligenceRepository repository;

  @override
  Future<Either<Failure, RevenueStats>> call(NoParams params) {
    return repository.getRevenueStats();
  }
}
