import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/attendance.dart';
import 'package:pg_manager/domain/entities/slot.dart';

void main() {
  group('Attendance', () {
    test('factory checkIn creates correct attendance', () {
      final attendance = Attendance.checkIn(
        id: 'att-1',
        userId: 'user-1',
        libraryId: 'lib-1',
        seatId: 'S01',
        slot: Slot.morning,
        date: '2024-01-15',
        distanceFromLibrary: 45.5,
      );

      expect(attendance.id, 'att-1');
      expect(attendance.userId, 'user-1');
      expect(attendance.libraryId, 'lib-1');
      expect(attendance.seatId, 'S01');
      expect(attendance.slot, Slot.morning);
      expect(attendance.date, '2024-01-15');
      expect(attendance.status, AttendanceStatus.checkedIn);
      expect(attendance.checkInDistance, 45.5);
      expect(attendance.checkInTime, isNotNull);
      expect(attendance.isCheckedIn, true);
      expect(attendance.isCheckedOut, false);
    });

    test('checkOut updates status and time', () {
      final attendance = Attendance.checkIn(
        id: 'att-1',
        userId: 'user-1',
        libraryId: 'lib-1',
        seatId: 'S01',
        slot: Slot.morning,
        date: '2024-01-15',
        distanceFromLibrary: 45.5,
      );

      final checkedOut = attendance.checkOut(distanceFromLibrary: 50.0);

      expect(checkedOut.status, AttendanceStatus.checkedOut);
      expect(checkedOut.checkOutTime, isNotNull);
      expect(checkedOut.checkOutDistance, 50.0);
      expect(checkedOut.isCheckedIn, false);
      expect(checkedOut.isCheckedOut, true);
    });

    test('sessionDurationMinutes calculates correctly', () {
      final checkInTime = DateTime(2024, 1, 15, 9, 0);
      final checkOutTime = DateTime(2024, 1, 15, 12, 30);

      final attendance = Attendance(
        id: 'att-1',
        userId: 'user-1',
        libraryId: 'lib-1',
        seatId: 'S01',
        slot: Slot.morning,
        date: '2024-01-15',
        status: AttendanceStatus.checkedOut,
        checkInTime: checkInTime,
        checkOutTime: checkOutTime,
      );

      expect(attendance.sessionDurationMinutes, 210); // 3.5 hours
    });

    test('formattedDuration formats correctly', () {
      final checkInTime = DateTime(2024, 1, 15, 9, 0);
      final checkOutTime = DateTime(2024, 1, 15, 12, 30);

      final attendance = Attendance(
        id: 'att-1',
        userId: 'user-1',
        libraryId: 'lib-1',
        seatId: 'S01',
        slot: Slot.morning,
        date: '2024-01-15',
        status: AttendanceStatus.checkedOut,
        checkInTime: checkInTime,
        checkOutTime: checkOutTime,
      );

      expect(attendance.formattedDuration, '3h 30m');
    });

    test('formattedDuration handles minutes only', () {
      final checkInTime = DateTime(2024, 1, 15, 9, 0);
      final checkOutTime = DateTime(2024, 1, 15, 9, 45);

      final attendance = Attendance(
        id: 'att-1',
        userId: 'user-1',
        libraryId: 'lib-1',
        seatId: 'S01',
        slot: Slot.morning,
        date: '2024-01-15',
        status: AttendanceStatus.checkedOut,
        checkInTime: checkInTime,
        checkOutTime: checkOutTime,
      );

      expect(attendance.formattedDuration, '45m');
    });
  });

  group('LocationValidationResult', () {
    test('valid creates correct result', () {
      final result = LocationValidationResult.valid(45.0);

      expect(result.isValid, true);
      expect(result.distanceInMeters, 45.0);
      expect(result.errorMessage, isNull);
    });

    test('outOfRange creates correct result', () {
      final result = LocationValidationResult.outOfRange(250.0);

      expect(result.isValid, false);
      expect(result.distanceInMeters, 250.0);
      expect(result.errorMessage, contains('250m away'));
    });

    test('permissionDenied creates correct result', () {
      final result = LocationValidationResult.permissionDenied();

      expect(result.isValid, false);
      expect(result.distanceInMeters, -1);
      expect(result.errorMessage, contains('permission denied'));
    });

    test('serviceDisabled creates correct result', () {
      final result = LocationValidationResult.serviceDisabled();

      expect(result.isValid, false);
      expect(result.distanceInMeters, -1);
      expect(result.errorMessage, contains('disabled'));
    });

    test('libraryLocationMissing creates correct result', () {
      final result = LocationValidationResult.libraryLocationMissing();

      expect(result.isValid, false);
      expect(result.distanceInMeters, -1);
      expect(result.errorMessage, contains('not configured'));
    });
  });

  group('AttendanceStatus', () {
    test('fromString parses correctly', () {
      expect(
        AttendanceStatus.fromString('checkedIn'),
        AttendanceStatus.checkedIn,
      );
      expect(
        AttendanceStatus.fromString('checkedOut'),
        AttendanceStatus.checkedOut,
      );
      expect(
        AttendanceStatus.fromString('CHECKEDIN'),
        AttendanceStatus.checkedIn,
      );
      // Invalid values return AttendanceStatus.none as fallback
      expect(AttendanceStatus.fromString('invalid'), AttendanceStatus.none);
      expect(AttendanceStatus.fromString(null), AttendanceStatus.none);
    });

    test('displayName returns correct values', () {
      expect(AttendanceStatus.checkedIn.displayName, 'Checked In');
      expect(AttendanceStatus.checkedOut.displayName, 'Checked Out');
    });

    test('shortName returns correct values', () {
      expect(AttendanceStatus.checkedIn.shortName, 'IN');
      expect(AttendanceStatus.checkedOut.shortName, 'OUT');
    });
  });
}
