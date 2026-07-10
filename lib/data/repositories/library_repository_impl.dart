import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../domain/core/failure.dart';
import '../../domain/entities/library.dart';
import '../../domain/repositories/library_repository.dart';
import '../mappers/library_mapper.dart';
import '../models/library_dto.dart';
import '../utils/firebase_error_handler.dart';

/// Firebase implementation of LibraryRepository.
/// V1: One library per owner.
class LibraryRepositoryImpl implements LibraryRepository {
  LibraryRepositoryImpl({required this.firestore});

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> get _librariesCollection =>
      firestore.collection(LibraryDto.collectionName);

  @override
  Future<Either<Failure, Library>> createLibrary(Library library) async {
    return FirebaseErrorHandler.guard(() async {
      final dto = LibraryMapper.toDto(library);
      await _librariesCollection.doc(library.id).set(dto.toFirestore());
      return library;
    });
  }

  @override
  Future<Either<Failure, Library>> updateLibrary(Library library) async {
    return FirebaseErrorHandler.guard(() async {
      final dto = LibraryMapper.toDto(library);
      final updateData = <String, dynamic>{...dto.toFirestore()};
      
      // Explicitly handle null customMonthlyPrice (when admin clears custom pricing)
      // We need to explicitly delete the field from Firestore
      if (library.customMonthlyPrice == null && 
          !updateData.containsKey('customMonthlyPrice')) {
        updateData['customMonthlyPrice'] = FieldValue.delete();
      }
      
      await _librariesCollection.doc(library.id).update(updateData);
      return library;
    });
  }

  @override
  Future<Either<Failure, Library?>> getLibraryById(String libraryId) async {
    return FirebaseErrorHandler.guard(() async {
      final doc = await _librariesCollection.doc(libraryId).get();
      if (!doc.exists) {
        return null;
      }
      final dto = LibraryDto.fromFirestore(doc);
      return LibraryMapper.toEntity(dto);
    });
  }

  @override
  Future<Either<Failure, Library?>> getLibraryByOwnerId(String ownerId) async {
    return FirebaseErrorHandler.guard(() async {
      final query = await _librariesCollection
          .where('ownerId', isEqualTo: ownerId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return null;
      }

      final dto = LibraryDto.fromFirestore(query.docs.first);
      return LibraryMapper.toEntity(dto);
    });
  }

  @override
  Future<Either<Failure, bool>> ownerHasLibrary(String ownerId) async {
    return FirebaseErrorHandler.guard(() async {
      final query = await _librariesCollection
          .where('ownerId', isEqualTo: ownerId)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    });
  }

  @override
  Future<Either<Failure, List<Library>>> getAllCompletedLibraries() async {
    return FirebaseErrorHandler.guard(() async {
      final query = await _librariesCollection
          .where('isProfileComplete', isEqualTo: true)
          .get();

      return query.docs.map((doc) {
        final dto = LibraryDto.fromFirestore(doc);
        return LibraryMapper.toEntity(dto);
      }).toList();
    });
  }

  @override
  Future<Either<Failure, List<Library>>> getAllLibraries() async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _librariesCollection.get();
      return snapshot.docs.map((doc) {
        final dto = LibraryDto.fromFirestore(doc);
        return LibraryMapper.toEntity(dto);
      }).toList();
    });
  }
}
