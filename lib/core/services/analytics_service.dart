/// Abstract analytics service interface.
/// Defines contract for tracking user events and behavior across the platform.
/// 
/// All events automatically include:
/// - user_id: Current user identifier
/// - user_role: User role (admin/owner/student)
/// - library_id: Associated library (nullable for admin)
/// - platform: Current platform (android/ios/web)
/// - timestamp: Event timestamp
abstract class AnalyticsService {
  /// Tracks a custom event with parameters.
  /// 
  /// Use this for any event not covered by helper methods.
  /// 
  /// Example:
  /// ```dart
  /// await analyticsService.trackEvent(
  ///   'custom_action',
  ///   parameters: {'action_type': 'button_tap'},
  /// );
  /// ```
  Future<void> trackEvent(
    String eventName, {
    Map<String, dynamic>? parameters,
  });

  /// Sets user properties for analytics context.
  /// 
  /// Called when user signs in or role changes.
  /// Automatically included in all subsequent events.
  Future<void> setUserContext({
    required String userId,
    required String userRole,
    String? libraryId,
  });

  /// Clears user context on sign out.
  Future<void> clearUserContext();

  // ============================================
  // MEMBERSHIP EVENTS
  // ============================================

  /// Tracks membership creation.
  Future<void> trackMembershipCreated({
    required String membershipId,
    required String planType,
    required String duration,
    required double amount,
    Map<String, dynamic>? additionalParams,
  });

  /// Tracks membership renewal.
  Future<void> trackMembershipRenewed({
    required String membershipId,
    required String planType,
    required String duration,
    required double amount,
    Map<String, dynamic>? additionalParams,
  });

  // ============================================
  // ATTENDANCE EVENTS
  // ============================================

  /// Tracks attendance marking.
  Future<void> trackAttendanceMarked({
    required String studentId,
    required String attendanceType,
    required String sessionType,
    Map<String, dynamic>? additionalParams,
  });

  /// Tracks bulk attendance operation.
  Future<void> trackBulkAttendanceMarked({
    required int studentCount,
    required String attendanceType,
    Map<String, dynamic>? additionalParams,
  });

  // ============================================
  // SEAT MANAGEMENT EVENTS
  // ============================================

  /// Tracks seat assignment.
  Future<void> trackSeatAssigned({
    required String seatNumber,
    required String studentId,
    Map<String, dynamic>? additionalParams,
  });

  /// Tracks seat unassignment.
  Future<void> trackSeatUnassigned({
    required String seatNumber,
    required String studentId,
    Map<String, dynamic>? additionalParams,
  });

  // ============================================
  // INVOICE EVENTS
  // ============================================

  /// Tracks invoice generation.
  Future<void> trackInvoiceGenerated({
    required String invoiceId,
    required String invoiceType,
    required double amount,
    Map<String, dynamic>? additionalParams,
  });

  /// Tracks invoice download.
  Future<void> trackInvoiceDownloaded({
    required String invoiceId,
    required String invoiceType,
    Map<String, dynamic>? additionalParams,
  });

  /// Tracks invoice share.
  Future<void> trackInvoiceShared({
    required String invoiceId,
    required String invoiceType,
    required String shareMethod,
    Map<String, dynamic>? additionalParams,
  });

  // ============================================
  // PAYMENT EVENTS
  // ============================================

  /// Tracks payment failure.
  Future<void> trackPaymentFailed({
    required String paymentId,
    required String paymentMethod,
    required double amount,
    required String failureReason,
    Map<String, dynamic>? additionalParams,
  });

  /// Tracks payment refund.
  Future<void> trackPaymentRefunded({
    required String paymentId,
    required String paymentMethod,
    required double amount,
    required String reason,
    Map<String, dynamic>? additionalParams,
  });

  // ============================================
  // UTILITY/TOOL EVENTS
  // ============================================

  /// Tracks student utility usage.
  Future<void> trackStudentUtilityUsed({
    required String utilityName,
    Map<String, dynamic>? additionalParams,
  });

  /// Tracks bulk import operation.
  Future<void> trackBulkImportUsed({
    required String importType,
    required int recordCount,
    required bool success,
    Map<String, dynamic>? additionalParams,
  });

  // ============================================
  // SUBSCRIPTION EVENTS
  // ============================================

  /// Tracks subscription purchase.
  Future<void> trackSubscriptionPurchased({
    required String subscriptionPlan,
    required double amount,
    required String duration,
    Map<String, dynamic>? additionalParams,
  });

  /// Tracks subscription cancellation.
  Future<void> trackSubscriptionCancelled({
    required String subscriptionPlan,
    required String cancellationReason,
    Map<String, dynamic>? additionalParams,
  });

}

/// Analytics event names constants.
/// Used internally by the service to ensure consistency.
class AnalyticsEventNames {
  // Membership events
  static const membershipCreated = 'membership_created';
  static const membershipRenewed = 'membership_renewed';
  static const membershipExpired = 'membership_expired';

  // Attendance events
  static const attendanceMarked = 'attendance_marked';
  static const bulkAttendanceMarked = 'bulk_attendance_marked';

  // Seat management
  static const seatAssigned = 'seat_assigned';
  static const seatUnassigned = 'seat_unassigned';

  // Invoice events
  static const invoiceGenerated = 'invoice_generated';
  static const invoiceDownloaded = 'invoice_downloaded';
  static const invoiceShared = 'invoice_shared';

  // Payment events
  static const paymentInitiated = 'payment_initiated';
  static const paymentSuccess = 'payment_success';
  static const paymentFailed = 'payment_failed';
  static const paymentRefunded = 'payment_refunded';

  // Utility events
  static const studentUtilityUsed = 'student_utility_used';
  static const bulkImportUsed = 'bulk_import_used';

  // Subscription events
  static const subscriptionPurchased = 'subscription_purchased';
  static const subscriptionCancelled = 'subscription_cancelled';
}

/// Common parameter keys for analytics events.
class AnalyticsParamKeys {
  // User context (auto-included)
  static const userId = 'user_id';
  static const userRole = 'user_role';
  static const libraryId = 'library_id';
  static const platform = 'platform';
  static const timestamp = 'timestamp';

  // Membership
  static const membershipId = 'membership_id';
  static const planType = 'plan_type';
  static const duration = 'duration';
  static const amount = 'amount';

  // Attendance
  static const studentId = 'student_id';
  static const attendanceType = 'attendance_type';
  static const sessionType = 'session_type';
  static const studentCount = 'student_count';

  // Seat
  static const seatNumber = 'seat_number';

  // Invoice
  static const invoiceId = 'invoice_id';
  static const invoiceType = 'invoice_type';
  static const shareMethod = 'share_method';

  // Payment
  static const paymentId = 'payment_id';
  static const paymentMethod = 'payment_method';
  static const failureReason = 'failure_reason';

  // Utility
  static const utilityName = 'utility_name';
  static const importType = 'import_type';
  static const recordCount = 'record_count';
  static const success = 'success';

  // Subscription
  static const subscriptionPlan = 'subscription_plan';
  static const cancellationReason = 'cancellation_reason';
}
