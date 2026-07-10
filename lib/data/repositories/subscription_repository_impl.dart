import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../domain/core/failure.dart';
import '../../domain/entities/coupon.dart';
import '../../domain/entities/owner_trial.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../mappers/subscription_mapper.dart';
import '../models/subscription_dto.dart';

/// Generic data layer failure for subscription operations.
class _SubscriptionDataFailure extends Failure {
  const _SubscriptionDataFailure({super.message});
}

/// Firestore implementation of SubscriptionRepository.
class SubscriptionRepositoryImpl implements SubscriptionRepository {
  const SubscriptionRepositoryImpl({required this.firestore});

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> get _subscriptionsRef =>
      firestore.collection('subscriptions');

  CollectionReference<Map<String, dynamic>> get _trialsRef =>
      firestore.collection('owner_trials');

  CollectionReference<Map<String, dynamic>> get _couponsRef =>
      firestore.collection('coupons');

  @override
  Future<Either<Failure, Subscription>> createSubscription(
    Subscription subscription,
  ) async {
    try {
      final dto = SubscriptionMapper.toDto(subscription);
      await _subscriptionsRef.doc(subscription.id).set(dto.toFirestore());
      return Right(subscription);
    } catch (e) {
      return Left(
        _SubscriptionDataFailure(message: 'Failed to create subscription: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, Subscription>> updateSubscription(
    Subscription subscription,
  ) async {
    try {
      final dto = SubscriptionMapper.toDto(subscription);
      await _subscriptionsRef.doc(subscription.id).update(dto.toFirestore());
      return Right(subscription);
    } catch (e) {
      return Left(
        _SubscriptionDataFailure(message: 'Failed to update subscription: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, Subscription?>> getActiveSubscription(
    String ownerId,
  ) async {
    try {
      // Query for active subscription - simplified to avoid composite index
      final querySnapshot = await _subscriptionsRef
          .where('ownerId', isEqualTo: ownerId)
          .where('status', isEqualTo: 'active')
          .get();

      if (querySnapshot.docs.isEmpty) {
        return const Right(null);
      }

      // Convert to domain objects
      final allSubscriptions = querySnapshot.docs
          .map(
            (doc) =>
                SubscriptionMapper.toDomain(SubscriptionDto.fromFirestore(doc)),
          )
          .toList();

      // Filter to only those that are ACTUALLY active right now (started and not ended)
      final now = DateTime.now();
      final actuallyActiveSubscriptions = allSubscriptions.where((sub) {
        final hasStarted = !now.isBefore(sub.startDate);
        final hasNotEnded = !now.isAfter(sub.endDate);
        return hasStarted && hasNotEnded;
      }).toList();

      if (actuallyActiveSubscriptions.isEmpty) {
        return const Right(null);
      }

      // Sort by end date descending to get the one that ends latest
      actuallyActiveSubscriptions.sort(
        (a, b) => b.endDate.compareTo(a.endDate),
      );

      return Right(actuallyActiveSubscriptions.first);
    } catch (e) {
      return Left(
        _SubscriptionDataFailure(message: 'Failed to get subscription: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, Subscription>> getSubscriptionById(String id) async {
    try {
      final doc = await _subscriptionsRef.doc(id).get();
      if (!doc.exists) {
        return const Left(
          _SubscriptionDataFailure(message: 'Subscription not found'),
        );
      }

      final dto = SubscriptionDto.fromFirestore(doc);
      return Right(SubscriptionMapper.toDomain(dto));
    } catch (e) {
      return Left(
        _SubscriptionDataFailure(message: 'Failed to get subscription: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, List<Subscription>>> getSubscriptionHistory(
    String ownerId,
  ) async {
    try {
      // Query only by ownerId to avoid composite index requirement
      final querySnapshot = await _subscriptionsRef
          .where('ownerId', isEqualTo: ownerId)
          .get();

      final subscriptions = querySnapshot.docs
          .map(
            (doc) =>
                SubscriptionMapper.toDomain(SubscriptionDto.fromFirestore(doc)),
          )
          .toList();

      // Sort in memory by createdAt descending
      subscriptions.sort((a, b) {
        final aDate = a.createdAt ?? DateTime(2020);
        final bDate = b.createdAt ?? DateTime(2020);
        return bDate.compareTo(aDate);
      });

      return Right(subscriptions);
    } catch (e) {
      return Left(
        _SubscriptionDataFailure(
          message: 'Failed to get subscription history: $e',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<Subscription>>>
  getPendingVerificationSubscriptions() async {
    try {
      // Query only by status to avoid composite index requirement
      final querySnapshot = await _subscriptionsRef
          .where('status', isEqualTo: 'pendingVerification')
          .get();

      final subscriptions = querySnapshot.docs
          .map(
            (doc) =>
                SubscriptionMapper.toDomain(SubscriptionDto.fromFirestore(doc)),
          )
          .toList();

      // Sort in memory by markedPaidAt (oldest first)
      subscriptions.sort((a, b) {
        final aDate = a.markedPaidAt ?? a.createdAt ?? DateTime.now();
        final bDate = b.markedPaidAt ?? b.createdAt ?? DateTime.now();
        return aDate.compareTo(bDate);
      });

      return Right(subscriptions);
    } catch (e) {
      return Left(
        _SubscriptionDataFailure(
          message: 'Failed to get pending subscriptions: $e',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, Subscription?>> getLatestPendingSubscription(
    String ownerId,
  ) async {
    try {
      final querySnapshot = await _subscriptionsRef
          .where('ownerId', isEqualTo: ownerId)
          .where('status', isEqualTo: 'pendingVerification')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return const Right(null);
      }

      final dto = SubscriptionDto.fromFirestore(querySnapshot.docs.first);
      return Right(SubscriptionMapper.toDomain(dto));
    } catch (e) {
      return Left(
        _SubscriptionDataFailure(
          message: 'Failed to get pending subscription: $e',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<Subscription>>> getAllSubscriptions() async {
    try {
      final querySnapshot = await _subscriptionsRef
          .orderBy('createdAt', descending: true)
          .get();

      final subscriptions = querySnapshot.docs
          .map(
            (doc) =>
                SubscriptionMapper.toDomain(SubscriptionDto.fromFirestore(doc)),
          )
          .toList();

      return Right(subscriptions);
    } catch (e) {
      return Left(
        _SubscriptionDataFailure(message: 'Failed to get subscriptions: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> deleteSubscription(
    String subscriptionId,
  ) async {
    try {
      await _subscriptionsRef.doc(subscriptionId).delete();
      return const Right(null);
    } catch (e) {
      return Left(
        _SubscriptionDataFailure(message: 'Failed to delete subscription: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, OwnerTrial>> getOrCreateTrial(String ownerId) async {
    try {
      final doc = await _trialsRef.doc(ownerId).get();

      if (doc.exists) {
        final dto = OwnerTrialDto.fromFirestore(doc);
        return Right(OwnerTrialMapper.toDomain(dto));
      }

      // Create new trial
      final trial = OwnerTrial.create(ownerId: ownerId);
      final dto = OwnerTrialMapper.toDto(trial);
      await _trialsRef.doc(ownerId).set(dto.toFirestore());

      return Right(trial);
    } catch (e) {
      return Left(
        _SubscriptionDataFailure(message: 'Failed to get/create trial: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, OwnerTrial?>> getTrial(String ownerId) async {
    try {
      final doc = await _trialsRef.doc(ownerId).get();

      if (!doc.exists) {
        return const Right(null);
      }

      final dto = OwnerTrialDto.fromFirestore(doc);
      return Right(OwnerTrialMapper.toDomain(dto));
    } catch (e) {
      return Left(_SubscriptionDataFailure(message: 'Failed to get trial: $e'));
    }
  }

  @override
  Future<Either<Failure, OwnerTrial>> updateTrial(OwnerTrial trial) async {
    try {
      final dto = OwnerTrialMapper.toDto(trial);
      await _trialsRef.doc(trial.ownerId).update(dto.toFirestore());
      return Right(trial);
    } catch (e) {
      return Left(
        _SubscriptionDataFailure(message: 'Failed to update trial: $e'),
      );
    }
  }

  // =========================================================================
  // Coupon Methods
  // =========================================================================

  @override
  Future<Either<Failure, Coupon?>> getCouponByCode(String code) async {
    try {
      final doc = await _couponsRef.doc(code.toUpperCase()).get();

      if (!doc.exists) {
        return const Right(null);
      }

      return Right(_couponFromFirestore(doc));
    } catch (e) {
      return Left(
        _SubscriptionDataFailure(message: 'Failed to get coupon: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, Coupon>> createCoupon(Coupon coupon) async {
    try {
      await _couponsRef
          .doc(coupon.code.toUpperCase())
          .set(_couponToFirestore(coupon));
      return Right(coupon);
    } catch (e) {
      return Left(
        _SubscriptionDataFailure(message: 'Failed to create coupon: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, Coupon>> updateCoupon(Coupon coupon) async {
    try {
      await _couponsRef
          .doc(coupon.code.toUpperCase())
          .update(_couponToFirestore(coupon));
      return Right(coupon);
    } catch (e) {
      return Left(
        _SubscriptionDataFailure(message: 'Failed to update coupon: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, List<Coupon>>> getAllCoupons() async {
    try {
      final querySnapshot = await _couponsRef.get();

      final coupons = querySnapshot.docs
          .map((doc) => _couponFromFirestore(doc))
          .toList();

      return Right(coupons);
    } catch (e) {
      return Left(
        _SubscriptionDataFailure(message: 'Failed to get coupons: $e'),
      );
    }
  }

  Coupon _couponFromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Coupon(
      code: doc.id,
      discountPercent: (data['discountPercent'] as num).toDouble(),
      isActive: data['isActive'] as bool? ?? true,
      description: data['description'] as String?,
      maxUses: data['maxUses'] as int?,
      currentUses: data['currentUses'] as int? ?? 0,
      validFrom: data['validFrom'] != null
          ? (data['validFrom'] as Timestamp).toDate()
          : null,
      validUntil: data['validUntil'] != null
          ? (data['validUntil'] as Timestamp).toDate()
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> _couponToFirestore(Coupon coupon) {
    return {
      'discountPercent': coupon.discountPercent,
      'isActive': coupon.isActive,
      'description': coupon.description,
      'maxUses': coupon.maxUses,
      'currentUses': coupon.currentUses,
      'validFrom': coupon.validFrom != null
          ? Timestamp.fromDate(coupon.validFrom!)
          : null,
      'validUntil': coupon.validUntil != null
          ? Timestamp.fromDate(coupon.validUntil!)
          : null,
      'createdAt': coupon.createdAt != null
          ? Timestamp.fromDate(coupon.createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}
