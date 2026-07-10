part of 'admin_intelligence_cubit.dart';

/// Status for admin intelligence dashboard.
enum AdminIntelligenceStatus { initial, loading, loaded, error }

/// State for [AdminIntelligenceCubit].
class AdminIntelligenceState extends Equatable {
  const AdminIntelligenceState({
    this.status = AdminIntelligenceStatus.initial,
    this.revenueStats = const RevenueStats.empty(),
    this.churnData = const ChurnData.empty(),
    this.alertsSummary = const AlertsSummary.empty(),
    this.recentActions = const [],
    this.errorMessage,
    this.isPerformingAction = false,
    this.actionSuccess,
    this.actionError,
  });

  final AdminIntelligenceStatus status;
  final RevenueStats revenueStats;
  final ChurnData churnData;
  final AlertsSummary alertsSummary;
  final List<AdminAction> recentActions;
  final String? errorMessage;

  // Action state
  final bool isPerformingAction;
  final String? actionSuccess;
  final String? actionError;

  bool get isLoading => status == AdminIntelligenceStatus.loading;
  bool get isLoaded => status == AdminIntelligenceStatus.loaded;
  bool get hasError => status == AdminIntelligenceStatus.error;

  AdminIntelligenceState copyWith({
    AdminIntelligenceStatus? status,
    RevenueStats? revenueStats,
    ChurnData? churnData,
    AlertsSummary? alertsSummary,
    List<AdminAction>? recentActions,
    String? errorMessage,
    bool? isPerformingAction,
    String? actionSuccess,
    String? actionError,
  }) {
    return AdminIntelligenceState(
      status: status ?? this.status,
      revenueStats: revenueStats ?? this.revenueStats,
      churnData: churnData ?? this.churnData,
      alertsSummary: alertsSummary ?? this.alertsSummary,
      recentActions: recentActions ?? this.recentActions,
      errorMessage: errorMessage,
      isPerformingAction: isPerformingAction ?? this.isPerformingAction,
      actionSuccess: actionSuccess,
      actionError: actionError,
    );
  }

  @override
  List<Object?> get props => [
    status,
    revenueStats,
    churnData,
    alertsSummary,
    recentActions,
    errorMessage,
    isPerformingAction,
    actionSuccess,
    actionError,
  ];
}
