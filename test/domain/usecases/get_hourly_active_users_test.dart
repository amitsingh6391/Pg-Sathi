import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/data/failures/data_failures.dart';
import 'package:pg_manager/domain/entities/user.dart';
import 'package:pg_manager/domain/entities/user_activity_detail.dart';
import 'package:pg_manager/domain/repositories/admin_analytics_repository.dart';
import 'package:pg_manager/domain/usecases/get_hourly_active_users.dart';
import 'package:mocktail/mocktail.dart';

class MockAdminAnalyticsRepository extends Mock
    implements AdminAnalyticsRepository {}

void main() {
  late GetHourlyActiveUsers useCase;
  late MockAdminAnalyticsRepository mockRepository;

  setUp(() {
    mockRepository = MockAdminAnalyticsRepository();
    useCase = GetHourlyActiveUsers(mockRepository);
  });

  group('GetHourlyActiveUsers', () {
    final testDate = DateTime(2026, 1, 19);
    const testHour = 10;

    final testUsers = [
      UserActivityDetail(
        userId: 'user1',
        userName: 'John Doe',
        role: UserRole.student,
        checkInTime: DateTime(2026, 1, 19, 10, 15),
        checkOutTime: DateTime(2026, 1, 19, 11, 30),
        libraryName: 'Central Library',
        libraryId: 'lib1',
        sessionCount: 1,
      ),
      UserActivityDetail(
        userId: 'user2',
        userName: 'Jane Smith',
        role: UserRole.student,
        checkInTime: DateTime(2026, 1, 19, 10, 45),
        libraryName: 'East Library',
        libraryId: 'lib2',
        sessionCount: 2,
      ),
    ];

    test('should_return_list_of_active_users_when_successful', () async {
      // Arrange
      when(
        () => mockRepository.getHourlyActiveUsers(
          date: any(named: 'date'),
          hour: any(named: 'hour'),
        ),
      ).thenAnswer((_) async => Right(testUsers));

      // Act
      final result = await useCase(date: testDate, hour: testHour);

      // Assert
      expect(result, Right(testUsers));
      verify(
        () => mockRepository.getHourlyActiveUsers(
          date: testDate,
          hour: testHour,
        ),
      ).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('should_return_empty_list_when_no_users_active', () async {
      // Arrange
      when(
        () => mockRepository.getHourlyActiveUsers(
          date: any(named: 'date'),
          hour: any(named: 'hour'),
        ),
      ).thenAnswer((_) async => const Right(<UserActivityDetail>[]));

      // Act
      final result = await useCase(date: testDate, hour: testHour);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should return success'),
        (users) => expect(users, isEmpty),
      );
      verify(
        () => mockRepository.getHourlyActiveUsers(
          date: testDate,
          hour: testHour,
        ),
      ).called(1);
    });

    test('should_return_failure_when_repository_fails', () async {
      // Arrange
      const failure = ServerFailure(message: 'Database connection failed');
      when(
        () => mockRepository.getHourlyActiveUsers(
          date: any(named: 'date'),
          hour: any(named: 'hour'),
        ),
      ).thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(date: testDate, hour: testHour);

      // Assert
      expect(result, const Left(failure));
      verify(
        () => mockRepository.getHourlyActiveUsers(
          date: testDate,
          hour: testHour,
        ),
      ).called(1);
    });

    test('should_return_validation_failure_when_hour_is_negative', () async {
      // Act
      final result = await useCase(date: testDate, hour: -1);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect(
            (failure as ValidationFailure).message,
            'Hour must be between 0 and 23',
          );
        },
        (_) => fail('Should return failure'),
      );
      verifyZeroInteractions(mockRepository);
    });

    test('should_return_validation_failure_when_hour_is_greater_than_23',
        () async {
      // Act
      final result = await useCase(date: testDate, hour: 24);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect(
            (failure as ValidationFailure).message,
            'Hour must be between 0 and 23',
          );
        },
        (_) => fail('Should return failure'),
      );
      verifyZeroInteractions(mockRepository);
    });

    test('should_accept_hour_0_as_valid', () async {
      // Arrange
      when(
        () => mockRepository.getHourlyActiveUsers(
          date: any(named: 'date'),
          hour: any(named: 'hour'),
        ),
      ).thenAnswer((_) async => const Right(<UserActivityDetail>[]));

      // Act
      final result = await useCase(date: testDate, hour: 0);

      // Assert
      expect(result.isRight(), true);
      verify(
        () => mockRepository.getHourlyActiveUsers(
          date: testDate,
          hour: 0,
        ),
      ).called(1);
    });

    test('should_accept_hour_23_as_valid', () async {
      // Arrange
      when(
        () => mockRepository.getHourlyActiveUsers(
          date: any(named: 'date'),
          hour: any(named: 'hour'),
        ),
      ).thenAnswer((_) async => const Right(<UserActivityDetail>[]));

      // Act
      final result = await useCase(date: testDate, hour: 23);

      // Assert
      expect(result.isRight(), true);
      verify(
        () => mockRepository.getHourlyActiveUsers(
          date: testDate,
          hour: 23,
        ),
      ).called(1);
    });
  });
}
