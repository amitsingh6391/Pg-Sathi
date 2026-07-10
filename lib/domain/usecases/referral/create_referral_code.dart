import 'dart:math';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../core/core.dart';
import '../../entities/referral.dart';
import '../../failures/referral_failures.dart';
import '../../repositories/referral_repository.dart';
import '../../repositories/subscription_repository.dart';

/// Creates a unique referral code for an owner with an active subscription.
class CreateReferralCode
    implements UseCase<Referral, CreateReferralCodeParams> {
  const CreateReferralCode({
    required this.referralRepository,
    required this.subscriptionRepository,
  });

  final ReferralRepository referralRepository;
  final SubscriptionRepository subscriptionRepository;

  @override
  Future<Either<Failure, Referral>> call(
    CreateReferralCodeParams params,
  ) async {
    // Guard: owner must have an active subscription
    final subResult = await subscriptionRepository.getActiveSubscription(
      params.ownerId,
    );

    final hasActive = subResult.fold(
      (_) => false,
      (sub) => sub != null && sub.isActive(DateTime.now()),
    );

    if (!hasActive) {
      return const Left(NoActiveSubscriptionForReferralFailure());
    }

    // Guard: owner must not already have a referral code
    final existing = await referralRepository.getReferralByOwnerId(
      params.ownerId,
    );

    final alreadyExists = existing.fold((_) => false, (r) => r != null);
    if (alreadyExists) {
      return existing.fold(
        (f) => Left(f),
        (r) => Right(r!),
      );
    }

    final code = _generateCode(params.ownerName);
    final now = DateTime.now();

    final referral = Referral(
      id: '${params.ownerId}_referral',
      ownerId: params.ownerId,
      code: code,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    return referralRepository.createReferral(referral);
  }

  /// Generates a human-friendly code like "LT-AMIT-7X3K".
  String _generateCode(String? ownerName) {
    final rng = Random.secure();
    final chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final suffix = List.generate(4, (_) => chars[rng.nextInt(chars.length)])
        .join();

    final namePrefix = (ownerName ?? 'REF')
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z]'), '')
        .padRight(3, 'X')
        .substring(0, 3);

    return 'LT-$namePrefix-$suffix';
  }
}

class CreateReferralCodeParams extends Equatable {
  const CreateReferralCodeParams({
    required this.ownerId,
    this.ownerName,
  });

  final String ownerId;
  final String? ownerName;

  @override
  List<Object?> get props => [ownerId, ownerName];
}
