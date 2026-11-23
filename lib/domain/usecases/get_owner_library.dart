import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/library.dart';
import '../repositories/library_repository.dart';

/// Use case for getting the owner's library.
/// V1: Owner has at most one library.
/// With multiple branches, pass [libraryId] to fetch a specific branch.
class GetOwnerLibrary implements UseCase<Library?, GetOwnerLibraryParams> {
  const GetOwnerLibrary({required this.libraryRepository});

  final LibraryRepository libraryRepository;

  @override
  Future<Either<Failure, Library?>> call(GetOwnerLibraryParams params) async {
    if (params.libraryId != null && params.libraryId!.isNotEmpty) {
      return libraryRepository.getLibraryById(params.libraryId!);
    }

    if (params.ownerId.trim().isEmpty) {
      return const Right(null);
    }

    return libraryRepository.getLibraryByOwnerId(params.ownerId);
  }
}

/// Parameters for GetOwnerLibrary use case.
class GetOwnerLibraryParams extends Equatable {
  const GetOwnerLibraryParams({required this.ownerId, this.libraryId});

  final String ownerId;

  /// Specific branch to load. When null, falls back to owner-level lookup.
  final String? libraryId;

  @override
  List<Object?> get props => [ownerId, libraryId];
}
