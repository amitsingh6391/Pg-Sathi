import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/library.dart';

void main() {
  group('Library entity', () {
    final validLibrary = Library(
      id: 'lib-1',
      ownerId: 'owner-1',
      name: 'Central Library',
      fullAddress: '123 Main Street, City',
      area: 'Downtown',
      capacity: 50,
    );

    group('validate()', () {
      test('should return valid when all required fields are filled', () {
        final result = validLibrary.validate();

        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('should return invalid when name is empty', () {
        final library = validLibrary.copyWith(name: '');
        final result = library.validate();

        expect(result.isValid, false);
        expect(result.errors, contains('Library name is required'));
      });

      test('should return invalid when name is too short', () {
        final library = validLibrary.copyWith(name: 'AB');
        final result = library.validate();

        expect(result.isValid, false);
        expect(
          result.errors,
          contains('Library name must be at least 3 characters'),
        );
      });

      test('should return invalid when fullAddress is null', () {
        final library = Library(
          id: 'lib-1',
          ownerId: 'owner-1',
          name: 'Central Library',
          fullAddress: null,
          area: 'Downtown',
          capacity: 50,
        );
        final result = library.validate();

        expect(result.isValid, false);
        expect(result.errors, contains('Full address is required'));
      });

      test('should return invalid when area is empty', () {
        final library = Library(
          id: 'lib-1',
          ownerId: 'owner-1',
          name: 'Central Library',
          fullAddress: '123 Main Street',
          area: '',
          capacity: 50,
        );
        final result = library.validate();

        expect(result.isValid, false);
        expect(result.errors, contains('Area is required'));
      });

      test('should return invalid when capacity is zero', () {
        final library = validLibrary.copyWith(capacity: 0);
        final result = library.validate();

        expect(result.isValid, false);
        expect(result.errors, contains('Total seats must be greater than 0'));
      });

      test('should return multiple errors when multiple fields invalid', () {
        final library = Library(
          id: 'lib-1',
          ownerId: 'owner-1',
          name: '',
          fullAddress: null,
          area: null,
          capacity: 0,
        );
        final result = library.validate();

        expect(result.isValid, false);
        expect(result.errors.length, greaterThan(1));
      });
    });

    group('shouldBeProfileComplete', () {
      test('should return true when all fields are valid', () {
        expect(validLibrary.shouldBeProfileComplete, true);
      });

      test('should return false when validation fails', () {
        final library = validLibrary.copyWith(name: '');
        expect(library.shouldBeProfileComplete, false);
      });
    });

    group('enabledFacilities', () {
      test('should return empty list when no facilities', () {
        final library = Library(
          id: 'lib-1',
          ownerId: 'owner-1',
          name: 'Test',
          capacity: 10,
        );

        expect(library.enabledFacilities, isEmpty);
      });

      test('should return list of enabled facilities', () {
        final library = Library(
          id: 'lib-1',
          ownerId: 'owner-1',
          name: 'Test',
          capacity: 10,
          hasWifi: true,
          hasAC: true,
          hasCCTV: true,
        );

        expect(library.enabledFacilities.length, 3);
        expect(library.enabledFacilities, contains(LibraryFacility.wifi));
        expect(library.enabledFacilities, contains(LibraryFacility.ac));
        expect(library.enabledFacilities, contains(LibraryFacility.cctv));
      });
    });

    group('markProfileComplete', () {
      test('should set isProfileComplete based on validation', () {
        final completed = validLibrary.markProfileComplete();

        expect(completed.isProfileComplete, true);
        expect(completed.updatedAt, isNotNull);
      });

      test('should set isProfileComplete to false when validation fails', () {
        final incomplete = validLibrary
            .copyWith(name: '')
            .markProfileComplete();

        expect(incomplete.isProfileComplete, false);
      });
    });
  });

  group('LibraryFacility', () {
    test('should have correct display names', () {
      expect(LibraryFacility.wifi.displayName, 'WiFi');
      expect(LibraryFacility.ac.displayName, 'AC');
      expect(LibraryFacility.powerBackup.displayName, 'Power Backup');
      expect(LibraryFacility.washroom.displayName, 'Washroom');
      expect(LibraryFacility.drinkingWater.displayName, 'Drinking Water');
      expect(LibraryFacility.cctv.displayName, 'CCTV');
    });
  });
}
