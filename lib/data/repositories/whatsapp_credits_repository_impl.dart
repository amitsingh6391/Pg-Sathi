import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../domain/core/failure.dart';
import '../../domain/entities/whatsapp_credits.dart';
import '../../domain/repositories/whatsapp_credits_repository.dart';
import '../failures/data_failures.dart';

/// Firestore-backed WhatsApp credit wallet.
///
/// Wallet doc: `whatsapp_credits/{ownerId}` with shape
///   { totalCredits, usedCredits, updatedAt }
/// matching the Cloud Functions that deduct credits on send. Purchases are also
/// appended to `whatsapp_credit_purchases` for an audit trail.
class WhatsAppCreditsRepositoryImpl implements WhatsAppCreditsRepository {
  const WhatsAppCreditsRepositoryImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _credits =>
      _firestore.collection('whatsapp_credits');

  CollectionReference<Map<String, dynamic>> get _purchases =>
      _firestore.collection('whatsapp_credit_purchases');

  @override
  Future<Either<Failure, WhatsAppCredits>> getCredits(String ownerId) async {
    try {
      final snap = await _credits.doc(ownerId).get();
      if (!snap.exists) {
        // Never seeded → owner still has their free grant available.
        return Right(WhatsAppCredits.initial(ownerId));
      }
      return Right(_fromDoc(ownerId, snap.data()!));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to load WhatsApp credits: $e'));
    }
  }

  @override
  Future<Either<Failure, WhatsAppCredits>> addCredits({
    required String ownerId,
    required int credits,
    required String packId,
    required double amountPaid,
    String? paymentId,
  }) async {
    try {
      final ref = _credits.doc(ownerId);
      final updated = await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        // Seed the free grant on first purchase so the owner keeps it.
        final currentTotal = snap.exists
            ? ((snap.data()?['totalCredits'] as num?)?.toInt() ??
                WhatsAppCredits.freeCredits)
            : WhatsAppCredits.freeCredits;
        final currentUsed = snap.exists
            ? ((snap.data()?['usedCredits'] as num?)?.toInt() ?? 0)
            : 0;
        final newTotal = currentTotal + credits;

        tx.set(
          ref,
          {
            'totalCredits': newTotal,
            'usedCredits': currentUsed,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        return WhatsAppCredits(
          ownerId: ownerId,
          totalCredits: newTotal,
          usedCredits: currentUsed,
        );
      });

      // Audit trail (best-effort — never fails the purchase).
      try {
        await _purchases.add({
          'ownerId': ownerId,
          'packId': packId,
          'credits': credits,
          'amountPaid': amountPaid,
          'paymentId': paymentId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {/* non-critical */}

      return Right(updated);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to add WhatsApp credits: $e'));
    }
  }

  @override
  Future<Either<Failure, WhatsAppCredits>> grantBonusCredits({
    required String ownerId,
    required int credits,
    required String packId,
    required String grantId,
  }) async {
    try {
      final ref = _credits.doc(ownerId);
      // Deterministic id so the same grant can never be applied twice.
      final grantRef = _purchases.doc(grantId);
      final updated = await _firestore.runTransaction((tx) async {
        final grantSnap = await tx.get(grantRef);
        final snap = await tx.get(ref);
        final currentTotal = snap.exists
            ? ((snap.data()?['totalCredits'] as num?)?.toInt() ??
                WhatsAppCredits.freeCredits)
            : WhatsAppCredits.freeCredits;
        final currentUsed = snap.exists
            ? ((snap.data()?['usedCredits'] as num?)?.toInt() ?? 0)
            : 0;

        if (grantSnap.exists) {
          return WhatsAppCredits(
            ownerId: ownerId,
            totalCredits: currentTotal,
            usedCredits: currentUsed,
          );
        }

        final newTotal = currentTotal + credits;
        tx.set(
          ref,
          {
            'totalCredits': newTotal,
            'usedCredits': currentUsed,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        tx.set(grantRef, {
          'ownerId': ownerId,
          'packId': packId,
          'credits': credits,
          'amountPaid': 0,
          'paymentId': null,
          'type': 'subscription_bonus',
          'createdAt': FieldValue.serverTimestamp(),
        });

        return WhatsAppCredits(
          ownerId: ownerId,
          totalCredits: newTotal,
          usedCredits: currentUsed,
        );
      });
      return Right(updated);
    } catch (e) {
      return Left(
        ServerFailure(message: 'Failed to grant WhatsApp credits: $e'),
      );
    }
  }

  WhatsAppCredits _fromDoc(String ownerId, Map<String, dynamic> data) {
    return WhatsAppCredits(
      ownerId: ownerId,
      totalCredits: (data['totalCredits'] as num?)?.toInt() ??
          WhatsAppCredits.freeCredits,
      usedCredits: (data['usedCredits'] as num?)?.toInt() ?? 0,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
