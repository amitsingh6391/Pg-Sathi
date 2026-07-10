import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/library.dart';
import 'package:pg_manager/domain/entities/library_stats.dart';
import 'package:pg_manager/domain/failures/library_failures.dart';
import 'package:pg_manager/domain/usecases/create_library.dart';
import 'package:pg_manager/domain/usecases/get_library_stats.dart';
import 'package:pg_manager/domain/usecases/get_owner_library.dart';
import 'package:pg_manager/domain/usecases/update_library.dart';
import 'package:pg_manager/presentation/owner/bloc/owner_library_bloc.dart';
import 'package:pg_manager/presentation/owner/bloc/owner_library_event.dart';
import 'package:pg_manager/presentation/owner/bloc/owner_library_state.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'owner_library_bloc_test.mocks.dart';

@GenerateMocks([GetOwnerLibrary, GetLibraryStats, CreateLibrary, UpdateLibrary])
void main() {
  late OwnerLibraryBloc bloc;
  late MockGetOwnerLibrary mockGetOwnerLibrary;
  late MockGetLibraryStats mockGetLibraryStats;
  late MockCreateLibrary mockCreateLibrary;
  late MockUpdateLibrary mockUpdateLibrary;

  setUp(() {
    mockGetOwnerLibrary = MockGetOwnerLibrary();
    mockGetLibraryStats = MockGetLibraryStats();
    mockCreateLibrary = MockCreateLibrary();
    mockUpdateLibrary = MockUpdateLibrary();

    bloc = OwnerLibraryBloc(
      getOwnerLibrary: mockGetOwnerLibrary,
      getLibraryStats: mockGetLibraryStats,
      createLibrary: mockCreateLibrary,
      updateLibrary: mockUpdateLibrary,
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
            mockGetOwnerLibrary(any),
          ).thenAnswer((_) async => Right(testLibrary));
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
              .having(
                (s) => s.stats.occupiedSeats,
                'occupiedSeats',
                10,
              ), // 5 + 5
        ],
      );

      blocTest<OwnerLibraryBloc, OwnerLibraryState>(
        'emits_loaded_without_library_when_none_exists',
        build: () {
          when(
            mockGetOwnerLibrary(any),
          ).thenAnswer((_) async => const Right(null));
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
            mockGetOwnerLibrary(any),
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
    });

    group('CreateLibraryRequested', () {
      blocTest<OwnerLibraryBloc, OwnerLibraryState>(
        'emits_success_when_library_created',
        build: () {
          when(
            mockGetOwnerLibrary(any),
          ).thenAnswer((_) async => const Right(null));
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
            mockGetOwnerLibrary(any),
          ).thenAnswer((_) async => const Right(null));
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
            mockGetOwnerLibrary(any),
          ).thenAnswer((_) async => Right(testLibrary));
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
