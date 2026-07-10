import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../core/usecase.dart';
import '../repositories/subscription_repository.dart';

/// Use case for deleting a subscription (admin only).
/// This permanently removes the subscription record from the system.
class DeleteSubscription implements UseCase<void, DeleteSubscriptionParams> {
  final SubscriptionRepository repository;

  DeleteSubscription(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteSubscriptionParams params) async {
    return await repository.deleteSubscription(params.subscriptionId);
  }
}

class DeleteSubscriptionParams {
  final String subscriptionId;
  final String adminId;

  DeleteSubscriptionParams({
    required this.subscriptionId,
    required this.adminId,
  });
}
