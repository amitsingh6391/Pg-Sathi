import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/pg_room.dart';

void main() {
  group('PgRoom entity', () {
    const room = PgRoom(
      id: 'room-1',
      pgPropertyId: 'pg-1',
      roomNumber: '101',
      bedCount: 3,
      floor: '1',
      roomType: PgRoomType.triple,
      monthlyRentPerBed: 8500,
    );

    test('hasValidBedCount is true when bed count is positive', () {
      expect(room.hasValidBedCount, true);
    });

    test('hasValidBedCount is false when bed count is zero', () {
      expect(room.copyWith(bedCount: 0).hasValidBedCount, false);
    });

    test('deactivate and activate update active state', () {
      final inactive = room.deactivate();
      final active = inactive.activate();

      expect(inactive.isActive, false);
      expect(active.isActive, true);
    });
  });

  group('PgRoomTypeExtension', () {
    test('returns display names', () {
      expect(PgRoomType.single.displayName, 'Single');
      expect(PgRoomType.double.displayName, 'Double Sharing');
      expect(PgRoomType.triple.displayName, 'Triple Sharing');
      expect(PgRoomType.fourSharing.displayName, 'Four Sharing');
      expect(PgRoomType.shared.displayName, 'Shared');
    });
  });
}
