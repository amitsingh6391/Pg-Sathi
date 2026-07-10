import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../../core/services/analytics_service.dart';

/// Firebase implementation of AnalyticsService.
class AnalyticsServiceImpl implements AnalyticsService {
  AnalyticsServiceImpl({
    required this.analytics,
    required this.firestore,
  });

  final FirebaseAnalytics analytics;
  final FirebaseFirestore firestore;

  // User context cache
  String? _userId;
  String? _userRole;
  String? _libraryId;

  @override
  Future<void> setUserContext({
    required String userId,
    required String userRole,
    String? libraryId,
  }) async {
    try {
      _userId = userId;
      _userRole = userRole;
      _libraryId = libraryId;

      // Set Firebase user properties
      await analytics.setUserId(id: userId);
      await analytics.setUserProperty(name: 'user_role', value: userRole);
      if (libraryId != null) {
        await analytics.setUserProperty(name: 'library_id', value: libraryId);
      }

      debugPrint('📊 Analytics: User context set - $userId ($userRole)');
    } catch (e, stackTrace) {
      debugPrint('❌ Analytics: Failed to set user context: $e');
      debugPrint(stackTrace.toString());
    }
  }

  @override
  Future<void> clearUserContext() async {
    try {
      _userId = null;
      _userRole = null;
      _libraryId = null;

      await analytics.setUserId(id: null);
      
      debugPrint('📊 Analytics: User context cleared');
    } catch (e, stackTrace) {
      debugPrint('❌ Analytics: Failed to clear user context: $e');
      debugPrint(stackTrace.toString());
    }
  }

  @override
  Future<void> trackEvent(
    String eventName, {
    Map<String, dynamic>? parameters,
  }) async {
    try {
      final enrichedParams = _enrichParameters(parameters ?? {});
      
      // Firebase Analytics has a 100-character limit for event names
      final sanitizedEventName = _sanitizeEventName(eventName);
      
      // Convert dynamic values to Object for Firebase Analytics
      final sanitizedParams = enrichedParams.map(
        (key, value) => MapEntry(key, value as Object),
      );
      
      // Log to Firebase Analytics
      await analytics.logEvent(
        name: sanitizedEventName,
        parameters: sanitizedParams,
      );

      // Also write to Firestore for dashboard access
      await _writeToFirestore(sanitizedEventName, enrichedParams);

      debugPrint('📊 Analytics: Event tracked - $sanitizedEventName');
    } catch (e, stackTrace) {
      debugPrint('❌ Analytics: Failed to track event "$eventName": $e');
      debugPrint(stackTrace.toString());
    }
  }

