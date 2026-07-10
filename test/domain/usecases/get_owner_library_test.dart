import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/library.dart';
import 'package:pg_manager/domain/failures/library_failures.dart';
import 'package:pg_manager/domain/repositories/library_repository.dart';
import 'package:pg_manager/domain/usecases/get_owner_library.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'get_owner_library_test.mocks.dart';

@GenerateMocks([LibraryRepository])
void main() {
  late GetOwnerLibrary useCase;
  late MockLibraryRepository mockRepository;

  setUp(() {
    mockRepository = MockLibraryRepository();
    useCase = GetOwnerLibrary(libraryRepository: mockRepository);
  });

  const ownerId = 'owner-123';

  final testLibrary = Library(
    id: 'library-123',
    ownerId: ownerId,
    name: 'Test Library',
    location: 'Test Location',
    capacity: 50,
  );

  group('GetOwnerLibrary', () {
    test('should_return_null_when_ownerId_is_empty', () async {
      final result = await useCase(const GetOwnerLibraryParams(ownerId: ''));

      expect(result.isRight(), true);
      result.fold(
        (l) => fail('Should not return failure'),
        (r) => expect(r, isNull),
      );
      verifyNever(mockRepository.getLibraryByOwnerId(any));
    });

    test('should_return_library_when_exists', () async {
      when(
        mockRepository.getLibraryByOwnerId(any),
      ).thenAnswer((_) async => Right(testLibrary));

      final result = await useCase(
        const GetOwnerLibraryParams(ownerId: ownerId),
      );

      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r, isNotNull);
        expect(r!.name, 'Test Library');
      });
      verify(mockRepository.getLibraryByOwnerId(ownerId)).called(1);
    });

    test('should_return_null_when_no_library', () async {
      when(
        mockRepository.getLibraryByOwnerId(any),
      ).thenAnswer((_) async => const Right(null));

      final result = await useCase(
        const GetOwnerLibraryParams(ownerId: ownerId),
      );

      expect(result.isRight(), true);
      result.fold(
        (l) => fail('Should not return failure'),
        (r) => expect(r, isNull),
      );
    });

    test('should_return_failure_when_repository_fails', () async {
      when(
        mockRepository.getLibraryByOwnerId(any),
      ).thenAnswer((_) async => const Left(LibraryNotFoundFailure()));

      final result = await useCase(
        const GetOwnerLibraryParams(ownerId: ownerId),
      );

      expect(result.isLeft(), true);
      result.fold(
        (l) => expect(l, isA<LibraryNotFoundFailure>()),
        (r) => fail('Should return failure'),
      );
    });
  });

  group('GetOwnerLibraryParams', () {
    test('should_have_correct_props', () {
      const params = GetOwnerLibraryParams(ownerId: ownerId);
      expect(params.props, [ownerId]);
    });
  });
}
