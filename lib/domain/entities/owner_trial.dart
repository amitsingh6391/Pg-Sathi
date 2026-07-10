import 'package:equatable/equatable.dart';

import 'subscription_plan.dart';

/// Represents an owner's trial period.
/// Trial is automatically calculated from account creation date.
class OwnerTrial extends Equatable {
  const OwnerTrial({
    required this.ownerId,
    required this.startDate,
    required this.endDate,
    required this.isUsed,
  });

  final String ownerId;
  final DateTime startDate;
  final DateTime endDate;
  final bool isUsed;

  /// Creates a new trial for an owner based on account creation date.
  factory OwnerTrial.create({
    required String ownerId,
    DateTime? accountCreatedAt,
  }) {
    // Use account creation date if provided, otherwise use now
    final startDate = accountCreatedAt ?? DateTime.now();
    return OwnerTrial(
      ownerId: ownerId,
      startDate: startDate,
      endDate: startDate.add(Duration(days: SubscriptionPlan.trialDays)),
      isUsed: false,
    );
  }

  /// Creates trial from account creation date.
  /// Trial starts from the day owner account was created.
  factory OwnerTrial.fromAccountCreation({
    required String ownerId,
    required DateTime accountCreatedAt,
    bool isUsed = false,
  }) {
    return OwnerTrial(
      ownerId: ownerId,
      startDate: accountCreatedAt,
      endDate: accountCreatedAt.add(Duration(days: SubscriptionPlan.trialDays)),
      isUsed: isUsed,
    );
  }

  /// Checks if trial is active.
  bool isActive(DateTime currentDate) {
    if (isUsed) return false;
    final currentDateOnly = DateTime(
      currentDate.year,
      currentDate.month,
      currentDate.day,
    );
    final startDateOnly = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);
    return !currentDateOnly.isBefore(startDateOnly) &&
        !currentDateOnly.isAfter(endDateOnly);
  }

  /// Checks if trial has expired.
  /// A trial expires only if the current date is AFTER the end date.
  /// If the current date equals the end date, it's still valid for that day.
  bool isExpired(DateTime currentDate) {
    final currentDateOnly = DateTime(
      currentDate.year,
      currentDate.month,
      currentDate.day,
    );
    final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);
    return currentDateOnly.isAfter(endDateOnly);
  }

  /// Days remaining in trial.
  /// Returns negative value if expired (e.g., -3 means expired 3 days ago).
  int daysRemaining(DateTime currentDate) {
    return endDate.difference(currentDate).inDays;
  }

  /// Marks trial as used (when subscription purchased).
  OwnerTrial markUsed() {
    return OwnerTrial(
      ownerId: ownerId,
      startDate: startDate,
      endDate: endDate,
      isUsed: true,
    );
  }

  @override
  List<Object?> get props => [ownerId, startDate, endDate, isUsed];
}
