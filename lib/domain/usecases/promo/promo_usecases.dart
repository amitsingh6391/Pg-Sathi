import 'package:dartz/dartz.dart';

import '../../core/failure.dart';
import '../../entities/promo_offer.dart';
import '../../repositories/promo_repository.dart';

/// Use case for getting the active promo offer for an owner.
class GetActivePromo {
  const GetActivePromo(this.repository);

  final PromoRepository repository;

  Future<Either<Failure, PromoOffer?>> call({
    required String ownerId,
    required String libraryId,
    required PromoTargetAudience ownerAudience,
  }) {
    return repository.getActivePromoForOwner(
      ownerId: ownerId,
      libraryId: libraryId,
      ownerAudience: ownerAudience,
    );
  }
}

/// Use case for getting the active promo offer for a student.
class GetActivePromoForStudent {
  const GetActivePromoForStudent(this.repository);

  final PromoRepository repository;

  Future<Either<Failure, PromoOffer?>> call({
    required String studentId,
    required PromoTargetAudience studentAudience,
  }) {
    return repository.getActivePromoForStudent(
      studentId: studentId,
      studentAudience: studentAudience,
    );
  }
}

/// Use case for recording an interaction with a promo offer.
class RecordPromoInteraction {
  const RecordPromoInteraction(this.repository);

  final PromoRepository repository;

  Future<Either<Failure, void>> call({
    required String promoOfferId,
    required String ownerId,
    required String libraryId,
    required PromoInteractionAction action,
  }) {
    return repository.recordPromoInteraction(
      promoOfferId: promoOfferId,
      ownerId: ownerId,
      libraryId: libraryId,
      action: action,
    );
  }
}

/// Use case for getting all promo offers (admin only).
class GetAllPromos {
  const GetAllPromos(this.repository);

  final PromoRepository repository;

  Future<Either<Failure, List<PromoOffer>>> call() {
    return repository.getAllPromos();
  }
}

/// Use case for creating a promo offer (admin only).
class CreatePromo {
  const CreatePromo(this.repository);

  final PromoRepository repository;

  Future<Either<Failure, PromoOffer>> call(PromoOffer promo) {
    return repository.createPromo(promo);
  }
}

/// Use case for updating a promo offer (admin only).
class UpdatePromo {
  const UpdatePromo(this.repository);

  final PromoRepository repository;

  Future<Either<Failure, PromoOffer>> call(PromoOffer promo) {
    return repository.updatePromo(promo);
  }
}

/// Use case for deleting a promo offer (admin only).
class DeletePromo {
  const DeletePromo(this.repository);

  final PromoRepository repository;

  Future<Either<Failure, void>> call(String promoId) {
    return repository.deletePromo(promoId);
  }
}

/// Use case for getting promo analytics (admin only).
class GetPromoAnalytics {
  const GetPromoAnalytics(this.repository);

  final PromoRepository repository;

  Future<Either<Failure, PromoAnalytics>> call(String promoId) {
    return repository.getPromoAnalytics(promoId);
  }
}
