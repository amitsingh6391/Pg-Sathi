import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/library.dart';
import 'package:pg_manager/domain/failures/library_failures.dart';
import 'package:pg_manager/domain/repositories/library_repository.dart';
import 'package:pg_manager/domain/services/storage_service.dart';
import 'package:pg_manager/domain/usecases/delete_library_photo.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'delete_library_photo_test.mocks.dart';

@GenerateMocks([LibraryRepository, StorageService])
void main() {
  late DeleteLibraryPhoto useCase;
  late MockLibraryRepository mockRepository;
  late MockStorageService mockStorageService;

  setUp(() {
    mockRepository = MockLibraryRepository();
    mockStorageService = MockStorageService();
    useCase = DeleteLibraryPhoto(
      libraryRepository: mockRepository,
      storageService: mockStorageService,
    );
  });

  const photoUrl = 'https://storage.example.com/photo1.jpg';
  final testLibrary = Library(
    id: 'library-123',
    ownerId: 'owner-123',
    name: 'Test Library',
    capacity: 50,
    photos: [photoUrl, 'https://example.com/photo2.jpg'],
  );

  group('DeleteLibraryPhoto', () {
    test('should_return_failure_when_photo_not_found', () async {
      final libraryWithoutPhoto = testLibrary.copyWith(photos: []);

      final result = await useCase(
        DeleteLibraryPhotoParams(
          library: libraryWithoutPhoto,
          photoUrl: photoUrl,
        ),
      );

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<LibraryPhotoDeleteFailure>()),
        (r) => fail('Should return failure'),
      );
      verifyNever(mockRepository.updateLibrary(any));
    });

    test('should_remove_photo_and_update_library_when_successful', () async {
      when(mockRepository.updateLibrary(any)).thenAnswer(
        (_) async => Right(
          testLibrary.copyWith(
            photos: testLibrary.photos.where((url) => url != photoUrl).toList(),
          ),
        ),
      );

      when(mockStorageService.deleteImage(any)).thenAnswer((_) async => {});

      final result = await useCase(
        DeleteLibraryPhotoParams(library: testLibrary, photoUrl: photoUrl),
      );

      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.photos.length, 1);
        expect(r.photos, isNot(contains(photoUrl)));
      });
      verify(mockRepository.updateLibrary(any)).called(1);
      verify(mockStorageService.deleteImage(photoUrl)).called(1);
    });

    test('should_still_succeed_when_storage_delete_fails', () async {
      when(mockRepository.updateLibrary(any)).thenAnswer(
        (_) async => Right(
          testLibrary.copyWith(
            photos: testLibrary.photos.where((url) => url != photoUrl).toList(),
          ),
        ),
      );

      when(
        mockStorageService.deleteImage(any),
      ).thenThrow(Exception('Storage delete failed'));

      final result = await useCase(
        DeleteLibraryPhotoParams(library: testLibrary, photoUrl: photoUrl),
      );

      // Should still succeed even if storage delete fails
      expect(result.isRight(), true);
      verify(mockRepository.updateLibrary(any)).called(1);
    });

    test('should_return_failure_when_firestore_update_fails', () async {
      when(
        mockRepository.updateLibrary(any),
      ).thenAnswer((_) async => const Left(LibraryNotFoundFailure()));

      final result = await useCase(
        DeleteLibraryPhotoParams(library: testLibrary, photoUrl: photoUrl),
      );

      expect(result.isLeft(), true);
      verify(mockRepository.updateLibrary(any)).called(1);
      verifyNever(mockStorageService.deleteImage(any));
    });
  });
}
