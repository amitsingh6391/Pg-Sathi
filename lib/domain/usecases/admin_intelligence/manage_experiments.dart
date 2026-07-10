import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../core/core.dart';
import '../../entities/pricing_experiment.dart';
import '../../repositories/admin_intelligence_repository.dart';

/// Use case for creating a pricing experiment.
class CreateExperiment
    implements UseCase<PricingExperiment, CreateExperimentRequest> {
  const CreateExperiment({required this.repository});

  final AdminIntelligenceRepository repository;

  @override
  Future<Either<Failure, PricingExperiment>> call(
    CreateExperimentRequest params,
  ) {
    return repository.createExperiment(params);
  }
}

/// Use case for getting all experiments.
class GetExperiments
    implements UseCase<List<PricingExperiment>, GetExperimentsParams> {
  const GetExperiments({required this.repository});

  final AdminIntelligenceRepository repository;

  @override
  Future<Either<Failure, List<PricingExperiment>>> call(
    GetExperimentsParams params,
  ) {
    return repository.getExperiments(status: params.status);
  }
}

class GetExperimentsParams extends Equatable {
  const GetExperimentsParams({this.status});

  final ExperimentStatus? status;

  @override
  List<Object?> get props => [status];
}

/// Use case for updating experiment status.
class UpdateExperimentStatus
    implements UseCase<void, UpdateExperimentStatusParams> {
  const UpdateExperimentStatus({required this.repository});

  final AdminIntelligenceRepository repository;

  @override
  Future<Either<Failure, void>> call(UpdateExperimentStatusParams params) {
    return repository.updateExperimentStatus(
      experimentId: params.experimentId,
      status: params.status,
      adminId: params.adminId,
    );
  }
}

class UpdateExperimentStatusParams extends Equatable {
  const UpdateExperimentStatusParams({
    required this.experimentId,
    required this.status,
    required this.adminId,
  });

  final String experimentId;
  final ExperimentStatus status;
  final String adminId;

  @override
  List<Object?> get props => [experimentId, status, adminId];
}
