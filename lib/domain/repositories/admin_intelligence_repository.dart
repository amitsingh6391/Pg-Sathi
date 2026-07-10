import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/admin_action.dart';
import '../entities/admin_alert.dart';
import '../entities/admin_note.dart';
import '../entities/churn_data.dart';
import '../entities/pricing_experiment.dart';
import '../entities/revenue_stats.dart';

/// Repository for Admin Intelligence System (V2).
/// Handles revenue, churn, actions, experiments, alerts, and notes.
abstract class AdminIntelligenceRepository {
  // ============================================================================
  // Revenue Intelligence
  // ============================================================================

  /// Gets comprehensive revenue statistics.
  Future<Either<Failure, RevenueStats>> getRevenueStats();

  /// Gets revenue breakdown by plan.
  Future<Either<Failure, List<PlanRevenueBreakdown>>> getPlanWiseRevenue();

  /// Gets revenue breakdown by seat slabs.
  Future<Either<Failure, List<SeatSlabBreakdown>>> getSeatSlabRevenue();

  /// Gets upcoming renewals.
  Future<Either<Failure, UpcomingRenewals>> getUpcomingRenewals();

  /// Gets failed/missed renewals.
  Future<Either<Failure, List<FailedRenewal>>> getFailedRenewals();

  // ============================================================================
  // Churn & Retention
  // ============================================================================

  /// Gets churn and retention data.
  Future<Either<Failure, ChurnData>> getChurnData();

  /// Gets libraries at risk of churning.
  Future<Either<Failure, List<AtRiskLibrary>>> getAtRiskLibraries();

  // ============================================================================
  // Admin Actions
  // ============================================================================

  /// Suspends a library.
  Future<Either<Failure, void>> suspendLibrary(SuspendLibraryRequest request);

  /// Unsuspends a library.
  Future<Either<Failure, void>> unsuspendLibrary({
    required String libraryId,
    required String reason,
    required String adminId,
  });

  /// Extends a library's trial period.
  Future<Either<Failure, void>> extendTrial(ExtendTrialRequest request);

  /// Applies a custom discount to a library.
  Future<Either<Failure, void>> applyDiscount(ApplyDiscountRequest request);

  /// Removes a custom discount from a library.
  Future<Either<Failure, void>> removeDiscount(RemoveDiscountRequest request);

  /// Marks a payment as received manually.
  Future<Either<Failure, void>> markPaymentReceived(
    ManualPaymentRequest request,
  );

  /// Gets suspension status for a library.
  Future<Either<Failure, LibrarySuspensionStatus>> getSuspensionStatus(
    String libraryId,
  );

  /// Gets audit log of admin actions.
  Future<Either<Failure, List<AdminAction>>> getAdminActions({
    String? libraryId,
    AdminActionType? actionType,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  });

  // ============================================================================
  // Pricing Experiments
  // ============================================================================

  /// Creates a new pricing experiment.
  Future<Either<Failure, PricingExperiment>> createExperiment(
    CreateExperimentRequest request,
  );

  /// Gets all pricing experiments.
  Future<Either<Failure, List<PricingExperiment>>> getExperiments({
    ExperimentStatus? status,
  });

  /// Gets a specific experiment by ID.
  Future<Either<Failure, PricingExperiment>> getExperimentById(String id);

  /// Updates experiment status.
  Future<Either<Failure, void>> updateExperimentStatus({
    required String experimentId,
    required ExperimentStatus status,
    required String adminId,
  });

  /// Adds libraries to an experiment.
  Future<Either<Failure, void>> addLibrariesToExperiment({
    required String experimentId,
    required List<String> libraryIds,
  });

  /// Removes libraries from an experiment.
  Future<Either<Failure, void>> removeLibrariesFromExperiment({
    required String experimentId,
    required List<String> libraryIds,
  });

  // ============================================================================
  // Smart Alerts
  // ============================================================================

  /// Gets alert summary for admin dashboard.
  Future<Either<Failure, AlertsSummary>> getAlertsSummary();

  /// Gets all alerts with optional filtering.
  Future<Either<Failure, List<AdminAlert>>> getAlerts({
    AlertType? type,
    AlertSeverity? severity,
    bool? isRead,
    int limit = 50,
  });

  /// Marks an alert as read.
  Future<Either<Failure, void>> markAlertAsRead(String alertId);

  /// Marks all alerts as read.
  Future<Either<Failure, void>> markAllAlertsAsRead();

  /// Generates alerts based on current platform state.
  /// This is typically called by a background job.
  Future<Either<Failure, List<AdminAlert>>> generateAlerts();

  // ============================================================================
  // Admin Notes (CRM Lite)
  // ============================================================================

  /// Creates a new note for a library.
  Future<Either<Failure, AdminNote>> createNote(CreateNoteRequest request);

  /// Updates an existing note.
  Future<Either<Failure, AdminNote>> updateNote(UpdateNoteRequest request);

  /// Deletes a note.
  Future<Either<Failure, void>> deleteNote(String noteId);

  /// Gets all notes for a library.
  Future<Either<Failure, List<AdminNote>>> getNotesForLibrary(String libraryId);

  /// Gets notes summary for a library.
  Future<Either<Failure, LibraryNotesSummary>> getNotesSummary(
    String libraryId,
  );

  /// Gets all notes with follow-up reminders.
  Future<Either<Failure, List<AdminNote>>> getNotesWithFollowUps({
    bool overdueOnly = false,
  });

  /// Toggles pin status of a note.
  Future<Either<Failure, void>> toggleNotePin(String noteId);
}
