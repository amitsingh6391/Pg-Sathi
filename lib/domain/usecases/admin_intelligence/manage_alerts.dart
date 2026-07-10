import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../core/core.dart';
import '../../entities/admin_alert.dart';
import '../../repositories/admin_intelligence_repository.dart';

/// Use case for getting alerts summary.
class GetAlertsSummary implements UseCase<AlertsSummary, NoParams> {
  const GetAlertsSummary({required this.repository});

  final AdminIntelligenceRepository repository;

  @override
  Future<Either<Failure, AlertsSummary>> call(NoParams params) {
    return repository.getAlertsSummary();
  }
}

/// Use case for getting all alerts.
class GetAlerts implements UseCase<List<AdminAlert>, GetAlertsParams> {
  const GetAlerts({required this.repository});

  final AdminIntelligenceRepository repository;

  @override
  Future<Either<Failure, List<AdminAlert>>> call(GetAlertsParams params) {
    return repository.getAlerts(
      type: params.type,
      severity: params.severity,
      isRead: params.isRead,
      limit: params.limit,
    );
  }
}

class GetAlertsParams extends Equatable {
  const GetAlertsParams({
    this.type,
    this.severity,
    this.isRead,
    this.limit = 50,
  });

  final AlertType? type;
  final AlertSeverity? severity;
  final bool? isRead;
  final int limit;

  @override
  List<Object?> get props => [type, severity, isRead, limit];
}

/// Use case for marking an alert as read.
class MarkAlertAsRead implements UseCase<void, String> {
  const MarkAlertAsRead({required this.repository});

  final AdminIntelligenceRepository repository;

  @override
  Future<Either<Failure, void>> call(String alertId) {
    return repository.markAlertAsRead(alertId);
  }
}

/// Use case for marking all alerts as read.
class MarkAllAlertsAsRead implements UseCase<void, NoParams> {
  const MarkAllAlertsAsRead({required this.repository});

  final AdminIntelligenceRepository repository;

  @override
  Future<Either<Failure, void>> call(NoParams params) {
    return repository.markAllAlertsAsRead();
  }
}
