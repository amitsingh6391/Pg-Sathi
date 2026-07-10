import 'package:equatable/equatable.dart';

/// An auto-generated admin alert.
class AdminAlert extends Equatable {
  const AdminAlert({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
    this.libraryId,
    this.libraryName,
    this.metadata,
    this.actionUrl,
  });

  final String id;
  final AlertType type;
  final AlertSeverity severity;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String? libraryId;
  final String? libraryName;
  final Map<String, dynamic>? metadata;
  final String? actionUrl;

  /// Check if alert is recent (within last 24 hours).
  bool get isRecent {
    return DateTime.now().difference(createdAt).inHours < 24;
  }

  /// Formatted time ago.
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  @override
  List<Object?> get props => [
    id,
    type,
    severity,
    title,
    message,
    createdAt,
    isRead,
    libraryId,
    libraryName,
    metadata,
    actionUrl,
  ];

  AdminAlert copyWith({
    String? id,
    AlertType? type,
    AlertSeverity? severity,
    String? title,
    String? message,
    DateTime? createdAt,
    bool? isRead,
    String? libraryId,
    String? libraryName,
    Map<String, dynamic>? metadata,
    String? actionUrl,
  }) {
    return AdminAlert(
      id: id ?? this.id,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      libraryId: libraryId ?? this.libraryId,
      libraryName: libraryName ?? this.libraryName,
      metadata: metadata ?? this.metadata,
      actionUrl: actionUrl ?? this.actionUrl,
    );
  }
}

/// Types of admin alerts.
enum AlertType {
  seatLimitBreach,
  paymentFailure,
  dauDrop,
  wauDrop,
  ownerInactivity,
  renewalSoon,
  trialExpiring,
  suspiciousActivity,
  systemHealth;

  String get label {
    switch (this) {
      case AlertType.seatLimitBreach:
        return 'Seat Limit Breach';
      case AlertType.paymentFailure:
        return 'Payment Failure';
      case AlertType.dauDrop:
        return 'DAU Drop';
      case AlertType.wauDrop:
        return 'WAU Drop';
      case AlertType.ownerInactivity:
        return 'Owner Inactivity';
      case AlertType.renewalSoon:
        return 'Renewal Soon';
      case AlertType.trialExpiring:
        return 'Trial Expiring';
      case AlertType.suspiciousActivity:
        return 'Suspicious Activity';
      case AlertType.systemHealth:
        return 'System Health';
    }
  }

  String get icon {
    switch (this) {
      case AlertType.seatLimitBreach:
        return '⚠️';
      case AlertType.paymentFailure:
        return '❌';
      case AlertType.dauDrop:
        return '📉';
      case AlertType.wauDrop:
        return '📊';
      case AlertType.ownerInactivity:
        return '💤';
      case AlertType.renewalSoon:
        return '🔔';
      case AlertType.trialExpiring:
        return '⏰';
      case AlertType.suspiciousActivity:
        return '🚨';
      case AlertType.systemHealth:
        return '🔧';
    }
  }
}

/// Severity levels for alerts.
enum AlertSeverity {
  info,
  warning,
  critical;

  String get label {
    switch (this) {
      case AlertSeverity.info:
        return 'Info';
      case AlertSeverity.warning:
        return 'Warning';
      case AlertSeverity.critical:
        return 'Critical';
    }
  }
}

/// Summary of admin alerts.
class AlertsSummary extends Equatable {
  const AlertsSummary({
    required this.totalUnread,
    required this.criticalCount,
    required this.warningCount,
    required this.infoCount,
    required this.recentAlerts,
  });

  const AlertsSummary.empty()
    : totalUnread = 0,
      criticalCount = 0,
      warningCount = 0,
      infoCount = 0,
      recentAlerts = const [];

  final int totalUnread;
  final int criticalCount;
  final int warningCount;
  final int infoCount;
  final List<AdminAlert> recentAlerts;

  bool get hasCritical => criticalCount > 0;
  bool get hasWarning => warningCount > 0;

  @override
  List<Object?> get props => [
    totalUnread,
    criticalCount,
    warningCount,
    infoCount,
    recentAlerts,
  ];
}
