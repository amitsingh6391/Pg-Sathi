import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/membership.dart';
import 'package:pg_manager/domain/entities/slot.dart';
import 'package:pg_manager/data/failures/data_failures.dart';
import 'package:pg_manager/domain/repositories/invoice_repository.dart';
import 'package:pg_manager/domain/repositories/membership_repository.dart';
import 'package:pg_manager/domain/repositories/student_document_repository.dart';
import 'package:pg_manager/domain/usecases/sync_memberships_on_login.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'sync_memberships_on_login_test.mocks.dart';

@GenerateMocks([MembershipRepository, InvoiceRepository, StudentDocumentRepository])
void main() {
  late SyncMembershipsOnLogin useCase;
  late MockMembershipRepository mockMembershipRepo;
  late MockInvoiceRepository mockInvoiceRepo;
  late MockStudentDocumentRepository mockDocumentRepo;

  setUp(() {
    mockMembershipRepo = MockMembershipRepository();
    mockInvoiceRepo = MockInvoiceRepository();
    mockDocumentRepo = MockStudentDocumentRepository();
    useCase = SyncMembershipsOnLogin(
      membershipRepository: mockMembershipRepo,
      invoiceRepository: mockInvoiceRepo,
      documentRepository: mockDocumentRepo,
    );
  });

  const testUserId = 'user-123';
  const testPhoneNumber = '+919876543210';

  final unregisteredMembership = Membership(
    id: 'mem-1',
    userId: null, // Unregistered
    libraryId: 'lib-123',
    plan: MembershipPlan.monthly,
    startDate: DateTime.now(),
    endDate: DateTime.now().add(const Duration(days: 30)),
    status: MembershipStatus.active,
    phoneNumber: testPhoneNumber,
    assignedSeatId: 'S05',
    slot: Slot.morning,
  );

  final linkedMembership = unregisteredMembership.linkToUser(testUserId);

  group('SyncMembershipsOnLogin', () {
    test(
      'should sync memberships and invoices when student logs in after seat assignment',
      () async {
        // Arrange
        when(
          mockMembershipRepo.getUnregisteredMembershipsByPhone(testPhoneNumber),
        ).thenAnswer((_) async => Right([unregisteredMembership]));

        when(
          mockMembershipRepo.batchLinkMembershipsToUser(
            phoneNumber: testPhoneNumber,
            userId: testUserId,
          ),
        ).thenAnswer((_) async => const Right(null));

        when(
          mockInvoiceRepo.batchLinkInvoicesToUser(
            phoneNumber: testPhoneNumber,
            userId: testUserId,
          ),
        ).thenAnswer((_) async => const Right(null));

        when(
          mockDocumentRepo.batchLinkDocumentsToUser(
            phoneNumber: testPhoneNumber,
            userId: testUserId,
          ),
        ).thenAnswer((_) async => const Right(null));

        when(
          mockMembershipRepo.getMembershipsByPhoneNumber(testPhoneNumber),
        ).thenAnswer((_) async => Right([linkedMembership]));

        // Act
        final result = await useCase(
          const SyncMembershipsOnLoginParams(
            userId: testUserId,
            phoneNumber: testPhoneNumber,
          ),
        );

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not return failure: ${l.message}'), (
          r,
        ) {
          expect(r.length, 1);
          expect(r.first.id, 'mem-1');
          expect(r.first.userId, testUserId);
        });

        // Verify invoice sync was called
        verify(
          mockInvoiceRepo.batchLinkInvoicesToUser(
            phoneNumber: testPhoneNumber,
            userId: testUserId,
          ),
        ).called(1);

        // Verify document sync was called
        verify(
          mockDocumentRepo.batchLinkDocumentsToUser(
            phoneNumber: testPhoneNumber,
            userId: testUserId,
          ),
        ).called(1);
      },
    );

    test(
      'should return empty list when no unregistered memberships exist',
      () async {
        // Arrange
        when(
          mockMembershipRepo.getUnregisteredMembershipsByPhone(testPhoneNumber),
        ).thenAnswer((_) async => const Right([]));

        // Act
        final result = await useCase(
          const SyncMembershipsOnLoginParams(
            userId: testUserId,
            phoneNumber: testPhoneNumber,
          ),
        );

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (l) => fail('Should not return failure'),
          (r) => expect(r, isEmpty),
        );

        // Verify invoice sync was NOT called (no memberships to sync)
        verifyNever(
          mockInvoiceRepo.batchLinkInvoicesToUser(
            phoneNumber: anyNamed('phoneNumber'),
            userId: anyNamed('userId'),
          ),
        );
      },
    );

    test('should continue even if invoice sync fails', () async {
      // Arrange
      when(
        mockMembershipRepo.getUnregisteredMembershipsByPhone(testPhoneNumber),
      ).thenAnswer((_) async => Right([unregisteredMembership]));

      when(
        mockMembershipRepo.batchLinkMembershipsToUser(
          phoneNumber: testPhoneNumber,
          userId: testUserId,
        ),
      ).thenAnswer((_) async => const Right(null));

      when(
        mockInvoiceRepo.batchLinkInvoicesToUser(
          phoneNumber: testPhoneNumber,
          userId: testUserId,
        ),
      ).thenAnswer(
        (_) async => Left(ServerFailure(message: 'Invoice sync failed')),
      );

      when(
        mockDocumentRepo.batchLinkDocumentsToUser(
          phoneNumber: testPhoneNumber,
          userId: testUserId,
        ),
      ).thenAnswer((_) async => const Right(null));

      when(
        mockMembershipRepo.getMembershipsByPhoneNumber(testPhoneNumber),
      ).thenAnswer((_) async => Right([linkedMembership]));

      // Act
      final result = await useCase(
        const SyncMembershipsOnLoginParams(
          userId: testUserId,
          phoneNumber: testPhoneNumber,
        ),
      );

      // Assert - membership sync should still succeed
      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.length, 1);
        expect(r.first.userId, testUserId);
      });
    });

    test('should return failure when membership link fails', () async {
      // Arrange
      when(
        mockMembershipRepo.getUnregisteredMembershipsByPhone(testPhoneNumber),
      ).thenAnswer((_) async => Right([unregisteredMembership]));

      when(
        mockMembershipRepo.batchLinkMembershipsToUser(
          phoneNumber: testPhoneNumber,
          userId: testUserId,
        ),
      ).thenAnswer(
        (_) async => Left(ServerFailure(message: 'Failed to link memberships')),
      );

      // Act
      final result = await useCase(
        const SyncMembershipsOnLoginParams(
          userId: testUserId,
          phoneNumber: testPhoneNumber,
        ),
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (l) => expect(l.message, 'Failed to link memberships'),
        (r) => fail('Should return failure'),
      );

      // Verify invoice sync was NOT called (membership sync failed first)
      verifyNever(
        mockInvoiceRepo.batchLinkInvoicesToUser(
          phoneNumber: anyNamed('phoneNumber'),
          userId: anyNamed('userId'),
        ),
      );
    });
  });
}
