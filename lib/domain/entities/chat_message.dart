import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Represents a single message in an AI chat conversation.
class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.userId,
    required this.content,
    required this.role,
    required this.timestamp,
    this.imageBytes,
    this.imageMimeType,
    this.imageFileName,
  });

  final String id;
  final String userId;
  final String content;
  final ChatRole role;
  final DateTime timestamp;

  /// In-memory image bytes for display in current session.
  /// Not persisted to Firestore (too large). Shown only while app is open.
  final Uint8List? imageBytes;

  /// MIME type of the attached image (e.g. "image/jpeg").
  final String? imageMimeType;

  /// Original file name for display.
  final String? imageFileName;

  /// Whether this message has an image attachment.
  bool get hasImage => imageBytes != null && imageBytes!.isNotEmpty;

  ChatMessage copyWith({
    String? id,
    String? userId,
    String? content,
    ChatRole? role,
    DateTime? timestamp,
    Uint8List? imageBytes,
    String? imageMimeType,
    String? imageFileName,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      imageBytes: imageBytes ?? this.imageBytes,
      imageMimeType: imageMimeType ?? this.imageMimeType,
      imageFileName: imageFileName ?? this.imageFileName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'content': content,
      'role': role.name,
      'timestamp': timestamp.toIso8601String(),
      if (imageFileName != null) 'imageFileName': imageFileName,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      userId: map['userId'] as String,
      content: map['content'] as String,
      role: ChatRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => ChatRole.user,
      ),
      timestamp: DateTime.parse(map['timestamp'] as String),
      imageFileName: map['imageFileName'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, userId, content, role, timestamp];
}

/// The sender role for a chat message.
enum ChatRole {
  user,
  assistant,
}
