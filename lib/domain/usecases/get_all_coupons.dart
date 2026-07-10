import 'package:dartz/dartz.dart';

import '../core/core.dart';
import '../entities/coupon.dart';
import '../repositories/subscription_repository.dart';

/// Use case for getting all coupons (admin).
class GetAllCoupons implements UseCase<List<Coupon>, NoParams> {
  const GetAllCoupons({required this.subscriptionRepository});

  final SubscriptionRepository subscriptionRepository;

  @override
  Future<Either<Failure, List<Coupon>>> call(NoParams params) async {
    return subscriptionRepository.getAllCoupons();
  }
}
