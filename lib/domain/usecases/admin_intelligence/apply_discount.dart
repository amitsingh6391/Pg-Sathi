import 'package:dartz/dartz.dart';

import '../../../data/failures/data_failures.dart';
import '../../core/core.dart';
import '../../entities/admin_action.dart';
import '../../repositories/admin_intelligence_repository.dart';

/// Use case for applying a custom discount to a library.
class ApplyDiscount implements UseCase<void, ApplyDiscountRequest> {
  const ApplyDiscount({required this.repository});

  final AdminIntelligenceRepository repository;

  @override
  Future<Either<Failure, void>> call(ApplyDiscountRequest params) {
    // Validate discount percentage
    if (params.discountPercent < 0 || params.discountPercent > 100) {
      return Future.value(
        Left(
          const ValidationFailure(message: 'Discount must be between 0-100%'),
        ),
      );
    }
    return repository.applyDiscount(params);
  }
}
