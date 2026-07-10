import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/library.dart';
import 'package:pg_manager/domain/failures/library_failures.dart';
import 'package:pg_manager/domain/repositories/library_repository.dart';
import 'package:pg_manager/domain/services/storage_service.dart';
import 'package:pg_manager/domain/usecases/update_library_photos.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'update_library_photos_test.mocks.dart';

@GenerateMocks([LibraryRepository, StorageService])
void main() {
  late UpdateLibraryPhotos useCase;
  late MockLibraryRepository mockRepository;
  late MockStorageService mockStorageService;

  setUp(() {
    mockRepository = MockLibraryRepository();
    mockStorageService = MockStorageService();
    useCase = UpdateLibraryPhotos(
      libraryRepository: mockRepository,
      storageService: mockStorageService,
    );
  });

  final testLibrary = Library(
    id: 'library-123',
    ownerId: 'owner-123',
    name: 'Test Library',
    capacity: 50,
    photos: ['https://example.com/photo1.jpg'],
  );

  group('UpdateLibraryPhotos', () {
    test('should_return_failure_when_photo_limit_exceeded', () async {
      final libraryWithMaxPhotos = testLibrary.copyWith(
        photos: List.generate(5, (i) => 'https://example.com/photo$i.jpg'),
      );
      final newPhotos = [File('test1.jpg'), File('test2.jpg')];

      final result = await useCase(
        UpdateLibraryPhotosParams(
          library: libraryWithMaxPhotos,
          newPhotos: newPhotos,
        ),
      );

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<LibraryPhotoLimitExceededFailure>()),
        (r) => fail('Should return failure'),
      );
      verifyNever(
        mockStorageService.uploadImage(
          file: anyNamed('file'),
          path: anyNamed('path'),
        ),
      );
    });

    test('should_upload_photos_and_update_library_when_successful', () async {
      final newPhotos = [File('test1.jpg'), File('test2.jpg')];
      final uploadedUrls = [
        'https://storage.example.com/photo1.jpg',
        'https://storage.example.com/photo2.jpg',
      ];
      var callCount = 0;

      when(
        mockStorageService.uploadImage(
          file: anyNamed('file'),
          path: anyNamed('path'),
        ),
      ).thenAnswer((_) async {
        final url = uploadedUrls[callCount];
        callCount++;
        return url;
      });

      when(mockRepository.updateLibrary(any)).thenAnswer((invocation) async {
        final library = invocation.positionalArguments[0] as Library;
        return Right(library);
      });

      final result = await useCase(
        UpdateLibraryPhotosParams(library: testLibrary, newPhotos: newPhotos),
      );

      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.photos.length, 3); // 1 existing + 2 new
        expect(r.photos, containsAll(uploadedUrls));
        expect(r.photos, contains(testLibrary.photos.first));
      });
      verify(
        mockStorageService.uploadImage(
          file: anyNamed('file'),
          path: anyNamed('path'),
        ),
      ).called(2);
      verify(mockRepository.updateLibrary(any)).called(1);
    });

    test('should_return_failure_when_upload_fails', () async {
      final newPhotos = [File('test1.jpg')];

      when(
        mockStorageService.uploadImage(
          file: anyNamed('file'),
          path: anyNamed('path'),
        ),
      ).thenThrow(Exception('Upload failed'));

      final result = await useCase(
        UpdateLibraryPhotosParams(library: testLibrary, newPhotos: newPhotos),
      );

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<LibraryPhotoUploadFailure>()),
        (r) => fail('Should return failure'),
      );
      verifyNever(mockRepository.updateLibrary(any));
    });

    test('should_delete_uploaded_photos_when_firestore_update_fails', () async {
      final newPhotos = [File('test1.jpg')];
      const uploadedUrl = 'https://storage.example.com/photo1.jpg';

      when(
        mockStorageService.uploadImage(
          file: anyNamed('file'),
          path: anyNamed('path'),
        ),
      ).thenAnswer((_) async => uploadedUrl);

      when(
        mockRepository.updateLibrary(any),
      ).thenAnswer((_) async => const Left(LibraryNotFoundFailure()));

      when(mockStorageService.deleteImages(any)).thenAnswer((_) async => []);

      final result = await useCase(
        UpdateLibraryPhotosParams(library: testLibrary, newPhotos: newPhotos),
      );

      expect(result.isLeft(), true);
      verify(mockStorageService.deleteImages([uploadedUrl])).called(1);
    });
  });
}
