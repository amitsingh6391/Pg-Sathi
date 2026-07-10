import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/data/failures/data_failures.dart';
import 'package:pg_manager/domain/entities/user.dart';
import 'package:pg_manager/domain/entities/user_activity_detail.dart';
import 'package:pg_manager/domain/repositories/admin_analytics_repository.dart';
import 'package:pg_manager/domain/usecases/get_user_activity_details.dart';
import 'package:mocktail/mocktail.dart';

class MockAdminAnalyticsRepository extends Mock
    implements AdminAnalyticsRepository {}

void main() {
  late GetUserActivityDetails useCase;
  late MockAdminAnalyticsRepository mockRepository;

  setUp(() {
    mockRepository = MockAdminAnalyticsRepository();
    useCase = GetUserActivityDetails(mockRepository);
  });

  group('GetUserActivityDetails', () {
    const testUserId = 'user123';
    final testStartDate = DateTime(2026, 1, 1);
    final testEndDate = DateTime(2026, 1, 31);

    final testTimeline = [
      UserActivityTimeline(
        date: DateTime(2026, 1, 19),
        sessions: [
          UserActivityDetail(
            userId: testUserId,
            userName: 'John Doe',
            role: UserRole.student,
            checkInTime: DateTime(2026, 1, 19, 9, 0),
            checkOutTime: DateTime(2026, 1, 19, 12, 0),
            libraryName: 'Central Library',
            libraryId: 'lib1',
            sessionCount: 1,
          ),
          UserActivityDetail(
            userId: testUserId,
            userName: 'John Doe',
            role: UserRole.student,
            checkInTime: DateTime(2026, 1, 19, 14, 0),
            checkOutTime: DateTime(2026, 1, 19, 18, 0),
            libraryName: 'Central Library',
            libraryId: 'lib1',
            sessionCount: 1,
          ),
        ],
        totalDuration: 420,
      ),
      UserActivityTimeline(
        date: DateTime(2026, 1, 18),
        sessions: [
          UserActivityDetail(
            userId: testUserId,
            userName: 'John Doe',
            role: UserRole.student,
            checkInTime: DateTime(2026, 1, 18, 10, 0),
            checkOutTime: DateTime(2026, 1, 18, 16, 0),
            libraryName: 'Central Library',
            libraryId: 'lib1',
            sessionCount: 1,
          ),
        ],
        totalDuration: 360,
      ),
    ];

    test('should_return_activity_timeline_when_successful', () async {
      // Arrange
      when(
        () => mockRepository.getUserActivityDetails(
          userId: any(named: 'userId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => Right(testTimeline));

      // Act
      final result = await useCase(
        userId: testUserId,
        startDate: testStartDate,
        endDate: testEndDate,
      );

      // Assert
      expect(result, Right(testTimeline));
      verify(
        () => mockRepository.getUserActivityDetails(
          userId: testUserId,
          startDate: testStartDate,
          endDate: testEndDate,
        ),
      ).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('should_return_empty_timeline_when_no_activity', () async {
      // Arrange
      when(
        () => mockRepository.getUserActivityDetails(
          userId: any(named: 'userId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => const Right(<UserActivityTimeline>[]));

      // Act
      final result = await useCase(
        userId: testUserId,
        startDate: testStartDate,
        endDate: testEndDate,
      );

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should return success'),
        (timeline) => expect(timeline, isEmpty),
      );
      verify(
        () => mockRepository.getUserActivityDetails(
          userId: testUserId,
          startDate: testStartDate,
          endDate: testEndDate,
        ),
      ).called(1);
    });

    test('should_return_failure_when_repository_fails', () async {
      // Arrange
      const failure = ServerFailure(message: 'Network error');
      when(
        () => mockRepository.getUserActivityDetails(
          userId: any(named: 'userId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(
        userId: testUserId,
        startDate: testStartDate,
        endDate: testEndDate,
      );

      // Assert
      expect(result, const Left(failure));
      verify(
        () => mockRepository.getUserActivityDetails(
          userId: testUserId,
          startDate: testStartDate,
          endDate: testEndDate,
        ),
      ).called(1);
    });

    test('should_return_validation_failure_when_userId_is_empty', () async {
      // Act
      final result = await useCase(
        userId: '',
        startDate: testStartDate,
        endDate: testEndDate,
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect(
            (failure as ValidationFailure).message,
            'User ID cannot be empty',
          );
        },
        (_) => fail('Should return failure'),
      );
      verifyZeroInteractions(mockRepository);
    });

    test('should_return_validation_failure_when_endDate_before_startDate',
        () async {
      // Arrange
      final invalidStartDate = DateTime(2026, 1, 31);
      final invalidEndDate = DateTime(2026, 1, 1);

      // Act
      final result = await useCase(
        userId: testUserId,
        startDate: invalidStartDate,
        endDate: invalidEndDate,
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect(
            (failure as ValidationFailure).message,
            'End date must be after start date',
          );
        },
        (_) => fail('Should return failure'),
      );
      verifyZeroInteractions(mockRepository);
    });

    test('should_accept_same_startDate_and_endDate', () async {
      // Arrange
      final sameDate = DateTime(2026, 1, 19);
      when(
        () => mockRepository.getUserActivityDetails(
          userId: any(named: 'userId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => const Right(<UserActivityTimeline>[]));

      // Act
      final result = await useCase(
        userId: testUserId,
        startDate: sameDate,
        endDate: sameDate,
      );

      // Assert
      expect(result.isRight(), true);
      verify(
        () => mockRepository.getUserActivityDetails(
          userId: testUserId,
          startDate: sameDate,
          endDate: sameDate,
        ),
      ).called(1);
    });
  });
}
