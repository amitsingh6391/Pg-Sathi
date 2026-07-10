import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../domain/core/failure.dart';
import '../../domain/entities/current_affair.dart';
import '../../domain/repositories/current_affairs_repository.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../domain/usecases/current_affairs/current_affairs_usecases.dart';

/// Firestore-backed implementation of [CurrentAffairsRepository].
///
/// Collection: current_affairs/{id}
/// Bookmarks: current_affairs_bookmarks/{userId}/items/{currentAffairId}
class CurrentAffairsRepositoryImpl implements CurrentAffairsRepository {
  const CurrentAffairsRepositoryImpl({
    required this.firestore,
    required this.notificationRepository,
  });

  final FirebaseFirestore firestore;
  final NotificationRepository notificationRepository;

  CollectionReference<Map<String, dynamic>> get _collection =>
      firestore.collection('current_affairs');

  @override
  Future<Either<Failure, CurrentAffair>> create({
    required String title,
    required String summary,
    required String content,
    required CurrentAffairsCategory category,
    String? source,
    String? imageUrl,
    required String createdBy,
    bool sendNotification = true,
  }) async {
    try {
      final now = DateTime.now();
      final docRef = _collection.doc();

      final data = {
        'title': title,
        'summary': summary,
        'content': content,
        'category': category.name,
        'source': source,
        'imageUrl': imageUrl,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(now),
        'publishedAt': Timestamp.fromDate(now),
      };

      await docRef.set(data);

      final affair = CurrentAffair(
        id: docRef.id,
        title: title,
        summary: summary,
        content: content,
        category: category,
        createdAt: now,
        source: source,
        imageUrl: imageUrl,
        publishedAt: now,
        createdBy: createdBy,
      );

      // Send push notification to all students
      if (sendNotification) {
        _notifyAllStudents(affair);
      }

      return Right(affair);
    } catch (e) {
      return Left(
        CurrentAffairsFailure(message: 'Failed to create: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, PaginatedCurrentAffairs>> getAll({
    CurrentAffairsCategory? category,
    int limit = 10,
    String? startAfterId,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _collection
          .orderBy('publishedAt', descending: true);

      if (category != null) {
        query = query.where('category', isEqualTo: category.name);
      }

      // Cursor-based pagination.
      if (startAfterId != null) {
        final cursorDoc = await _collection.doc(startAfterId).get();
        if (cursorDoc.exists) {
          query = query.startAfterDocument(cursorDoc);
        }
      }

      // Fetch limit+1 to detect if more pages exist.
      final snapshot = await query.limit(limit + 1).get();
      final docs = snapshot.docs;
      final hasMore = docs.length > limit;
      final pageDocs = hasMore ? docs.sublist(0, limit) : docs;

      final items = pageDocs.map(_fromDoc).toList();

      return Right(PaginatedCurrentAffairs(
        items: items,
        hasMore: hasMore,
        lastDocumentId: items.isNotEmpty ? items.last.id : null,
      ));
    } catch (e) {
      return Left(
        CurrentAffairsFailure(message: 'Failed to fetch: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, CurrentAffair>> getById(String id) async {
    try {
      final doc = await _collection.doc(id).get();
      if (!doc.exists) {
        return const Left(
          CurrentAffairsFailure(message: 'Article not found'),
        );
      }
      return Right(_fromDoc(doc));
    } catch (e) {
      return Left(
        CurrentAffairsFailure(message: 'Failed to fetch: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> toggleBookmark({
    required String currentAffairId,
    required String userId,
    required bool isBookmarked,
  }) async {
    try {
      final ref = firestore
          .collection('current_affairs_bookmarks')
          .doc(userId)
          .collection('items')
          .doc(currentAffairId);

      if (isBookmarked) {
        await ref.set({'bookmarkedAt': FieldValue.serverTimestamp()});
      } else {
        await ref.delete();
      }
      return const Right(null);
    } catch (e) {
      return Left(
        CurrentAffairsFailure(message: 'Failed to update bookmark: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, Set<String>>> getBookmarkedIds(
    String userId,
  ) async {
    try {
      final snapshot = await firestore
          .collection('current_affairs_bookmarks')
          .doc(userId)
          .collection('items')
          .get();

      final ids = snapshot.docs.map((d) => d.id).toSet();
      return Right(ids);
    } catch (e) {
      return Left(
        CurrentAffairsFailure(message: 'Failed to fetch bookmarks: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> recordView({
    required String currentAffairId,
    required String userId,
  }) async {
    try {
      final viewRef = _collection
          .doc(currentAffairId)
          .collection('views')
          .doc(userId);

      final existing = await viewRef.get();
      if (existing.exists) return const Right(null);

      await firestore.runTransaction((tx) async {
        tx.set(viewRef, {'viewedAt': FieldValue.serverTimestamp()});
        tx.update(
          _collection.doc(currentAffairId),
          {'viewCount': FieldValue.increment(1)},
        );
      });

      return const Right(null);
    } catch (e) {
      return Left(
        CurrentAffairsFailure(message: 'Failed to record view: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> toggleLike({
    required String currentAffairId,
    required String userId,
    required bool isLiked,
  }) async {
    try {
      final articleLikeRef = _collection
          .doc(currentAffairId)
          .collection('likes')
          .doc(userId);

      // User-scoped collection mirrors bookmarks pattern for reliable queries
      final userLikeRef = firestore
          .collection('current_affairs_likes')
          .doc(userId)
          .collection('items')
          .doc(currentAffairId);

      await firestore.runTransaction((tx) async {
        final likeDoc = await tx.get(articleLikeRef);
        final alreadyLiked = likeDoc.exists;

        if (isLiked && alreadyLiked) return;
        if (!isLiked && !alreadyLiked) return;

        if (isLiked) {
          tx.set(articleLikeRef, {'likedAt': FieldValue.serverTimestamp()});
          tx.set(userLikeRef, {'likedAt': FieldValue.serverTimestamp()});
          tx.update(
            _collection.doc(currentAffairId),
            {'likeCount': FieldValue.increment(1)},
          );
        } else {
          tx.delete(articleLikeRef);
          tx.delete(userLikeRef);
          tx.update(
            _collection.doc(currentAffairId),
            {'likeCount': FieldValue.increment(-1)},
          );
        }
      });

      return Right(isLiked);
    } catch (e) {
      return Left(
        CurrentAffairsFailure(message: 'Failed to toggle like: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, Set<String>>> getLikedIds(String userId) async {
    try {
      final snapshot = await firestore
          .collection('current_affairs_likes')
          .doc(userId)
          .collection('items')
          .get();

      final ids = snapshot.docs.map((d) => d.id).toSet();
      return Right(ids);
    } catch (e) {
      return Left(
        CurrentAffairsFailure(message: 'Failed to fetch likes: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> delete(String id) async {
    try {
      await _collection.doc(id).delete();
      return const Right(null);
    } catch (e) {
      return Left(
        CurrentAffairsFailure(message: 'Failed to delete: $e'),
      );
    }
  }

  // ===========================================================================
  // Private Helpers
  // ===========================================================================

  CurrentAffair _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return CurrentAffair(
      id: doc.id,
      title: data['title'] as String? ?? '',
      summary: data['summary'] as String? ?? '',
      content: data['content'] as String? ?? '',
      category: CurrentAffairsCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => CurrentAffairsCategory.other,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      source: data['source'] as String?,
      imageUrl: data['imageUrl'] as String?,
      publishedAt: (data['publishedAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String?,
      viewCount: (data['viewCount'] as num?)?.toInt() ?? 0,
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
    );
  }

  /// Fire-and-forget notification to all students on the platform.
  void _notifyAllStudents(CurrentAffair affair) async {
    try {
      // Query all student user IDs
      final usersSnapshot = await firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();

      final userIds = usersSnapshot.docs.map((d) => d.id).toList();
      if (userIds.isEmpty) return;

      final categoryEmoji = _categoryEmoji(affair.category);

      await notificationRepository.sendNotificationsToUsers(
        userIds: userIds,
        title: '$categoryEmoji Current Affairs Update',
        body: affair.title,
        data: {
          'type': 'current_affair',
          'currentAffairId': affair.id,
        },
      );
    } catch (_) {
      // Fire-and-forget: don't fail the create operation
    }
  }

  String _categoryEmoji(CurrentAffairsCategory category) {
    switch (category) {
      case CurrentAffairsCategory.national:
        return '🇮🇳';
      case CurrentAffairsCategory.international:
        return '🌍';
      case CurrentAffairsCategory.economy:
        return '📊';
      case CurrentAffairsCategory.science:
        return '🔬';
      case CurrentAffairsCategory.environment:
        return '🌿';
      case CurrentAffairsCategory.polity:
        return '🏛️';
      case CurrentAffairsCategory.sports:
        return '🏆';
      case CurrentAffairsCategory.defense:
        return '🛡️';
      case CurrentAffairsCategory.other:
        return '📰';
    }
  }
}
