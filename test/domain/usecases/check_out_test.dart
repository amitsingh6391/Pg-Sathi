import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/attendance.dart';
import 'package:pg_manager/domain/entities/library.dart';
import 'package:pg_manager/domain/entities/slot.dart';
import 'package:pg_manager/domain/failures/attendance_failures.dart';
import 'package:pg_manager/domain/repositories/attendance_repository.dart';
import 'package:pg_manager/domain/repositories/library_repository.dart';
import 'package:pg_manager/domain/services/location_service.dart';
import 'package:pg_manager/domain/usecases/check_out.dart';
import 'package:mocktail/mocktail.dart';

class MockAttendanceRepository extends Mock implements AttendanceRepository {}

class MockLibraryRepository extends Mock implements LibraryRepository {}

class MockLocationService extends Mock implements LocationService {}

void main() {
  setUpAll(() {
    registerFallbackValue(Slot.morning);
  });
  late CheckOut useCase;
  late MockAttendanceRepository mockAttendanceRepository;
  late MockLibraryRepository mockLibraryRepository;
  late MockLocationService mockLocationService;

  setUp(() {
    mockAttendanceRepository = MockAttendanceRepository();
    mockLibraryRepository = MockLibraryRepository();
    mockLocationService = MockLocationService();

    useCase = CheckOut(
      attendanceRepository: mockAttendanceRepository,
      libraryRepository: mockLibraryRepository,
      locationService: mockLocationService,
    );
  });

  final testLibrary = Library(
    id: 'library-1',
    ownerId: 'owner-1',
    name: 'Test Library',
    fullAddress: '123 Test Street',
    area: 'Test Area',
    latitude: 12.9716,
    longitude: 77.5946,
    capacity: 100,
    isProfileComplete: true,
    createdAt: DateTime.now(),
  );

  final checkedInAttendance = Attendance(
    id: 'attendance-1',
    userId: 'user-1',
    libraryId: 'library-1',
    seatId: 'S01',
    slot: Slot.morning,
    date: '2024-01-15',
    status: AttendanceStatus.checkedIn,
    checkInTime: DateTime.now().subtract(const Duration(hours: 2)),
    checkInDistance: 45.0,
  );

  final testParams = CheckOutParams(
    userId: 'user-1',
    libraryId: 'library-1',
    slot: Slot.morning,
    checkOutTime: DateTime.now(),
  );

  group('CheckOut', () {
    test(
      'should return failure when not checked in (no attendance record)',
      () async {
        // Arrange
        when(
          () => mockAttendanceRepository.getTodayAttendance(
            userId: any(named: 'userId'),
            libraryId: any(named: 'libraryId'),
            slot: any(named: 'slot'),
            date: any(named: 'date'),
          ),
        ).thenAnswer((_) async => const Right(null));

        // Act
        final result = await useCase(testParams);

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) => expect(failure, isA<NotCheckedInFailure>()),
          (_) => fail('Expected failure'),
        );
      },
    );

    test('should return failure when already checked out', () async {
      // Arrange
      final alreadyCheckedOutAttendance = Attendance(
        id: 'attendance-1',
        userId: 'user-1',
        libraryId: 'library-1',
        seatId: 'S01',
        slot: Slot.morning,
        date: '2024-01-15',
        status: AttendanceStatus.checkedOut,
        checkInTime: DateTime.now().subtract(const Duration(hours: 2)),
        checkOutTime: DateTime.now().subtract(const Duration(hours: 1)),
        checkInDistance: 45.0,
        checkOutDistance: 50.0,
      );

      when(
        () => mockAttendanceRepository.getTodayAttendance(
          userId: any(named: 'userId'),
          libraryId: any(named: 'libraryId'),
          slot: any(named: 'slot'),
          date: any(named: 'date'),
        ),
      ).thenAnswer((_) async => Right(alreadyCheckedOutAttendance));

      // Act
      final result = await useCase(testParams);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<NotCheckedInFailure>()),
        (_) => fail('Expected failure'),
      );
    });

    test('should return failure when out of range', () async {
      // Arrange
      when(
        () => mockAttendanceRepository.getTodayAttendance(
          userId: any(named: 'userId'),
          libraryId: any(named: 'libraryId'),
          slot: any(named: 'slot'),
          date: any(named: 'date'),
        ),
      ).thenAnswer((_) async => Right(checkedInAttendance));

      when(
        () => mockLibraryRepository.getLibraryById(any()),
      ).thenAnswer((_) async => Right(testLibrary));

      when(
        () => mockLocationService.validateUserLocation(
          libraryLat: any(named: 'libraryLat'),
          libraryLon: any(named: 'libraryLon'),
          maxDistanceMeters: any(named: 'maxDistanceMeters'),
        ),
      ).thenAnswer(
        (_) async => Right(
          LocationValidation(
            isWithinRange: false,
            distanceInMeters: 300.0,
            userLocation: const UserLocation(latitude: 12.97, longitude: 77.59),
          ),
        ),
      );

      // Act
      final result = await useCase(testParams);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<OutOfRangeFailure>()),
        (_) => fail('Expected failure'),
      );
    });

    test('should return attendance when checkout successful', () async {
      // Arrange
      when(
        () => mockAttendanceRepository.getTodayAttendance(
          userId: any(named: 'userId'),
          libraryId: any(named: 'libraryId'),
          slot: any(named: 'slot'),
          date: any(named: 'date'),
        ),
      ).thenAnswer((_) async => Right(checkedInAttendance));

      when(
        () => mockLibraryRepository.getLibraryById(any()),
      ).thenAnswer((_) async => Right(testLibrary));

      when(
        () => mockLocationService.validateUserLocation(
          libraryLat: any(named: 'libraryLat'),
          libraryLon: any(named: 'libraryLon'),
          maxDistanceMeters: any(named: 'maxDistanceMeters'),
        ),
      ).thenAnswer(
        (_) async => Right(
          LocationValidation(
            isWithinRange: true,
            distanceInMeters: 40.0,
            userLocation: const UserLocation(latitude: 12.97, longitude: 77.59),
          ),
        ),
      );

      final checkedOutAttendance = checkedInAttendance.checkOut(
        distanceFromLibrary: 40.0,
      );

      when(
        () => mockAttendanceRepository.checkOut(
          attendanceId: any(named: 'attendanceId'),
          distanceFromLibrary: any(named: 'distanceFromLibrary'),
        ),
      ).thenAnswer((_) async => Right(checkedOutAttendance));

      // Act
      final result = await useCase(testParams);

      // Assert
      expect(result.isRight(), true);
      result.fold((failure) => fail('Expected success'), (attendance) {
        expect(attendance.status, AttendanceStatus.checkedOut);
        expect(attendance.checkOutTime, isNotNull);
      });
    });
  });
}
