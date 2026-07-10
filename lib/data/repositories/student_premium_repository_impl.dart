import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../../domain/core/failure.dart';
import '../../domain/entities/student_premium_subscription.dart';
import '../../domain/repositories/student_premium_repository.dart';
import '../failures/data_failures.dart';
import '../models/student_premium_subscription_dto.dart';

class StudentPremiumRepositoryImpl implements StudentPremiumRepository {
  StudentPremiumRepositoryImpl({
    required FirebaseFirestore firestore,
    Uuid? uuid,
  })  : _firestore = firestore,
        _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('studentPremiumSubscriptions');

  @override
  Future<Either<Failure, StudentPremiumSubscription?>> getActiveSubscription(
    String userId,
  ) async {
    try {
      final snap = await _col
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .orderBy('validTill', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return const Right(null);

      final entity = StudentPremiumSubscriptionModel.fromFirestore(
        snap.docs.first,
      ).toEntity();

      // Defensive: if server-side isActive is true but the window has
      // already closed, treat as inactive without a write (the expire
      // job will clean this up).
      if (!entity.isCurrentlyActive) return const Right(null);
      return Right(entity);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to load subscription: $e'));
    }
  }

  @override
  Future<Either<Failure, StudentPremiumSubscription>> activateSubscription({
    required String userId,
    required StudentPremiumPlan plan,
    required int amountPaise,
    required String paymentId,
    required String paymentProvider,
  }) async {
    try {
      // Idempotency: reuse the same doc id for the same payment so retries
      // don't create duplicate rows.
      final docRef = _col.doc(paymentId.isNotEmpty ? paymentId : _uuid.v4());
      final existing = await docRef.get();
      if (existing.exists) {
        final entity = StudentPremiumSubscriptionModel.fromFirestore(
          existing,
        ).toEntity();
        return Right(entity);
      }

      final now = DateTime.now();

      // If the user already has an active subscription, extend from its
      // existing [validTill] to avoid granting overlapping time.
      final activeResult = await getActiveSubscription(userId);
      final baseFrom = activeResult.fold(
        (_) => now,
        (sub) => (sub != null && sub.validTill.isAfter(now))
            ? sub.validTill
            : now,
      );

      final validTill = baseFrom.add(Duration(days: plan.durationDays));

      final subscription = StudentPremiumSubscription(
        id: docRef.id,
        userId: userId,
        plan: plan,
        amountPaise: amountPaise,
        startedAt: now,
        validTill: validTill,
        isActive: true,
        createdAt: now,
        paymentId: paymentId,
        paymentProvider: paymentProvider,
      );

      await docRef.set(
        StudentPremiumSubscriptionModel.fromEntity(subscription).toFirestore(),
      );
      return Right(subscription);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to activate: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> cancelSubscription(
    String subscriptionId,
  ) async {
    try {
      await _col.doc(subscriptionId).update({
        'isActive': false,
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to cancel: $e'));
    }
  }

  @override
  Future<Either<Failure, List<StudentPremiumSubscription>>>
      getAllSubscriptions() async {
    try {
      final snap =
          await _col.orderBy('createdAt', descending: true).limit(500).get();
      final items = snap.docs
          .map((d) => StudentPremiumSubscriptionModel.fromFirestore(d).toEntity())
          .toList(growable: false);
      return Right(items);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to load list: $e'));
    }
  }
}
