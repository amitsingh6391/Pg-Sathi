import 'package:dartz/dartz.dart';

import '../../core/core.dart';
import '../../entities/admin_note.dart';
import '../../repositories/admin_intelligence_repository.dart';

/// Use case for creating a note.
class CreateAdminNote implements UseCase<AdminNote, CreateNoteRequest> {
  const CreateAdminNote({required this.repository});

  final AdminIntelligenceRepository repository;

  @override
  Future<Either<Failure, AdminNote>> call(CreateNoteRequest params) {
    return repository.createNote(params);
  }
}

/// Use case for updating a note.
class UpdateAdminNote implements UseCase<AdminNote, UpdateNoteRequest> {
  const UpdateAdminNote({required this.repository});

  final AdminIntelligenceRepository repository;

  @override
  Future<Either<Failure, AdminNote>> call(UpdateNoteRequest params) {
    return repository.updateNote(params);
  }
}

/// Use case for deleting a note.
class DeleteAdminNote implements UseCase<void, String> {
  const DeleteAdminNote({required this.repository});

  final AdminIntelligenceRepository repository;

  @override
  Future<Either<Failure, void>> call(String noteId) {
    return repository.deleteNote(noteId);
  }
}

/// Use case for getting notes for a library.
class GetNotesForLibrary implements UseCase<List<AdminNote>, String> {
  const GetNotesForLibrary({required this.repository});

  final AdminIntelligenceRepository repository;

  @override
  Future<Either<Failure, List<AdminNote>>> call(String libraryId) {
    return repository.getNotesForLibrary(libraryId);
  }
}

/// Use case for getting notes summary.
class GetNotesSummary implements UseCase<LibraryNotesSummary, String> {
  const GetNotesSummary({required this.repository});

  final AdminIntelligenceRepository repository;

  @override
  Future<Either<Failure, LibraryNotesSummary>> call(String libraryId) {
    return repository.getNotesSummary(libraryId);
  }
}

/// Use case for getting notes with follow-up reminders.
class GetNotesWithFollowUps implements UseCase<List<AdminNote>, bool> {
  const GetNotesWithFollowUps({required this.repository});

  final AdminIntelligenceRepository repository;

  @override
  Future<Either<Failure, List<AdminNote>>> call(bool overdueOnly) {
    return repository.getNotesWithFollowUps(overdueOnly: overdueOnly);
  }
}
