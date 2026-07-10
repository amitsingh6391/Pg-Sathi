import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/attendance.dart';
import 'package:pg_manager/domain/entities/library.dart';
import 'package:pg_manager/domain/entities/membership.dart';
import 'package:pg_manager/domain/entities/slot.dart';
import 'package:pg_manager/domain/failures/attendance_failures.dart';
import 'package:pg_manager/domain/repositories/attendance_repository.dart';
import 'package:pg_manager/domain/repositories/library_repository.dart';
import 'package:pg_manager/domain/repositories/membership_repository.dart';
import 'package:pg_manager/domain/services/location_service.dart';
import 'package:pg_manager/domain/usecases/check_in.dart';
import 'package:mocktail/mocktail.dart';

class MockAttendanceRepository extends Mock implements AttendanceRepository {}

class MockMembershipRepository extends Mock implements MembershipRepository {}

class MockLibraryRepository extends Mock implements LibraryRepository {}

class MockLocationService extends Mock implements LocationService {}

class FakeAttendance extends Fake implements Attendance {}

void main() {
  setUpAll(() {
    registerFallbackValue(Slot.morning);
    registerFallbackValue(FakeAttendance());
  });
  late CheckIn useCase;
  late MockAttendanceRepository mockAttendanceRepository;
  late MockMembershipRepository mockMembershipRepository;
  late MockLibraryRepository mockLibraryRepository;
  late MockLocationService mockLocationService;

  setUp(() {
    mockAttendanceRepository = MockAttendanceRepository();
    mockMembershipRepository = MockMembershipRepository();
    mockLibraryRepository = MockLibraryRepository();
    mockLocationService = MockLocationService();

    useCase = CheckIn(
      attendanceRepository: mockAttendanceRepository,
      membershipRepository: mockMembershipRepository,
      libraryRepository: mockLibraryRepository,
      locationService: mockLocationService,
    );
  });

  final testMembership = Membership(
    id: 'membership-1',
    userId: 'user-1',
    libraryId: 'library-1',
    plan: MembershipPlan.monthly,
    startDate: DateTime.now().subtract(const Duration(days: 5)),
    endDate: DateTime.now().add(const Duration(days: 25)),
    status: MembershipStatus.active,
    phoneNumber: '+919876543210',
    assignedSeatId: 'S01',
    slot: Slot.morning,
  );

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

  final testParams = CheckInParams(
    attendanceId: 'attendance-1',
    userId: 'user-1',
    libraryId: 'library-1',
    slot: Slot.morning,
    checkInTime: DateTime.now(),
  );

  group('CheckIn', () {
    test(
      'should return failure when no active membership found for slot',
      () async {
        // Arrange
        when(
          () =>
              mockMembershipRepository.getActiveMembershipByUserLibraryAndSlot(
                userId: any(named: 'userId'),
                libraryId: any(named: 'libraryId'),
                slot: any(named: 'slot'),
              ),
        ).thenAnswer((_) async => const Right(null));

        // V2: Also mock the fallback call to getActiveMembershipByUserAndLibrary
        when(
          () => mockMembershipRepository.getActiveMembershipByUserAndLibrary(
            userId: any(named: 'userId'),
            libraryId: any(named: 'libraryId'),
          ),
        ).thenAnswer((_) async => const Right(null));

        // Act
        final result = await useCase(testParams);

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) =>
              expect(failure, isA<NoActiveMembershipForAttendanceFailure>()),
          (_) => fail('Expected failure'),
        );
      },
    );

    test('should return failure when already checked in', () async {
      // Arrange
      when(
        () => mockMembershipRepository.getActiveMembershipByUserLibraryAndSlot(
          userId: any(named: 'userId'),
          libraryId: any(named: 'libraryId'),
          slot: any(named: 'slot'),
        ),
      ).thenAnswer((_) async => Right(testMembership));

      final existingAttendance = Attendance(
        id: 'existing',
        userId: 'user-1',
        libraryId: 'library-1',
        seatId: 'S01',
        slot: Slot.morning,
        date: '2024-01-15',
        status: AttendanceStatus.checkedIn,
        checkInTime: DateTime.now(),
      );

      when(
        () => mockAttendanceRepository.getTodayAttendance(
          userId: any(named: 'userId'),
          libraryId: any(named: 'libraryId'),
          slot: any(named: 'slot'),
          date: any(named: 'date'),
        ),
      ).thenAnswer((_) async => Right(existingAttendance));

      // Act
      final result = await useCase(testParams);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<AlreadyCheckedInForSlotFailure>()),
        (_) => fail('Expected failure'),
      );
    });

    // V2: After checkout, user CAN check in again (this is the new behavior)
    // This test now verifies that V2 allows re-check-in after checkout
    test(
      'V2: should allow check-in again after checkout (multi-session)',
      () async {
        // Arrange
        when(
          () =>
              mockMembershipRepository.getActiveMembershipByUserLibraryAndSlot(
                userId: any(named: 'userId'),
                libraryId: any(named: 'libraryId'),
                slot: any(named: 'slot'),
              ),
        ).thenAnswer((_) async => Right(testMembership));

        final completedAttendance = Attendance(
          id: 'completed',
          userId: 'user-1',
          libraryId: 'library-1',
          seatId: 'S01',
          slot: Slot.morning,
          date: '2024-01-15',
          status: AttendanceStatus.checkedOut,
          checkInTime: DateTime.now().subtract(const Duration(hours: 2)),
          checkOutTime: DateTime.now(),
        );

        when(
          () => mockAttendanceRepository.getTodayAttendance(
            userId: any(named: 'userId'),
            libraryId: any(named: 'libraryId'),
            slot: any(named: 'slot'),
            date: any(named: 'date'),
          ),
        ).thenAnswer((_) async => Right(completedAttendance));

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
              distanceInMeters: 50.0,
              userLocation: const UserLocation(
                latitude: 12.97,
                longitude: 77.59,
              ),
            ),
          ),
        );

        when(
          () => mockAttendanceRepository.addSession(
            attendanceId: any(named: 'attendanceId'),
            sessionId: any(named: 'sessionId'),
            distanceFromLibrary: any(named: 'distanceFromLibrary'),
          ),
        ).thenAnswer((_) async {
          // Return updated attendance with new session
          return Right(
            completedAttendance.copyWith(status: AttendanceStatus.checkedIn),
          );
        });

        // Act
        final result = await useCase(testParams);

        // Assert - V2: Check-in should succeed after checkout
        expect(result.isRight(), true);
        result.fold(
          (failure) =>
              fail('Expected success but got failure: ${failure.message}'),
          (attendance) {
            expect(attendance.status, AttendanceStatus.checkedIn);
          },
        );
      },
    );

    test('should return failure when out of range', () async {
      // Arrange
      when(
        () => mockMembershipRepository.getActiveMembershipByUserLibraryAndSlot(
          userId: any(named: 'userId'),
          libraryId: any(named: 'libraryId'),
          slot: any(named: 'slot'),
        ),
      ).thenAnswer((_) async => Right(testMembership));

      when(
        () => mockAttendanceRepository.getTodayAttendance(
          userId: any(named: 'userId'),
          libraryId: any(named: 'libraryId'),
          slot: any(named: 'slot'),
          date: any(named: 'date'),
        ),
      ).thenAnswer((_) async => const Right(null));

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
            distanceInMeters: 250.0,
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

    test('should return attendance when all validations pass', () async {
      // Arrange
      when(
        () => mockMembershipRepository.getActiveMembershipByUserLibraryAndSlot(
          userId: any(named: 'userId'),
          libraryId: any(named: 'libraryId'),
          slot: any(named: 'slot'),
        ),
      ).thenAnswer((_) async => Right(testMembership));

      when(
        () => mockAttendanceRepository.getTodayAttendance(
          userId: any(named: 'userId'),
          libraryId: any(named: 'libraryId'),
          slot: any(named: 'slot'),
          date: any(named: 'date'),
        ),
      ).thenAnswer((_) async => const Right(null));

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
            distanceInMeters: 50.0,
            userLocation: const UserLocation(latitude: 12.97, longitude: 77.59),
          ),
        ),
      );

      when(() => mockAttendanceRepository.checkIn(any())).thenAnswer((
        invocation,
      ) async {
        final attendance = invocation.positionalArguments[0] as Attendance;
        return Right(attendance);
      });

      // Act
      final result = await useCase(testParams);

      // Assert
      expect(result.isRight(), true);
      result.fold((failure) => fail('Expected success'), (attendance) {
        expect(attendance.userId, 'user-1');
        expect(attendance.libraryId, 'library-1');
        expect(attendance.slot, Slot.morning);
        expect(attendance.status, AttendanceStatus.checkedIn);
      });
    });

    test(
      'should allow check-in for evening slot when user has both memberships',
      () async {
        // Arrange - User has evening membership, checking in for evening
        final eveningMembership = testMembership.copyWith(slot: Slot.evening);
        final eveningParams = CheckInParams(
          attendanceId: 'attendance-2',
          userId: 'user-1',
          libraryId: 'library-1',
          slot: Slot.evening,
          checkInTime: DateTime.now(),
        );

        // This should return the evening membership when querying for evening slot
        when(
          () =>
              mockMembershipRepository.getActiveMembershipByUserLibraryAndSlot(
                userId: any(named: 'userId'),
                libraryId: any(named: 'libraryId'),
                slot: any(named: 'slot'),
              ),
        ).thenAnswer((_) async => Right(eveningMembership));

        when(
          () => mockAttendanceRepository.getTodayAttendance(
            userId: any(named: 'userId'),
            libraryId: any(named: 'libraryId'),
            slot: any(named: 'slot'),
            date: any(named: 'date'),
          ),
        ).thenAnswer((_) async => const Right(null));

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
              distanceInMeters: 50.0,
              userLocation: const UserLocation(
                latitude: 12.97,
                longitude: 77.59,
              ),
            ),
          ),
        );

        when(() => mockAttendanceRepository.checkIn(any())).thenAnswer((
          invocation,
        ) async {
          final attendance = invocation.positionalArguments[0] as Attendance;
          return Right(attendance);
        });

        // Act
        final result = await useCase(eveningParams);

        // Assert
        expect(result.isRight(), true);
        result.fold((failure) => fail('Expected success'), (attendance) {
          expect(attendance.userId, 'user-1');
          expect(attendance.libraryId, 'library-1');
          expect(attendance.slot, Slot.evening);
          expect(attendance.status, AttendanceStatus.checkedIn);
        });
      },
    );
  });
}
