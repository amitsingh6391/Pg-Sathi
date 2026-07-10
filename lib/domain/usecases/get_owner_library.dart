import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/library.dart';
import '../repositories/library_repository.dart';

/// Use case for getting the owner's library.
/// V1: Owner has at most one library.
class GetOwnerLibrary implements UseCase<Library?, GetOwnerLibraryParams> {
  const GetOwnerLibrary({required this.libraryRepository});

  final LibraryRepository libraryRepository;

  @override
  Future<Either<Failure, Library?>> call(GetOwnerLibraryParams params) async {
    if (params.ownerId.trim().isEmpty) {
      return const Right(null);
    }

    return libraryRepository.getLibraryByOwnerId(params.ownerId);
  }
}

/// Parameters for GetOwnerLibrary use case.
class GetOwnerLibraryParams extends Equatable {
  const GetOwnerLibraryParams({required this.ownerId});

  final String ownerId;

  @override
  List<Object?> get props => [ownerId];
}
