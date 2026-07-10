import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:pg_manager/domain/core/failure.dart';
import 'package:pg_manager/domain/entities/invoice.dart';
import 'package:pg_manager/domain/entities/slot.dart';
import 'package:pg_manager/domain/repositories/admin_analytics_repository.dart';
import 'package:pg_manager/domain/usecases/get_admin_invoices.dart';

class MockAdminAnalyticsRepository extends Mock
    implements AdminAnalyticsRepository {}

void main() {
  late GetAdminInvoices useCase;
  late MockAdminAnalyticsRepository mockRepository;

  setUp(() {
    mockRepository = MockAdminAnalyticsRepository();
    useCase = GetAdminInvoices(repository: mockRepository);
  });

  group('GetAdminInvoices', () {
    final tInvoices = [
      Invoice(
        id: 'inv-1',
        invoiceNumber: 'INV-2024-000001',
        libraryId: 'lib-1',
        libraryName: 'Test Library',
        libraryAddress: '123 Test Street',
        ownerId: 'owner-1',
        ownerName: 'Test Owner',
        ownerContact: '9876543210',
        studentId: 'student-1',
        studentName: 'Test Student',
        studentPhone: '9876543211',
        membershipId: 'member-1',
        seatNumber: 'A1',
        slot: Slot.morning,
        sessionTiming: '6:00 AM - 12:00 PM',
        billingMonth: '2024-01',
        amountPaid: 2000,
        currency: 'INR',
        paymentId: 'pay-1',
        paymentDate: DateTime(2024, 1, 15),
        generatedAt: DateTime(2024, 1, 15),
        expiryDate: DateTime(2024, 2, 14),
      ),
    ];

    test('should_return_all_invoices_when_no_filters', () async {
      // Arrange
      when(
        () => mockRepository.getInvoices(
          libraryId: null,
          ownerId: null,
          startDate: null,
          endDate: null,
        ),
      ).thenAnswer((_) async => Right(tInvoices));

      // Act
      final result = await useCase(const GetAdminInvoicesParams());

      // Assert
      expect(result, Right(tInvoices));
      verify(
        () => mockRepository.getInvoices(
          libraryId: null,
          ownerId: null,
          startDate: null,
          endDate: null,
        ),
      ).called(1);
    });

    test('should_filter_invoices_by_library_id', () async {
      // Arrange
      when(
        () => mockRepository.getInvoices(
          libraryId: 'lib-1',
          ownerId: null,
          startDate: null,
          endDate: null,
        ),
      ).thenAnswer((_) async => Right(tInvoices));

      // Act
      final result = await useCase(
        const GetAdminInvoicesParams(libraryId: 'lib-1'),
      );

      // Assert
      expect(result, Right(tInvoices));
      verify(
        () => mockRepository.getInvoices(
          libraryId: 'lib-1',
          ownerId: null,
          startDate: null,
          endDate: null,
        ),
      ).called(1);
    });

    test('should_filter_invoices_by_date_range', () async {
      // Arrange
      final startDate = DateTime(2024, 1, 1);
      final endDate = DateTime(2024, 1, 31);

      when(
        () => mockRepository.getInvoices(
          libraryId: null,
          ownerId: null,
          startDate: startDate,
          endDate: endDate,
        ),
      ).thenAnswer((_) async => Right(tInvoices));

      // Act
      final result = await useCase(
        GetAdminInvoicesParams(startDate: startDate, endDate: endDate),
      );

      // Assert
      expect(result, Right(tInvoices));
      verify(
        () => mockRepository.getInvoices(
          libraryId: null,
          ownerId: null,
          startDate: startDate,
          endDate: endDate,
        ),
      ).called(1);
    });

    test('should_return_failure_when_repository_fails', () async {
      // Arrange
      const tFailure = ServerFailure(message: 'Failed to get invoices');
      when(
        () => mockRepository.getInvoices(
          libraryId: any(named: 'libraryId'),
          ownerId: any(named: 'ownerId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => const Left(tFailure));

      // Act
      final result = await useCase(const GetAdminInvoicesParams());

      // Assert
      expect(result, const Left(tFailure));
    });
  });

  group('GetAdminInvoicesParams', () {
    test('should_support_equality', () {
      const params1 = GetAdminInvoicesParams(libraryId: 'lib-1');
      const params2 = GetAdminInvoicesParams(libraryId: 'lib-1');
      const params3 = GetAdminInvoicesParams(libraryId: 'lib-2');

      expect(params1, equals(params2));
      expect(params1, isNot(equals(params3)));
    });

    test('should_include_all_filters_in_props', () {
      final params = GetAdminInvoicesParams(
        libraryId: 'lib-1',
        ownerId: 'owner-1',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 31),
      );

      expect(params.props.length, 4);
    });
  });
}

class ServerFailure extends Failure {
  const ServerFailure({super.message});
}
