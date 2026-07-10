import 'package:dartz/dartz.dart';

import '../core/core.dart';
import '../entities/subscription.dart';
import '../repositories/subscription_repository.dart';

/// Use case for getting all subscriptions (admin).
class GetAllSubscriptions implements UseCase<List<Subscription>, NoParams> {
  const GetAllSubscriptions({required this.subscriptionRepository});

  final SubscriptionRepository subscriptionRepository;

  @override
  Future<Either<Failure, List<Subscription>>> call(NoParams params) async {
    return subscriptionRepository.getAllSubscriptions();
  }
}
