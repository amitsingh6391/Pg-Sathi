import 'package:flutter_test/flutter_test.dart';

import 'package:pg_manager/domain/entities/custom_slot.dart';

void main() {
  group('CustomSlot', () {
    test('should create a valid slot', () {
      const slot = CustomSlot(
        id: 'slot1',
        libraryId: 'lib1',
        name: 'Morning',
        startTime: 360, // 6:00 AM
        endTime: 840, // 2:00 PM
        price: 500.0,
        capacity: 20,
      );

      expect(slot.id, 'slot1');
      expect(slot.name, 'Morning');
      expect(slot.startTime, 360);
      expect(slot.endTime, 840);
      expect(slot.price, 500.0);
      expect(slot.isActive, true);
      expect(slot.isValid, true);
    });

    test('should validate slot times correctly', () {
      const validSlot = CustomSlot(
        id: 'slot1',
        libraryId: 'lib1',
        name: 'Morning',
        startTime: 360,
        endTime: 840,
        price: 500.0,
        capacity: 20,
      );

      // Overnight slot: endTime < startTime is valid (spans to next day)
      const overnightSlot = CustomSlot(
        id: 'slot2',
        libraryId: 'lib1',
        name: 'Overnight',
        startTime: 840,
        endTime: 360,
        price: 500.0,
        capacity: 20,
      );

      // Same start and end time is the only truly invalid case
      const sameTimeSlot = CustomSlot(
        id: 'slot3',
        libraryId: 'lib1',
        name: 'Invalid',
        startTime: 840,
        endTime: 840,
        price: 500.0,
        capacity: 20,
      );

      expect(validSlot.isValid, true);
      expect(overnightSlot.isValid, true); // overnight slots are allowed
      expect(sameTimeSlot.isValid, false);
    });

    test('should detect overlapping slots', () {
      const slot1 = CustomSlot(
        id: 'slot1',
        libraryId: 'lib1',
        name: 'Morning',
        startTime: 360, // 6:00 AM
        endTime: 840, // 2:00 PM
        price: 500.0,
        capacity: 20,
      );

      const slot2 = CustomSlot(
        id: 'slot2',
        libraryId: 'lib1',
        name: 'Afternoon',
        startTime: 840, // 2:00 PM
        endTime: 1320, // 10:00 PM
        price: 600.0,
        capacity: 25,
      );

      const slot3 = CustomSlot(
        id: 'slot3',
        libraryId: 'lib1',
        name: 'Overlap',
        startTime: 720, // 12:00 PM - overlaps with slot1
        endTime: 900, // 3:00 PM - overlaps with slot2
        price: 550.0,
        capacity: 15,
      );

      expect(slot1.overlapsWith(slot2), false);
      expect(slot1.overlapsWith(slot3), true);
      expect(slot2.overlapsWith(slot3), true);
      expect(slot1.overlapsWith(slot1), false); // Same slot
    });

    test('should not overlap with inactive slots', () {
      const activeSlot = CustomSlot(
        id: 'slot1',
        libraryId: 'lib1',
        name: 'Morning',
        startTime: 360,
        endTime: 840,
        price: 500.0,
        capacity: 20,
        isActive: true,
      );

      const inactiveSlot = CustomSlot(
        id: 'slot2',
        libraryId: 'lib1',
        name: 'Inactive',
        startTime: 360,
        endTime: 840,
        price: 500.0,
        capacity: 20,
        isActive: false,
      );

      expect(activeSlot.overlapsWith(inactiveSlot), false);
    });

    test('should format display time correctly', () {
      const slot = CustomSlot(
        id: 'slot1',
        libraryId: 'lib1',
        name: 'Morning',
        startTime: 360, // 6:00 AM
        endTime: 840, // 2:00 PM
        price: 500.0,
        capacity: 20,
      );

      expect(slot.displayTime, contains('6:00'));
      expect(slot.displayTime, contains('2:00'));
      expect(slot.displayWithPrice, contains('₹500'));
    });

    test('should toggle active status', () {
      const slot = CustomSlot(
        id: 'slot1',
        libraryId: 'lib1',
        name: 'Morning',
        startTime: 360,
        endTime: 840,
        price: 500.0,
        capacity: 20,
        isActive: true,
      );

      final deactivated = slot.deactivate();
      expect(deactivated.isActive, false);

      final activated = deactivated.activate();
      expect(activated.isActive, true);
    });

    // ── Seat numbering ──────────────────────────────────────────────────

    group('effectivePrefix', () {
      test('defaults to S when seatPrefix is null', () {
        const slot = CustomSlot(
          id: 's1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 10,
        );
        expect(slot.effectivePrefix, 'S');
      });

      test('defaults to S when seatPrefix is empty string', () {
        const slot = CustomSlot(
          id: 's1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 10,
          seatPrefix: '',
        );
        expect(slot.effectivePrefix, 'S');
      });

      test('returns uppercased custom prefix', () {
        const slot = CustomSlot(
          id: 's1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 10,
          seatPrefix: 'a',
        );
        expect(slot.effectivePrefix, 'A');
      });

      test('trims whitespace before using prefix', () {
        const slot = CustomSlot(
          id: 's1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 10,
          seatPrefix: ' B ',
        );
        expect(slot.effectivePrefix, 'B');
      });
    });

    group('effectiveStartNumber', () {
      test('defaults to 1 when seatStartNumber is null', () {
        const slot = CustomSlot(
          id: 's1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 10,
        );
        expect(slot.effectiveStartNumber, 1);
      });

      test('defaults to 1 when seatStartNumber is 0', () {
        const slot = CustomSlot(
          id: 's1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 10,
          seatStartNumber: 0,
        );
        expect(slot.effectiveStartNumber, 1);
      });

      test('uses provided start number', () {
        const slot = CustomSlot(
          id: 's1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 10,
          seatStartNumber: 20,
        );
        expect(slot.effectiveStartNumber, 20);
      });
    });

    group('seatLabels', () {
      test('generates default S01..S05 when no prefix or start set', () {
        const slot = CustomSlot(
          id: 's1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 5,
        );
        expect(slot.seatLabels, ['S01', 'S02', 'S03', 'S04', 'S05']);
      });

      test('generates default S01..S20 for 20-seat slot', () {
        const slot = CustomSlot(
          id: 's1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 20,
        );
        expect(slot.seatLabels.first, 'S01');
        expect(slot.seatLabels.last, 'S20');
        expect(slot.seatLabels.length, 20);
      });

      test('applies custom prefix with default start', () {
        const slot = CustomSlot(
          id: 's1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 5,
          seatPrefix: 'A',
        );
        expect(slot.seatLabels, ['A01', 'A02', 'A03', 'A04', 'A05']);
      });

      test('applies custom prefix + custom start number', () {
        const slot = CustomSlot(
          id: 's1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 5,
          seatPrefix: 'A',
          seatStartNumber: 20,
        );
        expect(slot.seatLabels, ['A20', 'A21', 'A22', 'A23', 'A24']);
      });

      test('applies start number without prefix (falls back to S)', () {
        const slot = CustomSlot(
          id: 's1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 3,
          seatStartNumber: 10,
        );
        expect(slot.seatLabels, ['S10', 'S11', 'S12']);
      });

      test('correct count always equals capacity', () {
        const slot = CustomSlot(
          id: 's1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 30,
          seatPrefix: 'R',
          seatStartNumber: 5,
        );
        expect(slot.seatLabels.length, 30);
        expect(slot.seatLabels.first, 'R05');
        expect(slot.seatLabels.last, 'R34');
      });

      test('pad length widens to 3 digits when numbers exceed 99', () {
        const slot = CustomSlot(
          id: 's1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 10,
          seatPrefix: 'B',
          seatStartNumber: 95,
        );
        // 95..104 → last number is 104 (3 digits), so pad to 3
        expect(slot.seatLabels.first, 'B095');
        expect(slot.seatLabels.last, 'B104');
      });

      test('no duplicate labels in generated list', () {
        const slot = CustomSlot(
          id: 's1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 50,
          seatPrefix: 'Z',
          seatStartNumber: 1,
        );
        final labels = slot.seatLabels;
        expect(labels.toSet().length, labels.length);
      });
    });

    group('copyWith seat numbering', () {
      const base = CustomSlot(
        id: 's1', libraryId: 'l1', name: 'M',
        startTime: 360, endTime: 840, price: 100, capacity: 10,
      );

      test('sets seatPrefix via copyWith', () {
        final updated = base.copyWith(seatPrefix: 'C');
        expect(updated.seatPrefix, 'C');
      });

      test('sets seatStartNumber via copyWith', () {
        final updated = base.copyWith(seatStartNumber: 5);
        expect(updated.seatStartNumber, 5);
      });

      test('clears seatPrefix to null via copyWith sentinel', () {
        const withPrefix = CustomSlot(
          id: 's1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 10,
          seatPrefix: 'A',
        );
        final cleared = withPrefix.copyWith(seatPrefix: null);
        expect(cleared.seatPrefix, isNull);
        // After clearing, labels fall back to default
        expect(cleared.seatLabels.first, 'S01');
      });

      test('clears seatStartNumber to null via copyWith sentinel', () {
        const withStart = CustomSlot(
          id: 's1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 5,
          seatStartNumber: 20,
        );
        final cleared = withStart.copyWith(seatStartNumber: null);
        expect(cleared.seatStartNumber, isNull);
        expect(cleared.seatLabels.first, 'S01');
      });

      test('preserves seatPrefix when not passed to copyWith', () {
        const withPrefix = CustomSlot(
          id: 's1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 10,
          seatPrefix: 'D',
        );
        final updated = withPrefix.copyWith(capacity: 5);
        expect(updated.seatPrefix, 'D');
      });

      test('props includes seatPrefix and seatStartNumber', () {
        const a = CustomSlot(
          id: 's1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 10,
          seatPrefix: 'A', seatStartNumber: 1,
        );
        const b = CustomSlot(
          id: 's1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 10,
          seatPrefix: 'B', seatStartNumber: 1,
        );
        expect(a, isNot(equals(b)));
      });
    });
  });
}
