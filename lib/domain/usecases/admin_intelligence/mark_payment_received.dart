import 'package:dartz/dartz.dart';

import '../../../data/failures/data_failures.dart';
import '../../core/core.dart';
import '../../entities/admin_action.dart';
import '../../repositories/admin_intelligence_repository.dart';

/// Use case for marking a payment as received manually by admin.
class AdminMarkPaymentReceived implements UseCase<void, ManualPaymentRequest> {
  const AdminMarkPaymentReceived({required this.repository});

  final AdminIntelligenceRepository repository;

  @override
  Future<Either<Failure, void>> call(ManualPaymentRequest params) {
    // Validate amount
    if (params.amount <= 0) {
      return Future.value(
        Left(const ValidationFailure(message: 'Amount must be greater than 0')),
      );
    }
    return repository.markPaymentReceived(params);
  }
}
