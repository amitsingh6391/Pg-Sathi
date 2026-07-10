import 'package:equatable/equatable.dart';

/// Churn and retention data for admin intelligence.
class ChurnData extends Equatable {
  const ChurnData({
    required this.inactiveLibraries,
    required this.trialExpiredUnpaid,
    required this.lowUsageLibraries,
    required this.generatedAt,
  });

  const ChurnData.empty()
    : inactiveLibraries = const InactiveLibraries.empty(),
      trialExpiredUnpaid = const [],
      lowUsageLibraries = const [],
      generatedAt = null;

  final InactiveLibraries inactiveLibraries;
  final List<AtRiskLibrary> trialExpiredUnpaid;
  final List<AtRiskLibrary> lowUsageLibraries;
  final DateTime? generatedAt;

  int get totalAtRisk =>
      inactiveLibraries.totalCount +
      trialExpiredUnpaid.length +
      lowUsageLibraries.length;

  @override
  List<Object?> get props => [
    inactiveLibraries,
    trialExpiredUnpaid,
    lowUsageLibraries,
    generatedAt,
  ];
}

/// Libraries categorized by inactivity period.
class InactiveLibraries extends Equatable {
  const InactiveLibraries({
    required this.inactive7Days,
    required this.inactive14Days,
    required this.inactive30Days,
  });

  const InactiveLibraries.empty()
    : inactive7Days = const [],
      inactive14Days = const [],
      inactive30Days = const [];

  final List<AtRiskLibrary> inactive7Days;
  final List<AtRiskLibrary> inactive14Days;
  final List<AtRiskLibrary> inactive30Days;

  int get totalCount =>
      inactive7Days.length + inactive14Days.length + inactive30Days.length;

  @override
  List<Object?> get props => [inactive7Days, inactive14Days, inactive30Days];
}

/// A library at risk of churning.
class AtRiskLibrary extends Equatable {
  const AtRiskLibrary({
    required this.libraryId,
    required this.libraryName,
    required this.ownerId,
    required this.ownerName,
    required this.ownerPhone,
    required this.retentionScore,
    required this.riskReasons,
    required this.lastActivityDate,
    required this.subscriptionEndDate,
    required this.monthlyRevenue,
    this.daysInactive,
    this.trialEndDate,
  });

  final String libraryId;
  final String libraryName;
  final String ownerId;
  final String ownerName;
  final String ownerPhone;
  final RetentionScore retentionScore;
  final List<RiskReason> riskReasons;
  final DateTime? lastActivityDate;
  final DateTime? subscriptionEndDate;
  final double monthlyRevenue;
  final int? daysInactive;
  final DateTime? trialEndDate;

  /// WhatsApp URL for quick contact.
  String get whatsappUrl {
    final cleaned = ownerPhone.replaceAll(RegExp(r'[^\d]'), '');
    final phone = cleaned.startsWith('91') ? cleaned : '91$cleaned';
    return 'https://wa.me/$phone';
  }

  @override
  List<Object?> get props => [
    libraryId,
    libraryName,
    ownerId,
    ownerName,
    ownerPhone,
    retentionScore,
    riskReasons,
    lastActivityDate,
    subscriptionEndDate,
    monthlyRevenue,
    daysInactive,
    trialEndDate,
  ];
}

/// Retention score levels.
enum RetentionScore {
  high,
  medium,
  low;

  String get label {
    switch (this) {
      case RetentionScore.high:
        return 'High';
      case RetentionScore.medium:
        return 'Medium';
      case RetentionScore.low:
        return 'Low';
    }
  }
}

/// Reasons why a library is at risk.
enum RiskReason {
  inactive7Days,
  inactive14Days,
  inactive30Days,
  trialExpired,
  lowUsage,
  paymentFailed,
  renewalSoon,
  noStudents,
  ownerInactive;

  String get label {
    switch (this) {
      case RiskReason.inactive7Days:
        return 'Inactive 7+ days';
      case RiskReason.inactive14Days:
        return 'Inactive 14+ days';
      case RiskReason.inactive30Days:
        return 'Inactive 30+ days';
      case RiskReason.trialExpired:
        return 'Trial expired';
      case RiskReason.lowUsage:
        return 'Low usage';
      case RiskReason.paymentFailed:
        return 'Payment failed';
      case RiskReason.renewalSoon:
        return 'Renewal soon';
      case RiskReason.noStudents:
        return 'No students';
      case RiskReason.ownerInactive:
        return 'Owner inactive';
    }
  }
}

/// Retention offer that can be applied to at-risk libraries.
class RetentionOffer extends Equatable {
  const RetentionOffer({
    required this.id,
    required this.name,
    required this.discountPercent,
    required this.validDays,
    required this.description,
  });

  final String id;
  final String name;
  final double discountPercent;
  final int validDays;
  final String description;

  @override
  List<Object?> get props => [
    id,
    name,
    discountPercent,
    validDays,
    description,
  ];
}
