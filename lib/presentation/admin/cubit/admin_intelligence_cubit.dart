import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../domain/core/usecase.dart';
import '../../../domain/entities/admin_action.dart';
import '../../../domain/entities/admin_alert.dart';
import '../../../domain/entities/churn_data.dart';
import '../../../domain/entities/revenue_stats.dart';
import '../../../domain/usecases/admin_intelligence/admin_intelligence_usecases.dart';

part 'admin_intelligence_state.dart';

/// Cubit for managing Admin Intelligence dashboard.
class AdminIntelligenceCubit extends Cubit<AdminIntelligenceState> {
  AdminIntelligenceCubit({
    required this.getRevenueStats,
    required this.getChurnData,
    required this.getAlertsSummary,
    required this.getAdminActions,
    required this.suspendLibrary,
    required this.unsuspendLibrary,
    required this.extendTrial,
    required this.applyDiscount,
    required this.removeDiscount,
    required this.adminMarkPaymentReceived,
    required this.markAlertAsRead,
  }) : super(const AdminIntelligenceState());

  final GetRevenueStats getRevenueStats;
  final GetChurnData getChurnData;
  final GetAlertsSummary getAlertsSummary;
  final GetAdminActions getAdminActions;
  final SuspendLibrary suspendLibrary;
  final UnsuspendLibrary unsuspendLibrary;
  final ExtendTrial extendTrial;
  final ApplyDiscount applyDiscount;
  final RemoveDiscount removeDiscount;
  final AdminMarkPaymentReceived adminMarkPaymentReceived;
  final MarkAlertAsRead markAlertAsRead;

  /// Load all dashboard data.
  Future<void> loadDashboard() async {
    emit(state.copyWith(status: AdminIntelligenceStatus.loading));

    try {
      final results = await Future.wait([
        getRevenueStats(NoParams()),
        getChurnData(NoParams()),
        getAlertsSummary(NoParams()),
        getAdminActions(const GetAdminActionsParams(limit: 20)),
      ]);

      RevenueStats? revenue;
      ChurnData? churn;
      AlertsSummary? alerts;
      List<AdminAction> actions = [];
      String? error;

      results[0].fold(
        (l) => error = l.message,
        (r) => revenue = r as RevenueStats,
      );
      results[1].fold(
        (l) => error ??= l.message,
        (r) => churn = r as ChurnData,
      );
      results[2].fold(
        (l) => error ??= l.message,
        (r) => alerts = r as AlertsSummary,
      );
      results[3].fold(
        (l) => error ??= l.message,
        (r) => actions = r as List<AdminAction>,
      );

      if (error != null) {
        emit(
          state.copyWith(
            status: AdminIntelligenceStatus.error,
            errorMessage: error,
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: AdminIntelligenceStatus.loaded,
            revenueStats: revenue,
            churnData: churn,
            alertsSummary: alerts,
            recentActions: actions,
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: AdminIntelligenceStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Suspend a library.
  Future<void> performSuspendLibrary(SuspendLibraryRequest request) async {
    emit(state.copyWith(isPerformingAction: true, actionError: null));

    final result = await suspendLibrary(request);

    result.fold(
      (failure) => emit(
        state.copyWith(isPerformingAction: false, actionError: failure.message),
      ),
      (_) {
        emit(
          state.copyWith(
            isPerformingAction: false,
            actionSuccess: 'Library suspended successfully',
          ),
        );
        loadDashboard(); // Refresh data
      },
    );
  }

  /// Unsuspend a library.
  Future<void> performUnsuspendLibrary({
    required String libraryId,
    required String reason,
    required String adminId,
  }) async {
    emit(state.copyWith(isPerformingAction: true, actionError: null));

    final result = await unsuspendLibrary(
      UnsuspendLibraryParams(
        libraryId: libraryId,
        reason: reason,
        adminId: adminId,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(isPerformingAction: false, actionError: failure.message),
      ),
      (_) {
        emit(
          state.copyWith(
            isPerformingAction: false,
            actionSuccess: 'Library unsuspended successfully',
          ),
        );
        loadDashboard();
      },
    );
  }

  /// Extend a library's trial.
  Future<void> performExtendTrial(ExtendTrialRequest request) async {
    emit(state.copyWith(isPerformingAction: true, actionError: null));

    final result = await extendTrial(request);

    result.fold(
      (failure) => emit(
        state.copyWith(isPerformingAction: false, actionError: failure.message),
      ),
      (_) {
        emit(
          state.copyWith(
            isPerformingAction: false,
            actionSuccess: 'Trial extended by ${request.extensionDays} days',
          ),
        );
        loadDashboard();
      },
    );
  }

  /// Apply a custom discount.
  Future<void> performApplyDiscount(ApplyDiscountRequest request) async {
    emit(state.copyWith(isPerformingAction: true, actionError: null));

    final result = await applyDiscount(request);

    result.fold(
      (failure) => emit(
        state.copyWith(isPerformingAction: false, actionError: failure.message),
      ),
      (_) {
        emit(
          state.copyWith(
            isPerformingAction: false,
            actionSuccess: 'Discount of ${request.discountPercent}% applied',
          ),
        );
        loadDashboard();
      },
    );
  }

  /// Remove a custom discount.
  Future<void> performRemoveDiscount(RemoveDiscountRequest request) async {
    emit(state.copyWith(isPerformingAction: true, actionError: null));

    final result = await removeDiscount(request);

    result.fold(
      (failure) => emit(
        state.copyWith(isPerformingAction: false, actionError: failure.message),
      ),
      (_) {
        emit(
          state.copyWith(
            isPerformingAction: false,
            actionSuccess: 'Discount removed successfully',
          ),
        );
        loadDashboard();
      },
    );
  }

  /// Mark payment as received.
  Future<void> performMarkPayment(ManualPaymentRequest request) async {
    emit(state.copyWith(isPerformingAction: true, actionError: null));

    final result = await adminMarkPaymentReceived(request);

    result.fold(
      (failure) => emit(
        state.copyWith(isPerformingAction: false, actionError: failure.message),
      ),
      (_) {
        emit(
          state.copyWith(
            isPerformingAction: false,
            actionSuccess: 'Payment marked as received',
          ),
        );
        loadDashboard();
      },
    );
  }

  /// Mark an alert as read.
  Future<void> markAlertRead(String alertId) async {
    final result = await markAlertAsRead(alertId);
    result.fold(
      (failure) => null, // Silent fail
      (_) => loadDashboard(), // Refresh
    );
  }

  /// Clear action messages.
  void clearActionMessages() {
    emit(state.copyWith(actionSuccess: null, actionError: null));
  }
}
