import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/promo_offer.dart';

/// Repository interface for managing promotional offers.
abstract class PromoRepository {
  /// Get the currently active promo offer for an owner.
  /// Returns the highest priority active promo that the owner hasn't
  /// seen according to its display frequency.
  Future<Either<Failure, PromoOffer?>> getActivePromoForOwner({
    required String ownerId,
    required String libraryId,
    required PromoTargetAudience ownerAudience,
  });

  /// Get the currently active promo offer for a student.
  /// Returns the highest priority active promo that the student hasn't
  /// seen according to its display frequency.
  Future<Either<Failure, PromoOffer?>> getActivePromoForStudent({
    required String studentId,
    required PromoTargetAudience studentAudience,
  });

  /// Record an interaction with a promo offer.
  Future<Either<Failure, void>> recordPromoInteraction({
    required String promoOfferId,
    required String ownerId,
    required String libraryId,
    required PromoInteractionAction action,
  });

  /// Get all promo offers (for admin).
  Future<Either<Failure, List<PromoOffer>>> getAllPromos();

  /// Create a new promo offer (for admin).
  Future<Either<Failure, PromoOffer>> createPromo(PromoOffer promo);

  /// Update a promo offer (for admin).
  Future<Either<Failure, PromoOffer>> updatePromo(PromoOffer promo);

  /// Delete a promo offer (for admin).
  Future<Either<Failure, void>> deletePromo(String promoId);

  /// Get promo analytics (click rate, view count, etc.)
  Future<Either<Failure, PromoAnalytics>> getPromoAnalytics(String promoId);
}

/// Analytics data for a promo offer
class PromoAnalytics {
  const PromoAnalytics({
    required this.promoId,
    required this.viewCount,
    required this.clickCount,
    required this.dismissCount,
    required this.uniqueOwners,
  });

  final String promoId;
  final int viewCount;
  final int clickCount;
  final int dismissCount;
  final int uniqueOwners;

  double get clickRate =>
      viewCount > 0 ? (clickCount / viewCount) * 100 : 0.0;
}
