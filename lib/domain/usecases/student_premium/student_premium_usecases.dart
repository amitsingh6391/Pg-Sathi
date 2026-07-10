import 'package:dartz/dartz.dart';

import '../../core/failure.dart';
import '../../entities/student_premium_subscription.dart';
import '../../repositories/student_premium_repository.dart';

class GetActiveStudentPremium {
  const GetActiveStudentPremium(this.repository);
  final StudentPremiumRepository repository;

  Future<Either<Failure, StudentPremiumSubscription?>> call(String userId) {
    return repository.getActiveSubscription(userId);
  }
}

class ActivateStudentPremium {
  const ActivateStudentPremium(this.repository);
  final StudentPremiumRepository repository;

  Future<Either<Failure, StudentPremiumSubscription>> call({
    required String userId,
    required StudentPremiumPlan plan,
    required int amountPaise,
    required String paymentId,
    required String paymentProvider,
  }) {
    return repository.activateSubscription(
      userId: userId,
      plan: plan,
      amountPaise: amountPaise,
      paymentId: paymentId,
      paymentProvider: paymentProvider,
    );
  }
}

class CancelStudentPremium {
  const CancelStudentPremium(this.repository);
  final StudentPremiumRepository repository;

  Future<Either<Failure, void>> call(String subscriptionId) {
    return repository.cancelSubscription(subscriptionId);
  }
}

class GetAllStudentPremiumSubscriptions {
  const GetAllStudentPremiumSubscriptions(this.repository);
  final StudentPremiumRepository repository;

  Future<Either<Failure, List<StudentPremiumSubscription>>> call() {
    return repository.getAllSubscriptions();
  }
}
