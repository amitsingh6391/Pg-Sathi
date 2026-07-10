import 'package:equatable/equatable.dart';

/// A private note added by admin for a library.
class AdminNote extends Equatable {
  const AdminNote({
    required this.id,
    required this.libraryId,
    required this.content,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.followUpDate,
    this.isPinned = false,
    this.tags = const [],
  });

  final String id;
  final String libraryId;
  final String content;
  final String createdBy; // Admin user ID
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? followUpDate;
  final bool isPinned;
  final List<String> tags;

  bool get hasFollowUp => followUpDate != null;

  bool get isFollowUpDue {
    if (followUpDate == null) return false;
    return DateTime.now().isAfter(followUpDate!);
  }

  bool get isFollowUpSoon {
    if (followUpDate == null) return false;
    final diff = followUpDate!.difference(DateTime.now()).inDays;
    return diff >= 0 && diff <= 3;
  }

  @override
  List<Object?> get props => [
    id,
    libraryId,
    content,
    createdBy,
    createdAt,
    updatedAt,
    followUpDate,
    isPinned,
    tags,
  ];

  AdminNote copyWith({
    String? id,
    String? libraryId,
    String? content,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? followUpDate,
    bool? isPinned,
    List<String>? tags,
  }) {
    return AdminNote(
      id: id ?? this.id,
      libraryId: libraryId ?? this.libraryId,
      content: content ?? this.content,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      followUpDate: followUpDate ?? this.followUpDate,
      isPinned: isPinned ?? this.isPinned,
      tags: tags ?? this.tags,
    );
  }
}

/// Request to create a new admin note.
class CreateNoteRequest extends Equatable {
  const CreateNoteRequest({
    required this.libraryId,
    required this.content,
    required this.adminId,
    this.followUpDate,
    this.tags = const [],
  });

  final String libraryId;
  final String content;
  final String adminId;
  final DateTime? followUpDate;
  final List<String> tags;

  @override
  List<Object?> get props => [libraryId, content, adminId, followUpDate, tags];
}

/// Request to update an existing note.
class UpdateNoteRequest extends Equatable {
  const UpdateNoteRequest({
    required this.noteId,
    required this.content,
    required this.adminId,
    this.followUpDate,
    this.isPinned,
    this.tags,
  });

  final String noteId;
  final String content;
  final String adminId;
  final DateTime? followUpDate;
  final bool? isPinned;
  final List<String>? tags;

  @override
  List<Object?> get props => [
    noteId,
    content,
    adminId,
    followUpDate,
    isPinned,
    tags,
  ];
}

/// Summary of notes for a library.
class LibraryNotesSummary extends Equatable {
  const LibraryNotesSummary({
    required this.libraryId,
    required this.totalNotes,
    required this.pinnedNotes,
    required this.upcomingFollowUps,
    required this.overdueFollowUps,
    required this.latestNote,
  });

  const LibraryNotesSummary.empty({required this.libraryId})
    : totalNotes = 0,
      pinnedNotes = 0,
      upcomingFollowUps = 0,
      overdueFollowUps = 0,
      latestNote = null;

  final String libraryId;
  final int totalNotes;
  final int pinnedNotes;
  final int upcomingFollowUps;
  final int overdueFollowUps;
  final AdminNote? latestNote;

  bool get hasNotes => totalNotes > 0;
  bool get needsAttention => overdueFollowUps > 0;

  @override
  List<Object?> get props => [
    libraryId,
    totalNotes,
    pinnedNotes,
    upcomingFollowUps,
    overdueFollowUps,
    latestNote,
  ];
}
