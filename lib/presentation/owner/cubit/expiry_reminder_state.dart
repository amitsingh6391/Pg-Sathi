import 'package:equatable/equatable.dart';

import '../../../domain/entities/membership.dart';
import '../../../domain/entities/user.dart';

/// State for expiry reminder cubit.
class ExpiryReminderState extends Equatable {
  const ExpiryReminderState({
    this.status = ExpiryReminderStatus.initial,
    this.expiringMemberships = const [],
    this.selectedStudentIds = const {},
    this.daysThreshold = 7,
    this.errorMessage,
    this.lastSentReminder = const {},
  });

  final ExpiryReminderStatus status;
  final List<ExpiringMembershipInfo> expiringMemberships;
  final Set<String> selectedStudentIds;
  final int daysThreshold;
  final String? errorMessage;

  /// Map of userId -> last sent timestamp (for 24h cooldown)
  final Map<String, DateTime> lastSentReminder;

  bool get isLoading => status == ExpiryReminderStatus.loading;
  bool get isSuccess => status == ExpiryReminderStatus.success;
  bool get isError => status == ExpiryReminderStatus.error;
  bool get isEmpty => expiringMemberships.isEmpty;
  bool get hasSelection => selectedStudentIds.isNotEmpty;

  /// Get unique user IDs from registered expiring memberships
  Set<String> get _uniqueUserIds => expiringMemberships
      .where((info) => info.isRegistered)
      .map((info) => info.membership.userId!)
      .toSet();

  bool get isAllSelected =>
      expiringMemberships.isNotEmpty &&
      _uniqueUserIds.isNotEmpty &&
      selectedStudentIds.length >= _uniqueUserIds.length;

  /// Check if user can send reminder (24h cooldown)
  bool canSendReminder(String userId) {
    final lastSent = lastSentReminder[userId];
    if (lastSent == null) return true;
    final now = DateTime.now();
    return now.difference(lastSent).inHours >= 24;
  }

  ExpiryReminderState copyWith({
    ExpiryReminderStatus? status,
    List<ExpiringMembershipInfo>? expiringMemberships,
    Set<String>? selectedStudentIds,
    int? daysThreshold,
    String? errorMessage,
    Map<String, DateTime>? lastSentReminder,
    bool clearError = false,
    bool clearSelection = false,
  }) {
    return ExpiryReminderState(
      status: status ?? this.status,
      expiringMemberships: expiringMemberships ?? this.expiringMemberships,
      selectedStudentIds: clearSelection
          ? <String>{}
          : (selectedStudentIds ?? this.selectedStudentIds),
      daysThreshold: daysThreshold ?? this.daysThreshold,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastSentReminder: lastSentReminder ?? this.lastSentReminder,
    );
  }

  @override
  List<Object?> get props => [
    status,
    expiringMemberships,
    selectedStudentIds,
    daysThreshold,
    errorMessage,
    lastSentReminder,
  ];
}

/// Status for expiry reminder operations.
enum ExpiryReminderStatus { initial, loading, success, error }

/// Information about an expiring membership with user details.
/// User is optional to support unregistered memberships.
class ExpiringMembershipInfo extends Equatable {
  const ExpiringMembershipInfo({
    required this.membership,
    this.user,
    required this.daysRemaining,
  });

  final Membership membership;
  final User? user;
  final int daysRemaining;

  /// Whether this membership is registered (has userId and user exists).
  bool get isRegistered => membership.userId != null && user != null;

  /// Display name for the membership (from user or membership).
  String get displayName => user?.displayName ?? membership.studentName ?? membership.phoneNumber;

  /// Phone number for the membership (from user or membership).
  String get phone => user?.phone ?? membership.phoneNumber;

  @override
  List<Object?> get props => [membership, user, daysRemaining];
}
