import 'package:dartz/dartz.dart';

import '../../core/core.dart';
import '../../entities/admin_action.dart';
import '../../repositories/admin_intelligence_repository.dart';

/// Use case for removing a custom discount from a library.
class RemoveDiscount implements UseCase<void, RemoveDiscountRequest> {
  const RemoveDiscount({required this.repository});

  final AdminIntelligenceRepository repository;

  @override
  Future<Either<Failure, void>> call(RemoveDiscountRequest params) {
    return repository.removeDiscount(params);
  }
}
