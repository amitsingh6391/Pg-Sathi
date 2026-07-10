import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../../domain/core/failure.dart';
import '../../domain/entities/promo_offer.dart';
import '../../domain/repositories/promo_repository.dart';
import '../failures/data_failures.dart';
import '../models/promo_offer_dto.dart';
import '../services/promo_seen_service.dart';

/// Firestore implementation of PromoRepository.
class PromoRepositoryImpl implements PromoRepository {
  const PromoRepositoryImpl({
    required this.firestore,
    required this.promoSeenService,
  });

  final FirebaseFirestore firestore;
  final PromoSeenService promoSeenService;

  CollectionReference<Map<String, dynamic>> get _promosCollection =>
      firestore.collection('promo_offers');

  CollectionReference<Map<String, dynamic>> get _interactionsCollection =>
      firestore.collection('promo_interactions');

  @override
  Future<Either<Failure, PromoOffer?>> getActivePromoForOwner({
    required String ownerId,
    required String libraryId,
    required PromoTargetAudience ownerAudience,
  }) async {
    try {
      // Fetch all active promos
      final querySnapshot = await _promosCollection
          .where('isActive', isEqualTo: true)
          .orderBy('priority', descending: true)
          .get();

      print('[PromoRepo] Found ${querySnapshot.docs.length} active promos');
      print('[PromoRepo] Owner audience: $ownerAudience');

      if (querySnapshot.docs.isEmpty) {
        return const Right(null);
      }

      final now = DateTime.now();
      final promos = querySnapshot.docs
          .map((doc) => PromoOfferModel.fromFirestore(doc).toEntity())
          .where((promo) {
            final valid = _isPromoValidForOwner(promo, ownerAudience, now);
            print('[PromoRepo] Promo "${promo.title}" (${promo.targetAudience}) valid for owner: $valid');
            return valid;
          })
          .toList();

      print('[PromoRepo] ${promos.length} promos valid for this owner');

      // Find first promo that owner hasn't seen according to display frequency
      for (final promo in promos) {
        final shouldShow = await _shouldShowPromo(
          promo: promo,
          ownerId: ownerId,
        );
        print('[PromoRepo] Should show "${promo.title}": $shouldShow (freq: ${promo.displayFrequency})');
        if (shouldShow) {
          return Right(promo);
        }
      }

      return const Right(null);
    } catch (e) {
      print('[PromoRepo] Error: $e');
      return Left(ServerFailure(message: 'Failed to fetch promo: $e'));
    }
  }

  @override
  Future<Either<Failure, PromoOffer?>> getActivePromoForStudent({
    required String studentId,
    required PromoTargetAudience studentAudience,
  }) async {
    try {
      // Fetch all active promos
      final querySnapshot = await _promosCollection
          .where('isActive', isEqualTo: true)
          .orderBy('priority', descending: true)
          .get();

      print('[PromoRepo] Found ${querySnapshot.docs.length} active promos (student)');
      print('[PromoRepo] Student audience: $studentAudience');

      if (querySnapshot.docs.isEmpty) {
        return const Right(null);
      }

      final now = DateTime.now();
      final promos = querySnapshot.docs
          .map((doc) => PromoOfferModel.fromFirestore(doc).toEntity())
          .where((promo) {
            final valid = _isPromoValidForStudent(promo, studentAudience, now);
            print('[PromoRepo] Promo "${promo.title}" (${promo.targetAudience}) valid for student: $valid');
            return valid;
          })
          .toList();

      print('[PromoRepo] ${promos.length} promos valid for this student');

      // Find first promo that student hasn't seen according to display frequency
      for (final promo in promos) {
        final shouldShow = await _shouldShowPromo(
          promo: promo,
          ownerId: studentId, // Reusing ownerId field for student tracking
        );
        print('[PromoRepo] Should show "${promo.title}": $shouldShow (freq: ${promo.displayFrequency})');
        if (shouldShow) {
          return Right(promo);
        }
      }

      return const Right(null);
    } catch (e) {
      print('[PromoRepo] Error (student): $e');
      return Left(ServerFailure(message: 'Failed to fetch promo: $e'));
    }
  }

  bool _isPromoValidForOwner(
    PromoOffer promo,
    PromoTargetAudience ownerAudience,
    DateTime now,
  ) {
    // Check date validity
    if (promo.startDate != null && now.isBefore(promo.startDate!)) {
      return false;
    }
    if (promo.endDate != null && now.isAfter(promo.endDate!)) {
      return false;
    }

    // Check target audience - "all" means everyone, "allOwners" means all owners
    if (promo.targetAudience == PromoTargetAudience.all ||
        promo.targetAudience == PromoTargetAudience.allOwners) {
      return true;
    }
    
    // Student-only audiences should not show to owners
    if (_isStudentOnlyAudience(promo.targetAudience)) {
      return false;
    }
    
    return promo.targetAudience == ownerAudience;
  }

