import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/membership.dart';
import 'package:pg_manager/domain/entities/slot.dart';
import 'package:pg_manager/domain/usecases/get_occupied_seats.dart';
import 'package:pg_manager/presentation/owner/cubit/occupied_seats_state.dart';

void main() {
  // Test fixtures
  final now = DateTime.now();

  Membership createMembership({
    required String id,
    String? userId,
    required String seatId,
    required String phoneNumber,
    String? slotId,
    Slot? slot,
  }) {
    return Membership(
      id: id,
      userId: userId,
      libraryId: 'lib-1',
      assignedSeatId: seatId,
      plan: MembershipPlan.monthly,
      startDate: now,
      endDate: now.add(const Duration(days: 30)),
      status: MembershipStatus.active,
      phoneNumber: phoneNumber,
      slot: slot,
      slotId: slotId,
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

  group('OccupiedSeatsState', () {
    group('hasActiveSearch', () {
      test('should return false when searchQuery is empty', () {
        const state = OccupiedSeatsState(searchQuery: '');
        expect(state.hasActiveSearch, false);
      });

      test('should return false when searchQuery is whitespace only', () {
        const state = OccupiedSeatsState(searchQuery: '   ');
        expect(state.hasActiveSearch, false);
      });

      test('should return true when searchQuery has content', () {
        const state = OccupiedSeatsState(searchQuery: 'john');
        expect(state.hasActiveSearch, true);
      });
    });

    group('searchSeats', () {
      late List<OccupiedSeatInfo> testSeats;

      setUp(() {
        testSeats = [
          createSeatInfo(
            seatId: 'S01',
            membership: createMembership(
              id: 'mem-1',
              userId: 'user-1',
              seatId: 'S01',
              phoneNumber: '+919876543210',
              slot: Slot.morning,
            ),
            studentName: 'John Doe',
            studentPhone: '+919876543210',
          ),
          createSeatInfo(
            seatId: 'S02',
            membership: createMembership(
              id: 'mem-2',
              userId: 'user-2',
              seatId: 'S02',
              phoneNumber: '+919876543211',
              slot: Slot.evening,
            ),
            studentName: 'Jane Smith',
            studentPhone: '+919876543211',
          ),
          createSeatInfo(
            seatId: 'S10',
            membership: createMembership(
              id: 'mem-3',
              userId: 'user-3',
              seatId: 'S10',
              phoneNumber: '+919999888877',
              slot: Slot.morning,
            ),
            studentName: 'Bob Johnson',
            studentPhone: '+919999888877',
          ),
          createSeatInfo(
            seatId: 'S15',
            membership: createMembership(
              id: 'mem-4',
              seatId: 'S15',
              phoneNumber: '+918888777766',
              slot: Slot.evening,
            ),
            studentName: null, // Unregistered student
            studentPhone: '+918888777766',
          ),
        ];
      });

      test('should return all seats when query is empty', () {
        const state = OccupiedSeatsState(searchQuery: '');
        final results = state.searchSeats(testSeats);
        expect(results.length, 4);
      });

      test('should return all seats when query is whitespace', () {
        const state = OccupiedSeatsState(searchQuery: '   ');
        final results = state.searchSeats(testSeats);
        expect(results.length, 4);
      });

      group('search by name', () {
        test('should find seat by full name (case insensitive)', () {
          const state = OccupiedSeatsState(searchQuery: 'john doe');
          final results = state.searchSeats(testSeats);
          expect(results.length, 1);
          expect(results.first.studentName, 'John Doe');
        });

        test('should find seat by partial name', () {
          const state = OccupiedSeatsState(searchQuery: 'jan');
          final results = state.searchSeats(testSeats);
          expect(results.length, 1);
          expect(results.first.studentName, 'Jane Smith');
        });

        test('should find multiple seats matching name pattern', () {
          const state = OccupiedSeatsState(searchQuery: 'jo');
          final results = state.searchSeats(testSeats);
          expect(results.length, 2); // John Doe and Bob Johnson
        });

        test('should be case insensitive', () {
          const state = OccupiedSeatsState(searchQuery: 'JANE');
          final results = state.searchSeats(testSeats);
          expect(results.length, 1);
          expect(results.first.studentName, 'Jane Smith');
        });
      });

      group('search by phone number', () {
        test('should find seat by full phone number', () {
          const state = OccupiedSeatsState(searchQuery: '9876543210');
          final results = state.searchSeats(testSeats);
          expect(results.length, 1);
          expect(results.first.seatId, 'S01');
        });

        test('should find seat by phone with +91 prefix', () {
          const state = OccupiedSeatsState(searchQuery: '+919876543211');
          final results = state.searchSeats(testSeats);
          expect(results.length, 1);
          expect(results.first.seatId, 'S02');
        });

        test('should find seat by partial phone number', () {
          const state = OccupiedSeatsState(searchQuery: '9999');
          final results = state.searchSeats(testSeats);
          expect(results.length, 1);
          expect(results.first.studentName, 'Bob Johnson');
        });

        test('should find unregistered student by phone', () {
          const state = OccupiedSeatsState(searchQuery: '8888777766');
          final results = state.searchSeats(testSeats);
          expect(results.length, 1);
          expect(results.first.seatId, 'S15');
          expect(results.first.studentName, isNull);
        });
      });

      group('search by seat ID', () {
        test('should find seat by full seat ID', () {
          const state = OccupiedSeatsState(searchQuery: 'S01');
          final results = state.searchSeats(testSeats);
          expect(results.length, 1);
          expect(results.first.seatId, 'S01');
        });

        test('should find seat by seat ID (case insensitive)', () {
          const state = OccupiedSeatsState(searchQuery: 's02');
          final results = state.searchSeats(testSeats);
          expect(results.length, 1);
          expect(results.first.seatId, 'S02');
        });

        test('should find seat by seat number only', () {
          const state = OccupiedSeatsState(searchQuery: '10');
          final results = state.searchSeats(testSeats);
          // Matches S10 (seatId contains "10") and potentially S01 (contains "0" and "1")
          // But seat number 10 should match S10
          expect(results.any((s) => s.seatId == 'S10'), true);
        });

        test('should find multiple seats matching partial seat ID', () {
          const state = OccupiedSeatsState(searchQuery: 'S1');
          final results = state.searchSeats(testSeats);
          expect(results.length, 2); // S10 and S15
        });
      });

      group('no results', () {
        test('should return empty list when no match found', () {
          const state = OccupiedSeatsState(searchQuery: 'xyz');
          final results = state.searchSeats(testSeats);
          expect(results, isEmpty);
        });

        test('should return empty list for non-existent phone', () {
          const state = OccupiedSeatsState(searchQuery: '1234567890');
          final results = state.searchSeats(testSeats);
          expect(results, isEmpty);
        });

        test('should return empty list for non-existent seat', () {
          const state = OccupiedSeatsState(searchQuery: 'S99');
          final results = state.searchSeats(testSeats);
          expect(results, isEmpty);
        });
      });

      group('edge cases', () {
        test('should handle empty seat list', () {
          const state = OccupiedSeatsState(searchQuery: 'john');
          final results = state.searchSeats([]);
          expect(results, isEmpty);
        });

        test('should handle special characters in query', () {
          const state = OccupiedSeatsState(searchQuery: '+91-9876');
          final results = state.searchSeats(testSeats);
          // Should normalize and find the phone
          expect(results.length, greaterThanOrEqualTo(1));
        });

        test('should handle query with leading/trailing spaces', () {
          const state = OccupiedSeatsState(searchQuery: '  john  ');
          final results = state.searchSeats(testSeats);
          // "john" matches "John Doe" and "Bob Johnson"
          expect(results.length, 2);
          expect(results.any((s) => s.studentName == 'John Doe'), true);
          expect(results.any((s) => s.studentName == 'Bob Johnson'), true);
        });
      });
    });

    group('copyWith', () {
      test('should update searchQuery', () {
        const state = OccupiedSeatsState(searchQuery: '');
        final newState = state.copyWith(searchQuery: 'test');
        expect(newState.searchQuery, 'test');
      });

      test('should clear searchQuery with clearSearch flag', () {
        const state = OccupiedSeatsState(searchQuery: 'test');
        final newState = state.copyWith(clearSearch: true);
        expect(newState.searchQuery, '');
      });

      test('should preserve searchQuery when not specified', () {
        const state = OccupiedSeatsState(searchQuery: 'test');
        final newState = state.copyWith(status: OccupiedSeatsStatus.loaded);
        expect(newState.searchQuery, 'test');
      });
    });

    group('props', () {
      test('should include searchQuery in props', () {
        const state1 = OccupiedSeatsState(searchQuery: 'test');
        const state2 = OccupiedSeatsState(searchQuery: 'test');
        const state3 = OccupiedSeatsState(searchQuery: 'different');

        expect(state1, equals(state2));
        expect(state1, isNot(equals(state3)));
      });
    });
  });
}
