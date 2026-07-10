import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/core/usecase.dart';
import 'package:pg_manager/domain/entities/library.dart';
import 'package:pg_manager/domain/entities/library_stats.dart';
import 'package:pg_manager/domain/entities/user.dart';
import 'package:pg_manager/domain/failures/library_failures.dart';
import 'package:pg_manager/domain/repositories/library_repository.dart';
import 'package:pg_manager/domain/repositories/user_repository.dart';
import 'package:pg_manager/domain/usecases/get_all_libraries.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'get_all_libraries_test.mocks.dart';

@GenerateMocks([LibraryRepository, UserRepository])
void main() {
  late GetAllLibraries useCase;
  late MockLibraryRepository mockRepo;
  late MockUserRepository mockUserRepo;

  setUp(() {
    mockRepo = MockLibraryRepository();
    mockUserRepo = MockUserRepository();
    useCase = GetAllLibraries(
      libraryRepository: mockRepo,
      userRepository: mockUserRepo,
    );
  });

  final testLibrary1 = Library(
    id: 'lib-1',
    ownerId: 'owner-1',
    name: 'Alpha Library',
    fullAddress: '123 Main St',
    area: 'Downtown',
    capacity: 50,
    isProfileComplete: true,
    hasWifi: true,
    hasAC: true,
  );

  final testLibrary2 = Library(
    id: 'lib-2',
    ownerId: 'owner-2',
    name: 'Beta Library',
    fullAddress: '456 Oak St',
    area: 'Suburb',
    capacity: 30,
    isProfileComplete: true,
    hasWifi: true,
  );

  group('GetAllLibraries', () {
    test(
      'should return empty list when no completed libraries exist',
      () async {
        // Arrange
        when(
          mockRepo.getAllCompletedLibraries(),
        ).thenAnswer((_) async => const Right([]));

        // Act
        final result = await useCase(const NoParams());

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (l) => fail('Should not return failure'),
          (r) => expect(r, isEmpty),
        );
      },
    );

    test('should return libraries with stats', () async {
      // Arrange
      when(
        mockRepo.getAllCompletedLibraries(),
      ).thenAnswer((_) async => Right([testLibrary1, testLibrary2]));

      // Stub getUsersByIds for owner visibility check
      when(
        mockUserRepo.getUsersByIds(['owner-1', 'owner-2']),
      ).thenAnswer((_) async => Right({}));

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.length, 2);
        // Should be sorted alphabetically by name
        expect(r[0].library.name, 'Alpha Library');
        expect(r[1].library.name, 'Beta Library');
      });
    });

    test('should include library stats with correct seat counts', () async {
      // Arrange
      when(
        mockRepo.getAllCompletedLibraries(),
      ).thenAnswer((_) async => Right([testLibrary1]));

      // Stub getUsersByIds for owner visibility check
      when(
        mockUserRepo.getUsersByIds(['owner-1']),
      ).thenAnswer((_) async => Right({}));

      // Act
      final result = await useCase(const NoParams());

      // Assert
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.length, 1);
        final stats = r.first.stats;
        expect(stats.totalSeats, 50);
        expect(stats.availableSeats, 50);
      });
    });

    test('should propagate repository failure', () async {
      // Arrange
      when(
        mockRepo.getAllCompletedLibraries(),
      ).thenAnswer((_) async => const Left(LibraryNotFoundFailure()));

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result.isLeft(), true);
    });

    test(
      'should_filter_libraries_when_owner_has_showMyLibraryInListing_false',
      () async {
        // Arrange
        final owner1 = const User(
          id: 'owner-1',
          name: 'Owner 1',
          phone: '+919876543210',
          role: UserRole.owner,
          showMyLibraryInListing: true, // Visible
        );
        final owner2 = const User(
          id: 'owner-2',
          name: 'Owner 2',
          phone: '+919876543211',
          role: UserRole.owner,
          showMyLibraryInListing: false, // Hidden
        );

        when(
          mockRepo.getAllCompletedLibraries(),
        ).thenAnswer((_) async => Right([testLibrary1, testLibrary2]));

        when(mockUserRepo.getUsersByIds(['owner-1', 'owner-2'])).thenAnswer(
          (_) async => Right({'owner-1': owner1, 'owner-2': owner2}),
        );

        // Act
        final result = await useCase(const NoParams());

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not return failure'), (r) {
          // Only library1 should be visible (owner-1 has showMyLibraryInListing=true)
          expect(r.length, 1);
          expect(r.first.library.id, 'lib-1');
          expect(r.first.library.name, 'Alpha Library');
        });
      },
    );

    test(
      'should_show_all_libraries_when_all_owners_have_showMyLibraryInListing_true',
      () async {
        // Arrange
        final owner1 = const User(
          id: 'owner-1',
          name: 'Owner 1',
          phone: '+919876543210',
          role: UserRole.owner,
          showMyLibraryInListing: true,
        );
        final owner2 = const User(
          id: 'owner-2',
          name: 'Owner 2',
          phone: '+919876543211',
          role: UserRole.owner,
          showMyLibraryInListing: true,
        );

        when(
          mockRepo.getAllCompletedLibraries(),
        ).thenAnswer((_) async => Right([testLibrary1, testLibrary2]));

        when(mockUserRepo.getUsersByIds(['owner-1', 'owner-2'])).thenAnswer(
          (_) async => Right({'owner-1': owner1, 'owner-2': owner2}),
        );

        // Act
        final result = await useCase(const NoParams());

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not return failure'), (r) {
          expect(r.length, 2);
        });
      },
    );

    test(
      'should_show_library_when_owner_not_found_defaults_to_visible',
      () async {
        // Arrange
        when(
          mockRepo.getAllCompletedLibraries(),
        ).thenAnswer((_) async => Right([testLibrary1]));

        // Owner not found in users map
        when(
          mockUserRepo.getUsersByIds(['owner-1']),
        ).thenAnswer((_) async => Right({}));

        // Act
        final result = await useCase(const NoParams());

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not return failure'), (r) {
          // Should show library when owner not found (default behavior)
          expect(r.length, 1);
        });
      },
    );
  });

  group('LibraryWithStats', () {
    test('should copy with distance', () {
      // Arrange
      final libWithStats = LibraryWithStats(
        library: testLibrary1,
        stats: const LibraryStats(
          totalSeats: 50,
          occupiedSeats: 0,
          reservedSeats: 0,
        ),
      );

      // Act
      final withDistance = libWithStats.copyWithDistance(5.5);

      // Assert
      expect(withDistance.distanceKm, 5.5);
      expect(withDistance.library, testLibrary1);
    });
  });
}
