import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/coupon.dart';
import '../repositories/subscription_repository.dart';

/// Use case for creating a coupon (admin only).
class CreateCoupon implements UseCase<Coupon, CreateCouponParams> {
  const CreateCoupon({required this.subscriptionRepository});

  final SubscriptionRepository subscriptionRepository;

  @override
  Future<Either<Failure, Coupon>> call(CreateCouponParams params) async {
    return subscriptionRepository.createCoupon(params.coupon);
  }
}

/// Parameters for CreateCoupon use case.
class CreateCouponParams extends Equatable {
  const CreateCouponParams({required this.coupon});

  final Coupon coupon;

  @override
  List<Object?> get props => [coupon];
}
