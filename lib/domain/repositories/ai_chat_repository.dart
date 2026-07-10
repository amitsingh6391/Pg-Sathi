import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/chat_message.dart';

/// Paginated response for chat history.
class PaginatedChatMessages {
  const PaginatedChatMessages({
    required this.messages,
    required this.hasMore,
    this.oldestMessageId,
  });

  /// Messages in ascending timestamp order (oldest → newest).
  final List<ChatMessage> messages;

  /// Whether there are older messages beyond this page.
  final bool hasMore;

  /// Cursor for loading the previous page (oldest message ID in this batch).
  final String? oldestMessageId;
}

/// Repository interface for AI chat persistence.
abstract class AiChatRepository {
  /// Saves a chat message to persistent storage.
  Future<Either<Failure, void>> saveMessage(ChatMessage message);

  /// Retrieves the latest [limit] messages, newest first, then reversed.
  ///
  /// [beforeMessageId] — cursor for pagination: pass the oldest message's ID
  /// from the previous page to load older messages.
  Future<Either<Failure, PaginatedChatMessages>> getChatHistory(
    String userId, {
    int limit = 6,
    String? beforeMessageId,
  });

  /// Clears all chat history for a user.
  Future<Either<Failure, void>> clearHistory(String userId);

  /// Returns the number of AI queries the user has made today.
  /// Uses a counter document — 1 read instead of scanning all messages.
  Future<Either<Failure, int>> getTodayQueryCount(String userId);

  /// Increments the daily query counter after a successful send.
  Future<void> incrementTodayQueryCount(String userId);
}
