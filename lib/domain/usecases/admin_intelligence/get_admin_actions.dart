import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../core/core.dart';
import '../../entities/admin_action.dart';
import '../../repositories/admin_intelligence_repository.dart';

/// Use case for getting admin actions (audit log).
class GetAdminActions
    implements UseCase<List<AdminAction>, GetAdminActionsParams> {
  const GetAdminActions({required this.repository});

  final AdminIntelligenceRepository repository;

  @override
  Future<Either<Failure, List<AdminAction>>> call(
    GetAdminActionsParams params,
  ) {
    return repository.getAdminActions(
      libraryId: params.libraryId,
      actionType: params.actionType,
      startDate: params.startDate,
      endDate: params.endDate,
      limit: params.limit,
    );
  }
}

class GetAdminActionsParams extends Equatable {
  const GetAdminActionsParams({
    this.libraryId,
    this.actionType,
    this.startDate,
    this.endDate,
    this.limit = 50,
  });

  final String? libraryId;
  final AdminActionType? actionType;
  final DateTime? startDate;
  final DateTime? endDate;
  final int limit;

  @override
  List<Object?> get props => [libraryId, actionType, startDate, endDate, limit];
}
