import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/invoice.dart';
import '../repositories/invoice_repository.dart';
import '../repositories/membership_repository.dart';

/// Use case for getting all invoices for a student.
/// Queries by studentId and also by membershipIds to catch invoices
/// created before student signup (where studentId was phone number).
class GetInvoicesForStudent
    implements UseCase<List<Invoice>, GetInvoicesForStudentParams> {
  const GetInvoicesForStudent({
    required this.invoiceRepository,
    required this.membershipRepository,
  });

  final InvoiceRepository invoiceRepository;
  final MembershipRepository membershipRepository;

  @override
  Future<Either<Failure, List<Invoice>>> call(
    GetInvoicesForStudentParams params,
  ) async {
    // Query invoices by studentId (userId)
    final invoicesByStudentIdResult = await invoiceRepository
        .getInvoicesForStudent(params.studentId);

    // Also get memberships to find invoices by membershipId
    // This catches invoices created before signup (where studentId was phone number)
    final membershipsResult = await membershipRepository.getMembershipsByUserId(
      params.studentId,
    );

    return membershipsResult.fold((failure) => invoicesByStudentIdResult, (
      memberships,
    ) async {
      if (memberships.isEmpty) {
        return invoicesByStudentIdResult;
      }

      // Get membership IDs
      final membershipIds = memberships.map((m) => m.id).toList();

      // Query invoices by membershipIds
      final invoicesByMembershipResult = await invoiceRepository
          .getInvoicesByMembershipIds(membershipIds);

      return invoicesByMembershipResult.fold(
        (failure) => invoicesByStudentIdResult,
        (invoicesByMembership) async {
          // Extract invoices from studentId query
          final invoicesByStudentId = invoicesByStudentIdResult.fold(
            (_) => <Invoice>[],
            (invoices) => invoices,
          );

          // Combine and deduplicate by invoice ID
          final allInvoices = <String, Invoice>{};
          for (final invoice in invoicesByStudentId) {
            allInvoices[invoice.id] = invoice;
          }
          for (final invoice in invoicesByMembership) {
            allInvoices[invoice.id] = invoice;
          }

          // Sort by generatedAt descending (newest first)
          final sortedInvoices = allInvoices.values.toList()
            ..sort((a, b) => b.generatedAt.compareTo(a.generatedAt));

          return Right(sortedInvoices);
        },
      );
    });
  }
}

/// Parameters for GetInvoicesForStudent use case.
class GetInvoicesForStudentParams extends Equatable {
  const GetInvoicesForStudentParams({required this.studentId});

  final String studentId;

  @override
  List<Object?> get props => [studentId];
}
