import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../core/core.dart';
import '../entities/membership.dart';
import '../repositories/invoice_repository.dart';
import '../repositories/membership_repository.dart';
import '../repositories/student_document_repository.dart';

/// Use case for syncing unregistered memberships when a student logs in.
/// Finds all memberships linked to the student's phone number and attaches userId.
/// Also syncs invoices and documents that were created with phone number as studentId.
class SyncMembershipsOnLogin
    implements UseCase<List<Membership>, SyncMembershipsOnLoginParams> {
  const SyncMembershipsOnLogin({
    required this.membershipRepository,
    required this.invoiceRepository,
    required this.documentRepository,
  });

  final MembershipRepository membershipRepository;
  final InvoiceRepository invoiceRepository;
  final StudentDocumentRepository documentRepository;

  @override
  Future<Either<Failure, List<Membership>>> call(
    SyncMembershipsOnLoginParams params,
  ) async {
    // Find all unregistered memberships for this phone number
    final unregisteredResult = await membershipRepository
        .getUnregisteredMembershipsByPhone(params.phoneNumber);

    return unregisteredResult.fold((failure) => Left(failure), (
      unregisteredMemberships,
    ) async {
      if (unregisteredMemberships.isEmpty) {
        return const Right([]);
      }

      // Link all unregistered memberships to the user ID
      final linkResult = await membershipRepository.batchLinkMembershipsToUser(
        phoneNumber: params.phoneNumber,
        userId: params.userId,
      );

      return linkResult.fold((failure) => Left(failure), (_) async {
        // Sync invoices that were created with phone number as studentId
        final invoiceSyncResult = await invoiceRepository
            .batchLinkInvoicesToUser(
              phoneNumber: params.phoneNumber,
              userId: params.userId,
            );

        // If invoice sync fails, log but don't fail the entire operation
        // Memberships are more critical than invoices
        invoiceSyncResult.fold(
          (failure) {
            if (kDebugMode) {
              print(
                'SyncMembershipsOnLogin: Invoice sync failed: ${failure.message}',
              );
            }
          },
          (_) {
            if (kDebugMode) {
              print('SyncMembershipsOnLogin: Invoices synced successfully');
            }
          },
        );

        // Sync documents that were uploaded with phone number as studentId
        final documentSyncResult =
            await documentRepository.batchLinkDocumentsToUser(
          phoneNumber: params.phoneNumber,
          userId: params.userId,
        );

        documentSyncResult.fold(
          (failure) {
            if (kDebugMode) {
              print(
                'SyncMembershipsOnLogin: Document sync failed: ${failure.message}',
              );
            }
          },
          (_) {
            if (kDebugMode) {
              print('SyncMembershipsOnLogin: Documents synced successfully');
            }
          },
        );

        // Return linked memberships from memory — no need to re-read
        // from Firestore since we already have the unregistered list and
        // know the userId that was just assigned.
        final linkedMemberships = unregisteredMemberships
            .map(
              (m) => m.copyWith(userId: params.userId),
            )
            .toList();
        return Right(linkedMemberships);
      });
    });
  }
}

/// Parameters for SyncMembershipsOnLogin use case.
class SyncMembershipsOnLoginParams extends Equatable {
  const SyncMembershipsOnLoginParams({
    required this.userId,
    required this.phoneNumber,
  });

  final String userId;
  final String phoneNumber;

  @override
  List<Object?> get props => [userId, phoneNumber];
}
