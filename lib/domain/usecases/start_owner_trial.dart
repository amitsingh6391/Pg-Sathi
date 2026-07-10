import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/owner_trial.dart';
import '../repositories/subscription_repository.dart';

/// Use case for starting a trial for a new owner.
class StartOwnerTrial implements UseCase<OwnerTrial, StartOwnerTrialParams> {
  const StartOwnerTrial({required this.subscriptionRepository});

  final SubscriptionRepository subscriptionRepository;

  @override
  Future<Either<Failure, OwnerTrial>> call(StartOwnerTrialParams params) async {
    return subscriptionRepository.getOrCreateTrial(params.ownerId);
  }
}

/// Parameters for StartOwnerTrial use case.
class StartOwnerTrialParams extends Equatable {
  const StartOwnerTrialParams({required this.ownerId});

  final String ownerId;

  @override
  List<Object?> get props => [ownerId];
}
