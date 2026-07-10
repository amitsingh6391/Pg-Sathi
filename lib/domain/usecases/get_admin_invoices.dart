import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/invoice.dart';
import '../repositories/admin_analytics_repository.dart';

/// Use case for fetching invoices with filters for admin.
/// Admin has read-only access to all invoices.
class GetAdminInvoices
    implements UseCase<List<Invoice>, GetAdminInvoicesParams> {
  const GetAdminInvoices({required this.repository});

  final AdminAnalyticsRepository repository;

  @override
  Future<Either<Failure, List<Invoice>>> call(GetAdminInvoicesParams params) {
    return repository.getInvoices(
      libraryId: params.libraryId,
      ownerId: params.ownerId,
      startDate: params.startDate,
      endDate: params.endDate,
    );
  }
}

/// Parameters for GetAdminInvoices use case.
class GetAdminInvoicesParams extends Equatable {
  const GetAdminInvoicesParams({
    this.libraryId,
    this.ownerId,
    this.startDate,
    this.endDate,
  });

  /// Filter by specific library.
  final String? libraryId;

  /// Filter by specific owner.
  final String? ownerId;

  /// Filter invoices from this date.
  final DateTime? startDate;

  /// Filter invoices until this date.
  final DateTime? endDate;

  @override
  List<Object?> get props => [libraryId, ownerId, startDate, endDate];
}