  /// Write analytics event to Firestore for dashboard queries.
  Future<void> _writeToFirestore(
    String eventName,
    Map<String, dynamic> parameters,
  ) async {
    try {
      await firestore.collection('analytics_events').add({
        'event_name': eventName,
        'user_id': _userId,
        'role': _userRole,
        'library_id': _libraryId,
        'platform': _getPlatform(),
        'parameters': parameters,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Silently fail - don't break analytics if Firestore write fails
      debugPrint('⚠️ Analytics: Failed to write to Firestore: $e');
    }
  }

  // ============================================
  // MEMBERSHIP EVENTS
  // ============================================

  @override
  Future<void> trackMembershipCreated({
    required String membershipId,
    required String planType,
    required String duration,
    required double amount,
    Map<String, dynamic>? additionalParams,
  }) async {
    await trackEvent(
      AnalyticsEventNames.membershipCreated,
      parameters: {
        AnalyticsParamKeys.membershipId: membershipId,
        AnalyticsParamKeys.planType: planType,
        AnalyticsParamKeys.duration: duration,
        AnalyticsParamKeys.amount: amount,
        ...?additionalParams,
      },
    );
  }

  @override
  Future<void> trackMembershipRenewed({
    required String membershipId,
    required String planType,
    required String duration,
    required double amount,
    Map<String, dynamic>? additionalParams,
  }) async {
    await trackEvent(
      AnalyticsEventNames.membershipRenewed,
      parameters: {
        AnalyticsParamKeys.membershipId: membershipId,
        AnalyticsParamKeys.planType: planType,
        AnalyticsParamKeys.duration: duration,
        AnalyticsParamKeys.amount: amount,
        ...?additionalParams,
      },
    );
  }

  // ============================================
  // ATTENDANCE EVENTS
  // ============================================

  @override
  Future<void> trackAttendanceMarked({
    required String studentId,
    required String attendanceType,
    required String sessionType,
    Map<String, dynamic>? additionalParams,
  }) async {
    await trackEvent(
      AnalyticsEventNames.attendanceMarked,
      parameters: {
        AnalyticsParamKeys.studentId: studentId,
        AnalyticsParamKeys.attendanceType: attendanceType,
        AnalyticsParamKeys.sessionType: sessionType,
        ...?additionalParams,
      },
    );
  }

  @override
  Future<void> trackBulkAttendanceMarked({
    required int studentCount,
    required String attendanceType,
    Map<String, dynamic>? additionalParams,
  }) async {
    await trackEvent(
      AnalyticsEventNames.bulkAttendanceMarked,
      parameters: {
        AnalyticsParamKeys.studentCount: studentCount,
        AnalyticsParamKeys.attendanceType: attendanceType,
        ...?additionalParams,
      },
    );
  }

  // ============================================
  // SEAT MANAGEMENT EVENTS
  // ============================================

  @override
  Future<void> trackSeatAssigned({
    required String seatNumber,
    required String studentId,
    Map<String, dynamic>? additionalParams,
  }) async {
    await trackEvent(
      AnalyticsEventNames.seatAssigned,
      parameters: {
        AnalyticsParamKeys.seatNumber: seatNumber,
        AnalyticsParamKeys.studentId: studentId,
        ...?additionalParams,
      },
    );
  }

  @override
  Future<void> trackSeatUnassigned({
    required String seatNumber,
    required String studentId,
    Map<String, dynamic>? additionalParams,
  }) async {
    await trackEvent(
      AnalyticsEventNames.seatUnassigned,
      parameters: {
        AnalyticsParamKeys.seatNumber: seatNumber,
        AnalyticsParamKeys.studentId: studentId,
        ...?additionalParams,
      },
    );
  }

  // ============================================
  // INVOICE EVENTS
  // ============================================

  @override
  Future<void> trackInvoiceGenerated({
    required String invoiceId,
    required String invoiceType,
    required double amount,
    Map<String, dynamic>? additionalParams,
  }) async {
    await trackEvent(
      AnalyticsEventNames.invoiceGenerated,
      parameters: {
        AnalyticsParamKeys.invoiceId: invoiceId,
        AnalyticsParamKeys.invoiceType: invoiceType,
        AnalyticsParamKeys.amount: amount,
        ...?additionalParams,
      },
    );
  }

  @override
  Future<void> trackInvoiceDownloaded({
    required String invoiceId,
    required String invoiceType,
    Map<String, dynamic>? additionalParams,
  }) async {
    await trackEvent(
      AnalyticsEventNames.invoiceDownloaded,
      parameters: {
        AnalyticsParamKeys.invoiceId: invoiceId,
        AnalyticsParamKeys.invoiceType: invoiceType,
        ...?additionalParams,
      },
    );
  }

  @override
  Future<void> trackInvoiceShared({
    required String invoiceId,
    required String invoiceType,
    required String shareMethod,
    Map<String, dynamic>? additionalParams,
  }) async {
    await trackEvent(
      AnalyticsEventNames.invoiceShared,
      parameters: {
        AnalyticsParamKeys.invoiceId: invoiceId,
        AnalyticsParamKeys.invoiceType: invoiceType,
        AnalyticsParamKeys.shareMethod: shareMethod,
        ...?additionalParams,
      },
    );
  }

  // ============================================
  // PAYMENT EVENTS
  // ============================================

  @override
  Future<void> trackPaymentFailed({
    required String paymentId,
    required String paymentMethod,
    required double amount,
    required String failureReason,
    Map<String, dynamic>? additionalParams,
  }) async {
    await trackEvent(
      AnalyticsEventNames.paymentFailed,
      parameters: {
        AnalyticsParamKeys.paymentId: paymentId,
        AnalyticsParamKeys.paymentMethod: paymentMethod,
        AnalyticsParamKeys.amount: amount,
        AnalyticsParamKeys.failureReason: failureReason,
        ...?additionalParams,
      },
    );
  }

  @override
  Future<void> trackPaymentRefunded({
    required String paymentId,
    required String paymentMethod,
    required double amount,
    required String reason,
    Map<String, dynamic>? additionalParams,
  }) async {
    await trackEvent(
      AnalyticsEventNames.paymentRefunded,
      parameters: {
        AnalyticsParamKeys.paymentId: paymentId,
        AnalyticsParamKeys.paymentMethod: paymentMethod,
        AnalyticsParamKeys.amount: amount,
        'refund_reason': reason,
        ...?additionalParams,
      },
    );
  }

  // ============================================
  // UTILITY/TOOL EVENTS
  // ============================================

  @override
  Future<void> trackStudentUtilityUsed({
    required String utilityName,
    Map<String, dynamic>? additionalParams,
  }) async {
    await trackEvent(
      AnalyticsEventNames.studentUtilityUsed,
      parameters: {
        AnalyticsParamKeys.utilityName: utilityName,
        ...?additionalParams,
      },
    );
  }

  @override
  Future<void> trackBulkImportUsed({
    required String importType,
    required int recordCount,
    required bool success,
    Map<String, dynamic>? additionalParams,
  }) async {
    await trackEvent(
      AnalyticsEventNames.bulkImportUsed,
      parameters: {
        AnalyticsParamKeys.importType: importType,
        AnalyticsParamKeys.recordCount: recordCount,
        AnalyticsParamKeys.success: success,
        ...?additionalParams,
      },
    );
  }

  // ============================================
  // SUBSCRIPTION EVENTS
  // ============================================

  @override
  Future<void> trackSubscriptionPurchased({
    required String subscriptionPlan,
    required double amount,
    required String duration,
    Map<String, dynamic>? additionalParams,
  }) async {
    await trackEvent(
      AnalyticsEventNames.subscriptionPurchased,
      parameters: {
        AnalyticsParamKeys.subscriptionPlan: subscriptionPlan,
        AnalyticsParamKeys.amount: amount,
        AnalyticsParamKeys.duration: duration,
        ...?additionalParams,
      },
    );
  }

  @override
  Future<void> trackSubscriptionCancelled({
    required String subscriptionPlan,
    required String cancellationReason,
    Map<String, dynamic>? additionalParams,
  }) async {
    await trackEvent(
      AnalyticsEventNames.subscriptionCancelled,
      parameters: {
        AnalyticsParamKeys.subscriptionPlan: subscriptionPlan,
        AnalyticsParamKeys.cancellationReason: cancellationReason,
        ...?additionalParams,
      },
    );
  }

  // ============================================
  // PRIVATE HELPER METHODS
  // ============================================

  /// Enriches parameters with user context and platform info.
  Map<String, dynamic> _enrichParameters(Map<String, dynamic> params) {
    return {
      ...params,
      if (_userId != null) AnalyticsParamKeys.userId: _userId!,
      if (_userRole != null) AnalyticsParamKeys.userRole: _userRole!,
      if (_libraryId != null) AnalyticsParamKeys.libraryId: _libraryId!,
      AnalyticsParamKeys.platform: _getPlatform(),
      AnalyticsParamKeys.timestamp: DateTime.now().toIso8601String(),
    };
  }

  /// Gets current platform name.
  String _getPlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  /// Sanitizes event name to meet Firebase Analytics requirements.
  /// - Max 40 characters
  /// - Alphanumeric and underscores only
  String _sanitizeEventName(String eventName) {
    // Replace spaces and special chars with underscores
    var sanitized = eventName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_'); // Remove multiple underscores

    // Trim to 40 characters (Firebase limit)
    if (sanitized.length > 40) {
      sanitized = sanitized.substring(0, 40);
    }

    return sanitized;
  }
}
