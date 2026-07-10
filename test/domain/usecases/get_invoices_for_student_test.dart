import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/invoice.dart';
import 'package:pg_manager/domain/entities/membership.dart';
import 'package:pg_manager/domain/entities/slot.dart';
import 'package:pg_manager/data/failures/data_failures.dart';
import 'package:pg_manager/domain/repositories/invoice_repository.dart';
import 'package:pg_manager/domain/repositories/membership_repository.dart';
import 'package:pg_manager/domain/usecases/get_invoices_for_student.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'get_invoices_for_student_test.mocks.dart';

@GenerateMocks([InvoiceRepository, MembershipRepository])
void main() {
  late GetInvoicesForStudent useCase;
  late MockInvoiceRepository mockInvoiceRepo;
  late MockMembershipRepository mockMembershipRepo;

  setUp(() {
    mockInvoiceRepo = MockInvoiceRepository();
    mockMembershipRepo = MockMembershipRepository();
    useCase = GetInvoicesForStudent(
      invoiceRepository: mockInvoiceRepo,
      membershipRepository: mockMembershipRepo,
    );
  });

  const testUserId = 'user-123';
  const testMembershipId = 'mem-1';

  final testMembership = Membership(
    id: testMembershipId,
    userId: testUserId,
    libraryId: 'lib-123',
    plan: MembershipPlan.monthly,
    startDate: DateTime.now(),
    endDate: DateTime.now().add(const Duration(days: 30)),
    status: MembershipStatus.active,
    phoneNumber: '+919876543210',
    assignedSeatId: 'S05',
    slot: Slot.morning,
  );

  final invoiceByStudentId = Invoice(
    id: 'inv-1',
    invoiceNumber: 'INV-2024-000001',
    libraryId: 'lib-123',
    libraryName: 'Test Library',
    libraryAddress: 'Test Address',
    ownerId: 'owner-1',
    ownerName: 'Owner',
    ownerContact: '+919876543210',
    studentId: testUserId,
    studentName: 'Student',
    studentPhone: '+919876543210',
    membershipId: testMembershipId,
    seatNumber: 'S05',
    slot: Slot.morning,
    sessionTiming: '6:00 AM – 2:00 PM',
    billingMonth: '2024-01',
    amountPaid: 1000.0,
    currency: 'INR',
    paymentId: 'pay-1',
    paymentDate: DateTime.now(),
    generatedAt: DateTime.now(),
    expiryDate: DateTime.now().add(const Duration(days: 30)),
  );

  // Invoice created before signup (studentId was phone number)
  final invoiceByMembership = Invoice(
    id: 'inv-2',
    invoiceNumber: 'INV-2024-000002',
    libraryId: 'lib-123',
    libraryName: 'Test Library',
    libraryAddress: 'Test Address',
    ownerId: 'owner-1',
    ownerName: 'Owner',
    ownerContact: '+919876543210',
    studentId: '+919876543210', // Phone number (before sync)
    studentName: 'Student',
    studentPhone: '+919876543210',
    membershipId: testMembershipId,
    seatNumber: 'S05',
    slot: Slot.morning,
    sessionTiming: '6:00 AM – 2:00 PM',
    billingMonth: '2024-02',
    amountPaid: 1000.0,
    currency: 'INR',
    paymentId: 'pay-2',
    paymentDate: DateTime.now(),
    generatedAt: DateTime.now().subtract(const Duration(days: 5)),
    expiryDate: DateTime.now().add(const Duration(days: 30)),
  );

  group('GetInvoicesForStudent', () {
    test(
      'should return invoices by studentId when student has memberships',
      () async {
        // Arrange
        when(
          mockInvoiceRepo.getInvoicesForStudent(testUserId),
        ).thenAnswer((_) async => Right([invoiceByStudentId]));

        when(
          mockMembershipRepo.getMembershipsByUserId(testUserId),
        ).thenAnswer((_) async => Right([testMembership]));

        when(
          mockInvoiceRepo.getInvoicesByMembershipIds([testMembershipId]),
        ).thenAnswer((_) async => Right([invoiceByMembership]));

        // Act
        final result = await useCase(
          const GetInvoicesForStudentParams(studentId: testUserId),
        );

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not return failure: ${l.message}'), (
          r,
        ) {
          expect(r.length, 2);
          // Should be sorted by generatedAt descending (newest first)
          expect(r.first.id, 'inv-1'); // Newer invoice
          expect(r.last.id, 'inv-2'); // Older invoice
        });
      },
    );

    test(
      'should return invoices by studentId when student has no memberships',
      () async {
        // Arrange
        when(
          mockInvoiceRepo.getInvoicesForStudent(testUserId),
        ).thenAnswer((_) async => Right([invoiceByStudentId]));

        when(
          mockMembershipRepo.getMembershipsByUserId(testUserId),
        ).thenAnswer((_) async => const Right([]));

        // Act
        final result = await useCase(
          const GetInvoicesForStudentParams(studentId: testUserId),
        );

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not return failure'), (r) {
          expect(r.length, 1);
          expect(r.first.id, 'inv-1');
        });

        // Verify membership query was not called
        verifyNever(mockInvoiceRepo.getInvoicesByMembershipIds(any));
      },
    );

    test(
      'should deduplicate invoices when same invoice appears in both queries',
      () async {
        // Arrange - same invoice in both results
        when(
          mockInvoiceRepo.getInvoicesForStudent(testUserId),
        ).thenAnswer((_) async => Right([invoiceByStudentId]));

        when(
          mockMembershipRepo.getMembershipsByUserId(testUserId),
        ).thenAnswer((_) async => Right([testMembership]));

        when(
          mockInvoiceRepo.getInvoicesByMembershipIds([testMembershipId]),
        ).thenAnswer((_) async => Right([invoiceByStudentId])); // Same invoice

        // Act
        final result = await useCase(
          const GetInvoicesForStudentParams(studentId: testUserId),
        );

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not return failure'), (r) {
          expect(r.length, 1); // Deduplicated
          expect(r.first.id, 'inv-1');
        });
      },
    );

    test('should return failure when invoice query fails', () async {
      // Arrange
      when(mockInvoiceRepo.getInvoicesForStudent(testUserId)).thenAnswer(
        (_) async => Left(ServerFailure(message: 'Failed to fetch invoices')),
      );

      when(
        mockMembershipRepo.getMembershipsByUserId(testUserId),
      ).thenAnswer((_) async => const Right([]));

      // Act
      final result = await useCase(
        const GetInvoicesForStudentParams(studentId: testUserId),
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (l) => expect(l.message, 'Failed to fetch invoices'),
        (r) => fail('Should return failure'),
      );
    });

    test(
      'should return invoices by studentId when membership query fails',
      () async {
        // Arrange
        when(
          mockInvoiceRepo.getInvoicesForStudent(testUserId),
        ).thenAnswer((_) async => Right([invoiceByStudentId]));

        when(mockMembershipRepo.getMembershipsByUserId(testUserId)).thenAnswer(
          (_) async =>
              Left(ServerFailure(message: 'Failed to fetch memberships')),
        );

        // Act
        final result = await useCase(
          const GetInvoicesForStudentParams(studentId: testUserId),
        );

        // Assert - should still return invoices by studentId
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not return failure'), (r) {
          expect(r.length, 1);
          expect(r.first.id, 'inv-1');
        });
      },
    );
  });
}
