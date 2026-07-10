import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../domain/core/failure.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/ai_chat_repository.dart';
import '../../domain/usecases/ai/ai_usecases.dart';

/// Firestore-backed implementation of [AiChatRepository].
///
/// Collection structure:
/// ai_chats/{userId}              — counter document (todayCount, lastCountDate)
/// ai_chats/{userId}/messages/{id} — individual chat messages
///
/// Optimizations:
/// - Paginated history: loads only N messages per page (cursor-based).
/// - Counter document: 1 read for daily limit check instead of scanning.
class AiChatRepositoryImpl implements AiChatRepository {
  const AiChatRepositoryImpl({required this.firestore});

  final FirebaseFirestore firestore;

  DocumentReference<Map<String, dynamic>> _userDoc(String userId) {
    return firestore.collection('ai_chats').doc(userId);
  }

  CollectionReference<Map<String, dynamic>> _messagesCollection(
    String userId,
  ) {
    return _userDoc(userId).collection('messages');
  }

  @override
  Future<Either<Failure, void>> saveMessage(ChatMessage message) async {
    try {
      await _messagesCollection(message.userId)
          .doc(message.id)
          .set(message.toMap());
      return const Right(null);
    } catch (e) {
      return Left(AiFailure(message: 'Failed to save message: $e'));
    }
  }

  @override
  Future<Either<Failure, PaginatedChatMessages>> getChatHistory(
    String userId, {
    int limit = 6,
    String? beforeMessageId,
  }) async {
    try {
      // Query newest first so we can grab the latest N messages.
      Query<Map<String, dynamic>> query = _messagesCollection(userId)
          .orderBy('timestamp', descending: true);

      // Cursor-based pagination: load older messages before a given doc.
      if (beforeMessageId != null) {
        final cursorDoc =
            await _messagesCollection(userId).doc(beforeMessageId).get();
        if (cursorDoc.exists) {
          query = query.startAfterDocument(cursorDoc);
        }
      }

      // Fetch limit+1 to check if more exist.
      final snapshot = await query.limit(limit + 1).get();
      final docs = snapshot.docs;
      final hasMore = docs.length > limit;
      final pageDocs = hasMore ? docs.sublist(0, limit) : docs;

      // Reverse to ascending order (oldest → newest) for UI display.
      final messages = pageDocs.reversed
          .map((doc) => ChatMessage.fromMap(doc.data()))
          .toList();

      return Right(PaginatedChatMessages(
        messages: messages,
        hasMore: hasMore,
        oldestMessageId: messages.isNotEmpty ? messages.first.id : null,
      ));
    } catch (e) {
      return Left(AiFailure(message: 'Failed to load chat history: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> clearHistory(String userId) async {
    try {
      // Delete in batches (Firestore batch limit = 500).
      QuerySnapshot<Map<String, dynamic>> snapshot;
      do {
        snapshot = await _messagesCollection(userId).limit(500).get();
        if (snapshot.docs.isEmpty) break;

        final batch = firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      } while (snapshot.docs.length == 500);

      // Reset counter document.
      await _userDoc(userId).set({
        'todayCount': 0,
        'lastCountDate': _todayString(),
      }, SetOptions(merge: true));

      return const Right(null);
    } catch (e) {
      return Left(AiFailure(message: 'Failed to clear history: $e'));
    }
  }

  // ===========================================================================
  // Daily query counter — single-document approach (1 read, 1 write)
  // ===========================================================================

  @override
  Future<Either<Failure, int>> getTodayQueryCount(String userId) async {
    try {
      final doc = await _userDoc(userId).get();
      if (!doc.exists) return const Right(0);

      final data = doc.data()!;
      final lastDate = data['lastCountDate'] as String?;

      // If the counter is from a previous day, treat as 0.
      if (lastDate != _todayString()) return const Right(0);

      return Right((data['todayCount'] as num?)?.toInt() ?? 0);
    } catch (e) {
      // Default to 0 on error to not block the user.
      return const Right(0);
    }
  }

  @override
  Future<void> incrementTodayQueryCount(String userId) async {
    try {
      final today = _todayString();
      final doc = await _userDoc(userId).get();

      if (!doc.exists || doc.data()?['lastCountDate'] != today) {
        // New day — reset to 1.
        await _userDoc(userId).set({
          'todayCount': 1,
          'lastCountDate': today,
        }, SetOptions(merge: true));
      } else {
        // Same day — atomic increment.
        await _userDoc(userId).update({
          'todayCount': FieldValue.increment(1),
        });
      }
    } catch (_) {
      // Non-critical: silently ignore counter update failures.
    }
  }

  /// Returns today's date as YYYY-MM-DD for the counter document.
  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
