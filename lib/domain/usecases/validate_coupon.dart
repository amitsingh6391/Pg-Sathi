import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/coupon.dart';
import '../failures/subscription_failures.dart';
import '../repositories/subscription_repository.dart';

/// Use case for validating a coupon code.
class ValidateCoupon implements UseCase<Coupon, ValidateCouponParams> {
  const ValidateCoupon({required this.subscriptionRepository});

  final SubscriptionRepository subscriptionRepository;

  @override
  Future<Either<Failure, Coupon>> call(ValidateCouponParams params) async {
    if (params.couponCode.trim().isEmpty) {
      return const Left(
        SubscriptionFailure(message: 'Coupon code is required'),
      );
    }

    final couponResult = await subscriptionRepository.getCouponByCode(
      params.couponCode.trim().toUpperCase(),
    );

    return couponResult.fold((failure) => Left(failure), (coupon) {
      if (coupon == null) {
        return const Left(SubscriptionFailure(message: 'Invalid coupon code'));
      }

      if (!coupon.isValid(DateTime.now())) {
        if (!coupon.isActive) {
          return const Left(
            SubscriptionFailure(message: 'This coupon is no longer active'),
          );
        }
        if (coupon.maxUses != null && coupon.currentUses >= coupon.maxUses!) {
          return const Left(
            SubscriptionFailure(
              message: 'This coupon has reached its usage limit',
            ),
          );
        }
        return const Left(
          SubscriptionFailure(message: 'This coupon has expired'),
        );
      }

      return Right(coupon);
    });
  }
}

/// Parameters for ValidateCoupon use case.
class ValidateCouponParams extends Equatable {
  const ValidateCouponParams({required this.couponCode});

  final String couponCode;

  @override
  List<Object?> get props => [couponCode];
}
