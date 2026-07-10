import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../core/failure.dart';
import '../../entities/current_affair.dart';
import '../../repositories/current_affairs_repository.dart';

// =============================================================================
// Get Current Affairs
// =============================================================================

/// Fetches a paginated list of current affairs with optional category filter.
class GetCurrentAffairs {
  const GetCurrentAffairs({required this.repository});

  final CurrentAffairsRepository repository;

  Future<Either<Failure, PaginatedCurrentAffairs>> call({
    CurrentAffairsCategory? category,
    int limit = 10,
    String? startAfterId,
  }) {
    return repository.getAll(
      category: category,
      limit: limit,
      startAfterId: startAfterId,
    );
  }
}

// =============================================================================
// Get Current Affair By ID
// =============================================================================

/// Fetches a single current affair by its ID.
class GetCurrentAffairById {
  const GetCurrentAffairById({required this.repository});

  final CurrentAffairsRepository repository;

  Future<Either<Failure, CurrentAffair>> call(String id) {
    return repository.getById(id);
  }
}

// =============================================================================
// Create Current Affair
// =============================================================================

/// Creates a new current affair and sends push notification to all students.
class CreateCurrentAffair {
  const CreateCurrentAffair({required this.repository});

  final CurrentAffairsRepository repository;

  Future<Either<Failure, CurrentAffair>> call({
    required String title,
    required String summary,
    required String content,
    required CurrentAffairsCategory category,
    String? source,
    String? imageUrl,
    required String createdBy,
    bool sendNotification = true,
  }) {
    return repository.create(
      title: title,
      summary: summary,
      content: content,
      category: category,
      source: source,
      imageUrl: imageUrl,
      createdBy: createdBy,
      sendNotification: sendNotification,
    );
  }
}

// =============================================================================
// Toggle Bookmark
// =============================================================================

/// Toggles the bookmark status of a current affair for a student.
class ToggleCurrentAffairBookmark {
  const ToggleCurrentAffairBookmark({required this.repository});

  final CurrentAffairsRepository repository;

  Future<Either<Failure, void>> call({
    required String currentAffairId,
    required String userId,
    required bool isBookmarked,
  }) {
    return repository.toggleBookmark(
      currentAffairId: currentAffairId,
      userId: userId,
      isBookmarked: isBookmarked,
    );
  }
}

// =============================================================================
// Delete Current Affair
// =============================================================================

/// Deletes a current affair by ID. Admin only.
class DeleteCurrentAffair {
  const DeleteCurrentAffair({required this.repository});

  final CurrentAffairsRepository repository;

  Future<Either<Failure, void>> call(String id) {
    return repository.delete(id);
  }
}

// =============================================================================
// Record Article View
// =============================================================================

/// Records a unique view when a student opens an article.
/// Deduplication is handled server-side (one view per user per article).
class RecordArticleView {
  const RecordArticleView({required this.repository});

  final CurrentAffairsRepository repository;

  Future<Either<Failure, void>> call({
    required String currentAffairId,
    required String userId,
  }) {
    return repository.recordView(
      currentAffairId: currentAffairId,
      userId: userId,
    );
  }
}

// =============================================================================
// Toggle Article Like
// =============================================================================

/// Toggles like status for a student on an article.
class ToggleArticleLike {
  const ToggleArticleLike({required this.repository});

  final CurrentAffairsRepository repository;

  Future<Either<Failure, bool>> call({
    required String currentAffairId,
    required String userId,
    required bool isLiked,
  }) {
    return repository.toggleLike(
      currentAffairId: currentAffairId,
      userId: userId,
      isLiked: isLiked,
    );
  }
}

// =============================================================================
// Affiliate Coupon Copy Tracking
// =============================================================================

/// Records when a student copies the affiliate coupon code.
/// Deduplicates per user; maintains a global counter for admin analytics.
class RecordAffiliateCouponCopy {
  const RecordAffiliateCouponCopy({required this.firestore});

  final FirebaseFirestore firestore;

  /// Records a coupon copy event. Deduplicates per user+coupon pair.
  Future<void> call({
    required String userId,
    String couponCode = '',
  }) async {
    try {
      final docId = couponCode.isEmpty ? userId : '${userId}_$couponCode';
      final ref =
          firestore.collection('affiliate_coupon_copies').doc(docId);

      final existing = await ref.get();
      if (existing.exists) return;

      final batch = firestore.batch();
      batch.set(ref, {
        'copiedAt': FieldValue.serverTimestamp(),
        'userId': userId,
        'couponCode': couponCode,
      });
      batch.set(
        firestore.collection('affiliate_stats').doc('coupon_copies'),
        {'totalCopies': FieldValue.increment(1)},
        SetOptions(merge: true),
      );
      await batch.commit();
    } catch (_) {
      // Fire-and-forget — don't disrupt the student experience
    }
  }
}

/// Admin: fetches affiliate coupon copy stats.
class GetAffiliateCouponStats {
  const GetAffiliateCouponStats({required this.firestore});

  final FirebaseFirestore firestore;

  Future<AffiliateCouponStats> call() async {
    try {
      final results = await Future.wait([
        firestore.collection('affiliate_stats').doc('coupon_copies').get(),
        firestore
            .collection('affiliate_coupon_copies')
            .orderBy('copiedAt', descending: true)
            .limit(50)
            .get(),
      ]);

      final statsDoc = results[0] as DocumentSnapshot;
      final copiesSnap = results[1] as QuerySnapshot;

      final totalCopies =
          (statsDoc.data() as Map<String, dynamic>?)?['totalCopies'] as int? ??
              0;

      final recentCopies = copiesSnap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return CouponCopyRecord(
          userId: (data['userId'] as String?) ?? doc.id,
          copiedAt: (data['copiedAt'] as Timestamp?)?.toDate(),
          couponCode: (data['couponCode'] as String?) ?? '',
        );
      }).toList();

      return AffiliateCouponStats(
        totalCopies: totalCopies,
        recentCopies: recentCopies,
      );
    } catch (_) {
      return const AffiliateCouponStats(totalCopies: 0, recentCopies: []);
    }
  }
}

class AffiliateCouponStats {
  const AffiliateCouponStats({
    required this.totalCopies,
    required this.recentCopies,
  });

  final int totalCopies;
  final List<CouponCopyRecord> recentCopies;
}

class CouponCopyRecord {
  const CouponCopyRecord({
    required this.userId,
    this.copiedAt,
    this.couponCode = '',
  });

  final String userId;
  final DateTime? copiedAt;
  final String couponCode;
}

// =============================================================================
// Current Affairs Failure
// =============================================================================

/// Failure type for current affairs operations.
class CurrentAffairsFailure extends Failure {
  const CurrentAffairsFailure({super.message});
}
