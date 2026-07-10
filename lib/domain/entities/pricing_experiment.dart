import 'package:equatable/equatable.dart';

/// A pricing experiment for A/B testing.
class PricingExperiment extends Equatable {
  const PricingExperiment({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.createdBy,
    required this.targetLibraryIds,
    required this.metrics,
    this.startDate,
    this.endDate,
    this.trialDurationDays,
    this.discountPercent,
  });

  final String id;
  final String name;
  final String description;
  final ExperimentType type;
  final ExperimentStatus status;
  final DateTime createdAt;
  final String createdBy;
  final List<String> targetLibraryIds;
  final ExperimentMetrics metrics;
  final DateTime? startDate;
  final DateTime? endDate;

  // Experiment values based on type
  final int? trialDurationDays;
  final double? discountPercent;

  bool get isActive => status == ExperimentStatus.active;
  bool get isCompleted => status == ExperimentStatus.completed;

  int get targetCount => targetLibraryIds.length;

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    type,
    status,
    createdAt,
    createdBy,
    targetLibraryIds,
    metrics,
    startDate,
    endDate,
    trialDurationDays,
    discountPercent,
  ];
}

/// Type of pricing experiment.
enum ExperimentType {
  trialDuration,
  discount,
  customPricing;

  String get label {
    switch (this) {
      case ExperimentType.trialDuration:
        return 'Trial Duration';
      case ExperimentType.discount:
        return 'Discount';
      case ExperimentType.customPricing:
        return 'Custom Pricing';
    }
  }
}

/// Status of a pricing experiment.
enum ExperimentStatus {
  draft,
  active,
  paused,
  completed,
  cancelled;

  String get label {
    switch (this) {
      case ExperimentStatus.draft:
        return 'Draft';
      case ExperimentStatus.active:
        return 'Active';
      case ExperimentStatus.paused:
        return 'Paused';
      case ExperimentStatus.completed:
        return 'Completed';
      case ExperimentStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Metrics for tracking experiment performance.
class ExperimentMetrics extends Equatable {
  const ExperimentMetrics({
    required this.impressions,
    required this.conversions,
    required this.revenue,
    required this.lastUpdated,
  });

  const ExperimentMetrics.empty()
    : impressions = 0,
      conversions = 0,
      revenue = 0.0,
      lastUpdated = null;

  final int impressions;
  final int conversions;
  final double revenue;
  final DateTime? lastUpdated;

  double get conversionRate =>
      impressions > 0 ? (conversions / impressions) * 100 : 0;

  double get averageRevenue => conversions > 0 ? revenue / conversions : 0;

  @override
  List<Object?> get props => [impressions, conversions, revenue, lastUpdated];
}

/// Request to create a new pricing experiment.
class CreateExperimentRequest extends Equatable {
  const CreateExperimentRequest({
    required this.name,
    required this.description,
    required this.type,
    required this.targetLibraryIds,
    required this.adminId,
    this.trialDurationDays,
    this.discountPercent,
    this.startDate,
    this.endDate,
  });

  final String name;
  final String description;
  final ExperimentType type;
  final List<String> targetLibraryIds;
  final String adminId;
  final int? trialDurationDays;
  final double? discountPercent;
  final DateTime? startDate;
  final DateTime? endDate;

  @override
  List<Object?> get props => [
    name,
    description,
    type,
    targetLibraryIds,
    adminId,
    trialDurationDays,
    discountPercent,
    startDate,
    endDate,
  ];
}
