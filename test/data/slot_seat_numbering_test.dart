import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/data/mappers/slot_mapper.dart';
import 'package:pg_manager/data/models/slot_dto.dart';
import 'package:pg_manager/domain/entities/custom_slot.dart';

void main() {
  // ── helpers ─────────────────────────────────────────────────────────────────

  /// Creates a [SlotDto] without needing a real DocumentSnapshot by using
  /// fake_cloud_firestore to write and read back data.
  Future<SlotDto> roundTripFromFirestore({
    String? seatPrefix,
    int? seatStartNumber,
  }) async {
    final fake = FakeFirebaseFirestore();
    final data = <String, dynamic>{
      'libraryId': 'lib1',
      'name': 'Morning',
      'startTime': 360,
      'endTime': 840,
      'price': 500.0,
      'capacity': 20,
      'isActive': true,
      if (seatPrefix != null) 'seatPrefix': seatPrefix,
      if (seatStartNumber != null) 'seatStartNumber': seatStartNumber,
    };
    final ref = await fake.collection('slots').add(data);
    await ref
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data()!,
          toFirestore: (v, _) => v,
        )
        .get();

    // Re-read as a raw DocumentSnapshot to feed into SlotDto.fromFirestore
    final rawSnap = await fake
        .collection('slots')
        .doc(ref.id)
        .get() as dynamic;
    return SlotDto.fromFirestore(rawSnap);
  }

  // ── SlotDto ──────────────────────────────────────────────────────────────────

  group('SlotDto', () {
    group('fromFirestore – seat numbering fields', () {
      test('returns null seatPrefix when field absent (existing doc)', () async {
        final dto = await roundTripFromFirestore();
        expect(dto.seatPrefix, isNull);
        expect(dto.seatStartNumber, isNull);
      });

      test('reads seatPrefix from Firestore', () async {
        final dto = await roundTripFromFirestore(seatPrefix: 'A');
        expect(dto.seatPrefix, 'A');
      });

      test('reads seatStartNumber from Firestore', () async {
        final dto = await roundTripFromFirestore(seatStartNumber: 20);
        expect(dto.seatStartNumber, 20);
      });

      test('reads both seatPrefix and seatStartNumber', () async {
        final dto =
            await roundTripFromFirestore(seatPrefix: 'B', seatStartNumber: 5);
        expect(dto.seatPrefix, 'B');
        expect(dto.seatStartNumber, 5);
      });
    });

    group('toFirestore – seat numbering fields', () {
      test('omits seatPrefix when null', () {
        const dto = SlotDto(
          id: 'd1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 10,
        );
        final map = dto.toFirestore();
        expect(map.containsKey('seatPrefix'), isFalse);
      });

      test('omits seatPrefix when empty string', () {
        const dto = SlotDto(
          id: 'd1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 10,
          seatPrefix: '',
        );
        final map = dto.toFirestore();
        expect(map.containsKey('seatPrefix'), isFalse);
      });

      test('omits seatStartNumber when null', () {
        const dto = SlotDto(
          id: 'd1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 10,
        );
        final map = dto.toFirestore();
        expect(map.containsKey('seatStartNumber'), isFalse);
      });

      test('omits seatStartNumber when 0', () {
        const dto = SlotDto(
          id: 'd1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 10,
          seatStartNumber: 0,
        );
        final map = dto.toFirestore();
        expect(map.containsKey('seatStartNumber'), isFalse);
      });

      test('writes seatPrefix when provided', () {
        const dto = SlotDto(
          id: 'd1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 10,
          seatPrefix: 'C',
        );
        final map = dto.toFirestore();
        expect(map['seatPrefix'], 'C');
      });

      test('writes seatStartNumber when provided', () {
        const dto = SlotDto(
          id: 'd1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 10,
          seatStartNumber: 15,
        );
        final map = dto.toFirestore();
        expect(map['seatStartNumber'], 15);
      });

      test('existing core fields are always present', () {
        const dto = SlotDto(
          id: 'd1', libraryId: 'l1', name: 'Morning',
          startTime: 360, endTime: 840, price: 500, capacity: 20,
          seatPrefix: 'A', seatStartNumber: 10,
        );
        final map = dto.toFirestore();
        expect(map['libraryId'], 'l1');
        expect(map['name'], 'Morning');
        expect(map['startTime'], 360);
        expect(map['endTime'], 840);
        expect(map['price'], 500.0);
        expect(map['capacity'], 20);
      });
    });
  });

  // ── SlotMapper ───────────────────────────────────────────────────────────────

  group('SlotMapper', () {
    group('toEntity', () {
      test('maps null seat fields to null on entity', () {
        const dto = SlotDto(
          id: 'd1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 10,
        );
        final entity = SlotMapper.toEntity(dto);
        expect(entity.seatPrefix, isNull);
        expect(entity.seatStartNumber, isNull);
      });

      test('maps seatPrefix to entity', () {
        const dto = SlotDto(
          id: 'd1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 10,
          seatPrefix: 'A',
        );
        final entity = SlotMapper.toEntity(dto);
        expect(entity.seatPrefix, 'A');
      });

      test('maps seatStartNumber to entity', () {
        const dto = SlotDto(
          id: 'd1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 10,
          seatStartNumber: 20,
        );
        final entity = SlotMapper.toEntity(dto);
        expect(entity.seatStartNumber, 20);
      });

      test('entity seatLabels are correct after mapping', () {
        const dto = SlotDto(
          id: 'd1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 5,
          seatPrefix: 'A',
          seatStartNumber: 20,
        );
        final entity = SlotMapper.toEntity(dto);
        expect(entity.seatLabels, ['A20', 'A21', 'A22', 'A23', 'A24']);
      });
    });

    group('toDto', () {
      test('maps null seat fields from entity to dto', () {
        const entity = CustomSlot(
          id: 's1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 10,
        );
        final dto = SlotMapper.toDto(entity);
        expect(dto.seatPrefix, isNull);
        expect(dto.seatStartNumber, isNull);
      });

      test('maps seatPrefix from entity to dto', () {
        const entity = CustomSlot(
          id: 's1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 10,
          seatPrefix: 'B',
        );
        final dto = SlotMapper.toDto(entity);
        expect(dto.seatPrefix, 'B');
      });

      test('maps seatStartNumber from entity to dto', () {
        const entity = CustomSlot(
          id: 's1', libraryId: 'l1', name: 'M',
          startTime: 360, endTime: 840, price: 100, capacity: 10,
          seatStartNumber: 7,
        );
        final dto = SlotMapper.toDto(entity);
        expect(dto.seatStartNumber, 7);
      });
    });

    group('round-trip entity → dto → entity', () {
      test('preserves seat numbering fields', () {
        const original = CustomSlot(
          id: 's1', libraryId: 'l1', name: 'Afternoon',
          startTime: 840, endTime: 1320, price: 600, capacity: 15,
          seatPrefix: 'R',
          seatStartNumber: 10,
        );
        final dto = SlotMapper.toDto(original);
        final restored = SlotMapper.toEntity(dto);

        expect(restored.seatPrefix, original.seatPrefix);
        expect(restored.seatStartNumber, original.seatStartNumber);
        expect(restored.seatLabels, original.seatLabels);
      });

      test('round-trip with null seat fields produces default labels', () {
        const original = CustomSlot(
          id: 's1', libraryId: 'l1', name: 'Morning',
          startTime: 360, endTime: 840, price: 500, capacity: 5,
        );
        final restored = SlotMapper.toEntity(SlotMapper.toDto(original));
        expect(restored.seatLabels, ['S01', 'S02', 'S03', 'S04', 'S05']);
      });
    });
  });
}
