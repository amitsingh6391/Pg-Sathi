import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/pg_property.dart';

void main() {
  group('PgProperty entity', () {
    const validPg = PgProperty(
      id: 'pg-1',
      ownerId: 'owner-1',
      name: 'Green Stay PG',
      fullAddress: '123 Main Road, Bengaluru',
      area: 'BTM Layout',
      capacity: 24,
      monthlyRentFrom: 7500,
      defaultSecurityDeposit: 10000,
    );

    group('validate()', () {
      test('returns valid when required fields are filled', () {
        final result = validPg.validate();

        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('returns invalid when name is empty', () {
        final result = validPg.copyWith(name: '').validate();

        expect(result.isValid, false);
        expect(result.errors, contains('PG name is required'));
      });

      test('returns invalid when address is missing', () {
        const pg = PgProperty(
          id: 'pg-1',
          ownerId: 'owner-1',
          name: 'Green Stay PG',
          area: 'BTM Layout',
          capacity: 24,
        );

        final result = pg.validate();

        expect(result.isValid, false);
        expect(result.errors, contains('Full address is required'));
      });

      test('returns invalid when bed capacity is zero', () {
        final result = validPg.copyWith(capacity: 0).validate();

        expect(result.isValid, false);
        expect(result.errors, contains('Total beds must be greater than 0'));
      });

      test('returns invalid when rent or deposit is negative', () {
        final result = validPg
            .copyWith(monthlyRentFrom: -1, defaultSecurityDeposit: -1)
            .validate();

        expect(result.isValid, false);
        expect(result.errors, contains('Monthly rent cannot be negative'));
        expect(result.errors, contains('Security deposit cannot be negative'));
      });
    });

    test('enabledFacilities returns selected PG facilities', () {
      final pg = validPg.copyWith(
        hasWifi: true,
        hasFood: true,
        hasLaundry: true,
      );

      expect(pg.enabledFacilities, contains(PgFacility.wifi));
      expect(pg.enabledFacilities, contains(PgFacility.food));
      expect(pg.enabledFacilities, contains(PgFacility.laundry));
      expect(pg.enabledFacilities.length, 3);
    });

    test('markProfileComplete sets profile status from validation', () {
      final completed = validPg.markProfileComplete();

      expect(completed.isProfileComplete, true);
      expect(completed.updatedAt, isNotNull);
    });
  });

  group('PgFacilityExtension', () {
    test('returns display names', () {
      expect(PgFacility.wifi.displayName, 'WiFi');
      expect(PgFacility.ac.displayName, 'AC');
      expect(PgFacility.powerBackup.displayName, 'Power Backup');
      expect(PgFacility.food.displayName, 'Food');
      expect(PgFacility.laundry.displayName, 'Laundry');
      expect(PgFacility.cctv.displayName, 'CCTV');
      expect(PgFacility.parking.displayName, 'Parking');
    });
  });
}
