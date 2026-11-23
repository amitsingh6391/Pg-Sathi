import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/library.dart';
import '../repositories/library_repository.dart';

/// Use case for getting all libraries owned by an owner (multi-branch).
class GetOwnerLibraries
    implements UseCase<List<Library>, GetOwnerLibrariesParams> {
  const GetOwnerLibraries({required this.libraryRepository});

  final LibraryRepository libraryRepository;

  @override
  Future<Either<Failure, List<Library>>> call(
    GetOwnerLibrariesParams params,
  ) async {
    if (params.ownerId.trim().isEmpty) {
      return const Right([]);
    }

    final result = await libraryRepository.getLibrariesByOwnerId(
      params.ownerId,
    );
    final only = params.onlyLibraryIds;
    if (only == null) return result;
    return result.map(
      (libraries) => libraries.where((l) => only.contains(l.id)).toList(),
    );
  }
}

/// Parameters for GetOwnerLibraries use case.
class GetOwnerLibrariesParams extends Equatable {
  const GetOwnerLibrariesParams({required this.ownerId, this.onlyLibraryIds});

  final String ownerId;

  /// Set for managers: only these libraries are returned.
  final List<String>? onlyLibraryIds;

  @override
  List<Object?> get props => [ownerId, onlyLibraryIds];
}
