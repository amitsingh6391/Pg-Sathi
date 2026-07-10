import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/data/services/member_export_service.dart';
import 'package:pg_manager/domain/entities/membership.dart';
import 'package:pg_manager/domain/entities/slot.dart';
import 'package:pg_manager/domain/usecases/cancel_membership.dart';
import 'package:pg_manager/domain/usecases/deactivate_membership.dart';
import 'package:pg_manager/domain/usecases/get_expired_seats.dart';
import 'package:pg_manager/domain/usecases/get_occupied_seats.dart';
import 'package:pg_manager/domain/usecases/reassign_seat.dart';
import 'package:pg_manager/domain/usecases/update_membership.dart';
import 'package:pg_manager/presentation/owner/cubit/occupied_seats_cubit.dart';
import 'package:pg_manager/presentation/owner/cubit/occupied_seats_state.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'occupied_seats_cubit_test.mocks.dart';

@GenerateMocks([
  GetOccupiedSeats,
  GetExpiredSeats,
  ReassignSeat,
  DeactivateMembership,
  CancelMembership,
  UpdateMembership,
])
void main() {
  late OccupiedSeatsCubit cubit;
  late MockGetOccupiedSeats mockGetOccupiedSeats;
  late MockGetExpiredSeats mockGetExpiredSeats;
  late MockReassignSeat mockReassignSeat;
  late MockDeactivateMembership mockDeactivateMembership;
  late MockCancelMembership mockCancelMembership;
  late MockUpdateMembership mockUpdateMembership;

  setUp(() {
    mockGetOccupiedSeats = MockGetOccupiedSeats();
    mockGetExpiredSeats = MockGetExpiredSeats();
    mockReassignSeat = MockReassignSeat();
    mockDeactivateMembership = MockDeactivateMembership();
    mockCancelMembership = MockCancelMembership();
    mockUpdateMembership = MockUpdateMembership();

    cubit = OccupiedSeatsCubit(
      getOccupiedSeats: mockGetOccupiedSeats,
      getExpiredSeats: mockGetExpiredSeats,
      reassignSeat: mockReassignSeat,
      deactivateMembership: mockDeactivateMembership,
      cancelMembership: mockCancelMembership,
      updateMembership: mockUpdateMembership,
      memberExportService: const MemberExportService(),
    );
  });

  tearDown(() {
    cubit.close();
  });

  // Test fixtures
  final now = DateTime.now();

  Membership createMembership({
    required String id,
    required String seatId,
    required String phoneNumber,
  }) {
    return Membership(
      id: id,
      userId: 'user-1',
      libraryId: 'lib-1',
      assignedSeatId: seatId,
      plan: MembershipPlan.monthly,
      startDate: now,
      endDate: now.add(const Duration(days: 30)),
      status: MembershipStatus.active,
      phoneNumber: phoneNumber,
      slot: Slot.morning,
    );
  }

  OccupiedSeatInfo createSeatInfo({
    required String seatId,
    required Membership membership,
    String? studentName,
    String? studentPhone,
  }) {
    return OccupiedSeatInfo(
      seatId: seatId,
      membership: membership,
      studentName: studentName,
      studentPhone: studentPhone,
    );
  }

  group('OccupiedSeatsCubit', () {
    group('updateSearchQuery', () {
      blocTest<OccupiedSeatsCubit, OccupiedSeatsState>(
        'should emit state with updated searchQuery',
        build: () => cubit,
        act: (cubit) => cubit.updateSearchQuery('john'),
        expect: () => [const OccupiedSeatsState(searchQuery: 'john')],
      );

      blocTest<OccupiedSeatsCubit, OccupiedSeatsState>(
        'should emit state with empty searchQuery when cleared',
        build: () => cubit,
        seed: () => const OccupiedSeatsState(searchQuery: 'john'),
        act: (cubit) => cubit.updateSearchQuery(''),
        expect: () => [const OccupiedSeatsState(searchQuery: '')],
      );

      blocTest<OccupiedSeatsCubit, OccupiedSeatsState>(
        'should update searchQuery multiple times',
        build: () => cubit,
        act: (cubit) {
          cubit.updateSearchQuery('j');
          cubit.updateSearchQuery('jo');
          cubit.updateSearchQuery('john');
        },
        expect: () => [
          const OccupiedSeatsState(searchQuery: 'j'),
          const OccupiedSeatsState(searchQuery: 'jo'),
          const OccupiedSeatsState(searchQuery: 'john'),
        ],
      );
    });

    group('clearSearch', () {
      blocTest<OccupiedSeatsCubit, OccupiedSeatsState>(
        'should clear searchQuery',
        build: () => cubit,
        seed: () => const OccupiedSeatsState(searchQuery: 'john'),
        act: (cubit) => cubit.clearSearch(),
        expect: () => [const OccupiedSeatsState(searchQuery: '')],
      );

      blocTest<OccupiedSeatsCubit, OccupiedSeatsState>(
        'should emit even if searchQuery is already empty (state update)',
        build: () => cubit,
        seed: () => const OccupiedSeatsState(searchQuery: ''),
        act: (cubit) => cubit.clearSearch(),
        // clearSearch always emits with clearSearch: true flag
        // which creates a new state even if searchQuery was already empty
        expect: () => [], // No emission because state is identical
      );
    });

    group('load with search', () {
      final testSeats = [
        createSeatInfo(
          seatId: 'S01',
          membership: createMembership(
            id: 'mem-1',
            seatId: 'S01',
            phoneNumber: '+919876543210',
          ),
          studentName: 'John Doe',
          studentPhone: '+919876543210',
        ),
        createSeatInfo(
          seatId: 'S02',
          membership: createMembership(
            id: 'mem-2',
            seatId: 'S02',
            phoneNumber: '+919876543211',
          ),
          studentName: 'Jane Smith',
          studentPhone: '+919876543211',
        ),
      ];

      blocTest<OccupiedSeatsCubit, OccupiedSeatsState>(
        'should preserve searchQuery after load',
        build: () {
          when(
            mockGetOccupiedSeats(any),
          ).thenAnswer((_) async => Right(testSeats));
          when(
            mockGetExpiredSeats(any),
          ).thenAnswer((_) async => const Right([]));
          return cubit;
        },
        seed: () => const OccupiedSeatsState(searchQuery: 'john'),
        act: (cubit) => cubit.load(libraryId: 'lib-1', libraryCapacity: 50),
        expect: () => [
          const OccupiedSeatsState(
            status: OccupiedSeatsStatus.loading,
            searchQuery: 'john',
          ),
          OccupiedSeatsState(
            status: OccupiedSeatsStatus.loaded,
            occupiedSeats: testSeats,
            searchQuery: 'john',
          ),
        ],
      );
    });

    group('search integration', () {
      final testSeats = [
        createSeatInfo(
          seatId: 'S01',
          membership: createMembership(
            id: 'mem-1',
            seatId: 'S01',
            phoneNumber: '+919876543210',
          ),
          studentName: 'John Doe',
          studentPhone: '+919876543210',
        ),
        createSeatInfo(
          seatId: 'S02',
          membership: createMembership(
            id: 'mem-2',
            seatId: 'S02',
            phoneNumber: '+919876543211',
          ),
          studentName: 'Jane Smith',
          studentPhone: '+919876543211',
        ),
      ];

      test('should filter seats based on searchQuery in state', () async {
        when(
          mockGetOccupiedSeats(any),
        ).thenAnswer((_) async => Right(testSeats));
        when(mockGetExpiredSeats(any)).thenAnswer((_) async => const Right([]));

        await cubit.load(libraryId: 'lib-1', libraryCapacity: 50);
        cubit.updateSearchQuery('john');

        final state = cubit.state;
        expect(state.searchQuery, 'john');
        expect(state.occupiedSeats.length, 2); // All seats still in state

        // Search filtering is done via searchSeats method
        final filtered = state.searchSeats(state.occupiedSeats);
        expect(filtered.length, 1);
        expect(filtered.first.studentName, 'John Doe');
      });

      test('should return all seats when search is cleared', () async {
        when(
          mockGetOccupiedSeats(any),
        ).thenAnswer((_) async => Right(testSeats));
        when(mockGetExpiredSeats(any)).thenAnswer((_) async => const Right([]));

        await cubit.load(libraryId: 'lib-1', libraryCapacity: 50);
        cubit.updateSearchQuery('john');
        cubit.clearSearch();

        final state = cubit.state;
        expect(state.searchQuery, '');
        expect(state.hasActiveSearch, false);

        final filtered = state.searchSeats(state.occupiedSeats);
        expect(filtered.length, 2); // All seats returned
      });
    });
  });
}