  bool _isPromoValidForStudent(
    PromoOffer promo,
    PromoTargetAudience studentAudience,
    DateTime now,
  ) {
    // Check date validity
    if (promo.startDate != null && now.isBefore(promo.startDate!)) {
      return false;
    }
    if (promo.endDate != null && now.isAfter(promo.endDate!)) {
      return false;
    }

    // Check target audience - "all" means everyone, "allStudents" means all students
    if (promo.targetAudience == PromoTargetAudience.all ||
        promo.targetAudience == PromoTargetAudience.allStudents) {
      return true;
    }
    
    // Owner-only audiences should not show to students
    if (_isOwnerOnlyAudience(promo.targetAudience)) {
      return false;
    }
    
    return promo.targetAudience == studentAudience;
  }

  bool _isStudentOnlyAudience(PromoTargetAudience audience) {
    return audience == PromoTargetAudience.allStudents ||
        audience == PromoTargetAudience.activeMembership ||
        audience == PromoTargetAudience.expiredMembership ||
        audience == PromoTargetAudience.noMembership;
  }

  bool _isOwnerOnlyAudience(PromoTargetAudience audience) {
    return audience == PromoTargetAudience.allOwners ||
        audience == PromoTargetAudience.freeTier ||
        audience == PromoTargetAudience.paid ||
        audience == PromoTargetAudience.expired ||
        audience == PromoTargetAudience.pendingVerification ||
        audience == PromoTargetAudience.newOwners;
  }

  Future<bool> _shouldShowPromo({
    required PromoOffer promo,
    required String ownerId,
  }) async {
    switch (promo.displayFrequency) {
      case PromoDisplayFrequency.once:
        return !promoSeenService.hasSeenPromoEver(
          promoId: promo.id,
          ownerId: ownerId,
        );
      case PromoDisplayFrequency.daily:
        return !promoSeenService.hasSeenPromoToday(
          promoId: promo.id,
          ownerId: ownerId,
        );
      case PromoDisplayFrequency.session:
        return !promoSeenService.hasSeenPromoThisSession(
          promoId: promo.id,
          ownerId: ownerId,
        );
    }
  }

  @override
  Future<Either<Failure, void>> recordPromoInteraction({
    required String promoOfferId,
    required String ownerId,
    required String libraryId,
    required PromoInteractionAction action,
  }) async {
    try {
      final interactionId = const Uuid().v4();
      final now = DateTime.now();

      final interaction = PromoInteractionModel(
        id: interactionId,
        promoOfferId: promoOfferId,
        ownerId: ownerId,
        libraryId: libraryId,
        action: action.name,
        timestamp: now,
      );

      await _interactionsCollection.doc(interactionId).set(
            interaction.toFirestore(),
          );

      // Mark as seen locally
      await promoSeenService.markPromoAsSeen(
        promoId: promoOfferId,
        ownerId: ownerId,
      );

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to record interaction: $e'));
    }
  }

  @override
  Future<Either<Failure, List<PromoOffer>>> getAllPromos() async {
    try {
      final querySnapshot = await _promosCollection
          .orderBy('createdAt', descending: true)
          .get();

      final promos = querySnapshot.docs
          .map((doc) => PromoOfferModel.fromFirestore(doc).toEntity())
          .toList();

      return Right(promos);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to fetch promos: $e'));
    }
  }

  @override
  Future<Either<Failure, PromoOffer>> createPromo(PromoOffer promo) async {
    try {
      final promoId = const Uuid().v4();
      final promoWithId = PromoOffer(
        id: promoId,
        title: promo.title,
        imageUrl: promo.imageUrl,
        ctaText: promo.ctaText,
        ctaAction: promo.ctaAction,
        ctaValue: promo.ctaValue,
        description: promo.description,
        targetAudience: promo.targetAudience,
        displayFrequency: promo.displayFrequency,
        startDate: promo.startDate,
        endDate: promo.endDate,
        priority: promo.priority,
        isActive: promo.isActive,
        createdAt: DateTime.now(),
      );

      final model = PromoOfferModel.fromEntity(promoWithId);
      await _promosCollection.doc(promoId).set(model.toFirestore());

      return Right(promoWithId);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to create promo: $e'));
    }
  }

  @override
  Future<Either<Failure, PromoOffer>> updatePromo(PromoOffer promo) async {
    try {
      final model = PromoOfferModel.fromEntity(promo);
      await _promosCollection.doc(promo.id).update(model.toFirestore());
      return Right(promo);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to update promo: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deletePromo(String promoId) async {
    try {
      await _promosCollection.doc(promoId).delete();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to delete promo: $e'));
    }
  }

  @override
  Future<Either<Failure, PromoAnalytics>> getPromoAnalytics(
    String promoId,
  ) async {
    try {
      final querySnapshot = await _interactionsCollection
          .where('promoOfferId', isEqualTo: promoId)
          .get();

      int viewCount = 0;
      int clickCount = 0;
      int dismissCount = 0;
      final uniqueOwners = <String>{};

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final action = data['action'] as String?;
        final ownerId = data['ownerId'] as String?;

        if (ownerId != null) uniqueOwners.add(ownerId);

        switch (action) {
          case 'viewed':
            viewCount++;
            break;
          case 'clicked':
            clickCount++;
            break;
          case 'dismissed':
            dismissCount++;
            break;
        }
      }

      return Right(PromoAnalytics(
        promoId: promoId,
        viewCount: viewCount,
        clickCount: clickCount,
        dismissCount: dismissCount,
        uniqueOwners: uniqueOwners.length,
      ));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to fetch analytics: $e'));
    }
  }
}
