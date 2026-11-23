import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/data/services/owner_branch_selection_service.dart';
import 'package:pg_manager/domain/entities/library.dart';
import 'package:pg_manager/domain/entities/library_stats.dart';
import 'package:pg_manager/domain/failures/library_failures.dart';
import 'package:pg_manager/domain/usecases/create_library.dart';
import 'package:pg_manager/domain/usecases/get_library_stats.dart';
import 'package:pg_manager/domain/usecases/get_owner_libraries.dart';
import 'package:pg_manager/domain/usecases/update_library.dart';
import 'package:pg_manager/presentation/owner/bloc/owner_library_bloc.dart';
import 'package:pg_manager/presentation/owner/bloc/owner_library_event.dart';
import 'package:pg_manager/presentation/owner/bloc/owner_library_state.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'owner_library_bloc_test.mocks.dart';

@GenerateMocks([
  GetOwnerLibraries,
  GetLibraryStats,
  CreateLibrary,
  UpdateLibrary,
  OwnerBranchSelectionService,
])
void main() {
  late OwnerLibraryBloc bloc;
  late MockGetOwnerLibraries mockGetOwnerLibraries;
  late MockGetLibraryStats mockGetLibraryStats;
  late MockCreateLibrary mockCreateLibrary;
  late MockUpdateLibrary mockUpdateLibrary;
  late MockOwnerBranchSelectionService mockBranchSelectionService;

  setUp(() {
    mockGetOwnerLibraries = MockGetOwnerLibraries();
    mockGetLibraryStats = MockGetLibraryStats();
    mockCreateLibrary = MockCreateLibrary();
    mockUpdateLibrary = MockUpdateLibrary();
    mockBranchSelectionService = MockOwnerBranchSelectionService();

    when(
      mockBranchSelectionService.setSelectedLibraryId(any, any),
    ).thenAnswer((_) async {});
    when(
      mockBranchSelectionService.getSelectedLibraryId(any),
    ).thenReturn(null);

    bloc = OwnerLibraryBloc(
      getOwnerLibraries: mockGetOwnerLibraries,
      getLibraryStats: mockGetLibraryStats,
      createLibrary: mockCreateLibrary,
      updateLibrary: mockUpdateLibrary,
      branchSelectionService: mockBranchSelectionService,
    );
  });

  tearDown(() {
    bloc.close();
  });

  const ownerId = 'owner-123';

  final testLibrary = Library(
    id: 'library-123',
    ownerId: ownerId,
    name: 'Test Library',
    fullAddress: 'Test Full Address',
    area: 'Test Area',
    capacity: 50,
  );

  final secondLibrary = Library(
    id: 'library-456',
    ownerId: ownerId,
    name: 'Second Branch',
    fullAddress: 'Second Full Address',
    area: 'Second Area',
    capacity: 30,
  );

  const testStats = LibraryStats(
    totalSeats: 50,
    occupiedSeats: 5,
    reservedSeats: 0,
  );

  group('OwnerLibraryBloc', () {
    test('initial_state_is_correct', () {
      expect(bloc.state.status, OwnerLibraryStatus.initial);
      expect(bloc.state.library, isNull);
      expect(bloc.state.hasLibrary, false);
    });

    group('LoadOwnerLibrary', () {
      blocTest<OwnerLibraryBloc, OwnerLibraryState>(
        'emits_loaded_with_library_when_exists',
        build: () {
          when(
            mockGetOwnerLibraries(any),
          ).thenAnswer((_) async => Right([testLibrary]));
          when(
            mockGetLibraryStats(any),
          ).thenAnswer((_) async => const Right(testStats));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadOwnerLibrary(ownerId: ownerId)),
        expect: () => [
          isA<OwnerLibraryState>().having(
            (s) => s.status,
            'status',
            OwnerLibraryStatus.loading,
          ),
          isA<OwnerLibraryState>()
              .having((s) => s.status, 'status', OwnerLibraryStatus.loaded)
              .having((s) => s.library, 'library', testLibrary)
              .having((s) => s.stats.totalSeats, 'totalSeats', 50)
              .having((s) => s.stats.occupiedSeats, 'occupiedSeats', 5),
        ],
      );

      blocTest<OwnerLibraryBloc, OwnerLibraryState>(
        'emits_loaded_without_library_when_none_exists',
        build: () {
          when(
            mockGetOwnerLibraries(any),
          ).thenAnswer((_) async => const Right([]));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadOwnerLibrary(ownerId: ownerId)),
        expect: () => [
          isA<OwnerLibraryState>().having(
            (s) => s.status,
            'status',
            OwnerLibraryStatus.loading,
          ),
          isA<OwnerLibraryState>()
              .having((s) => s.status, 'status', OwnerLibraryStatus.loaded)
              .having((s) => s.library, 'library', isNull),
        ],
      );

      blocTest<OwnerLibraryBloc, OwnerLibraryState>(
        'emits_error_when_loading_fails',
        build: () {
          when(
            mockGetOwnerLibraries(any),
          ).thenAnswer((_) async => const Left(LibraryNotFoundFailure()));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadOwnerLibrary(ownerId: ownerId)),
        expect: () => [
          isA<OwnerLibraryState>().having(
            (s) => s.status,
            'status',
            OwnerLibraryStatus.loading,
          ),
          isA<OwnerLibraryState>()
              .having((s) => s.status, 'status', OwnerLibraryStatus.error)
              .having(
                (s) => s.failure,
                'failure',
                isA<LibraryNotFoundFailure>(),
              ),
        ],
      );

      blocTest<OwnerLibraryBloc, OwnerLibraryState>(
        'restores_persisted_selection_when_branch_still_exists',
        build: () {
          when(
            mockGetOwnerLibraries(any),
          ).thenAnswer((_) async => Right([testLibrary, secondLibrary]));
          when(
            mockBranchSelectionService.getSelectedLibraryId(ownerId),
          ).thenReturn(secondLibrary.id);
          when(
            mockGetLibraryStats(any),
          ).thenAnswer((_) async => const Right(testStats));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadOwnerLibrary(ownerId: ownerId)),
        expect: () => [
          isA<OwnerLibraryState>().having(
            (s) => s.status,
            'status',
            OwnerLibraryStatus.loading,
          ),
          isA<OwnerLibraryState>()
              .having((s) => s.status, 'status', OwnerLibraryStatus.loaded)
              .having((s) => s.selectedLibraryIndex, 'index', 1)
              .having((s) => s.library, 'library', secondLibrary),
        ],
      );

      blocTest<OwnerLibraryBloc, OwnerLibraryState>(
        'falls_back_to_first_branch_when_persisted_branch_no_longer_exists',
        build: () {
          when(
            mockGetOwnerLibraries(any),
          ).thenAnswer((_) async => Right([testLibrary, secondLibrary]));
          when(
            mockBranchSelectionService.getSelectedLibraryId(ownerId),
          ).thenReturn('library-deleted');
          when(
            mockGetLibraryStats(any),
          ).thenAnswer((_) async => const Right(testStats));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadOwnerLibrary(ownerId: ownerId)),
        expect: () => [
          isA<OwnerLibraryState>().having(
            (s) => s.status,
            'status',
            OwnerLibraryStatus.loading,
          ),
          isA<OwnerLibraryState>()
              .having((s) => s.status, 'status', OwnerLibraryStatus.loaded)
              .having((s) => s.selectedLibraryIndex, 'index', 0)
              .having((s) => s.library, 'library', testLibrary),
        ],
      );
    });

    group('SelectLibrary', () {
      blocTest<OwnerLibraryBloc, OwnerLibraryState>(
        'persists_chosen_branch',
        build: () {
          when(
            mockGetOwnerLibraries(any),
          ).thenAnswer((_) async => Right([testLibrary, secondLibrary]));
          when(
            mockGetLibraryStats(any),
          ).thenAnswer((_) async => const Right(testStats));
          return bloc;
        },
        act: (bloc) async {
          bloc.add(const LoadOwnerLibrary(ownerId: ownerId));
          await Future.delayed(const Duration(milliseconds: 100));
          bloc.add(const SelectLibrary(index: 1));
        },
        verify: (_) {
          verify(
            mockBranchSelectionService.setSelectedLibraryId(
              ownerId,
              secondLibrary.id,
            ),
          ).called(1);
        },
      );
    });

    group('CreateLibraryRequested', () {
      blocTest<OwnerLibraryBloc, OwnerLibraryState>(
        'emits_success_when_library_created',
        build: () {
          when(
            mockGetOwnerLibraries(any),
          ).thenAnswer((_) async => const Right([]));
          when(
            mockCreateLibrary(any),
          ).thenAnswer((_) async => Right(testLibrary));
          return bloc;
        },
        act: (bloc) async {
          // First load to set ownerId
          bloc.add(const LoadOwnerLibrary(ownerId: ownerId));
          await Future.delayed(const Duration(milliseconds: 100));
          bloc.add(
            const CreateLibraryRequested(
              name: 'Test Library',
              location: 'Test Location',
              capacity: 50,
            ),
          );
        },
        verify: (_) {
          verify(mockCreateLibrary(any)).called(1);
        },
      );

      blocTest<OwnerLibraryBloc, OwnerLibraryState>(
        'emits_failure_when_create_fails',
        build: () {
          when(
            mockGetOwnerLibraries(any),
          ).thenAnswer((_) async => const Right([]));
          when(mockCreateLibrary(any)).thenAnswer(
            (_) async => const Left(
              LibraryAlreadyExistsFailure(message: 'Already exists'),
            ),
          );
          return bloc;
        },
        act: (bloc) async {
          bloc.add(const LoadOwnerLibrary(ownerId: ownerId));
          await Future.delayed(const Duration(milliseconds: 100));
          bloc.add(
            const CreateLibraryRequested(
              name: 'Test Library',
              location: 'Test Location',
              capacity: 50,
            ),
          );
        },
        expect: () => [
          isA<OwnerLibraryState>().having(
            (s) => s.status,
            'status',
            OwnerLibraryStatus.loading,
          ),
          isA<OwnerLibraryState>().having(
            (s) => s.status,
            'status',
            OwnerLibraryStatus.loaded,
          ),
          isA<OwnerLibraryState>().having(
            (s) => s.formStatus,
            'formStatus',
            FormStatus.submitting,
          ),
          isA<OwnerLibraryState>()
              .having((s) => s.formStatus, 'formStatus', FormStatus.failure)
              .having(
                (s) => s.failure,
                'failure',
                isA<LibraryAlreadyExistsFailure>(),
              ),
        ],
      );
    });

    group('UpdateLibraryRequested', () {
      blocTest<OwnerLibraryBloc, OwnerLibraryState>(
        'emits_success_when_library_updated',
        build: () {
          when(
            mockGetOwnerLibraries(any),
          ).thenAnswer((_) async => Right([testLibrary]));
          when(
            mockGetLibraryStats(any),
          ).thenAnswer((_) async => const Right(testStats));
          when(mockUpdateLibrary(any)).thenAnswer(
            (_) async => Right(testLibrary.copyWith(name: 'Updated')),
          );
          return bloc;
        },
        act: (bloc) async {
          bloc.add(const LoadOwnerLibrary(ownerId: ownerId));
          await Future.delayed(const Duration(milliseconds: 100));
          bloc.add(
            const UpdateLibraryRequested(
              name: 'Updated',
              location: 'Test Location',
              capacity: 50,
            ),
          );
        },
        verify: (_) {
          verify(mockUpdateLibrary(any)).called(1);
        },
      );
    });
  });
}
