import 'package:equatable/equatable.dart';

/// Represents an admin action that can be performed on a library.
class AdminAction extends Equatable {
  const AdminAction({
    required this.id,
    required this.type,
    required this.libraryId,
    required this.libraryName,
    required this.performedBy,
    required this.performedAt,
    required this.details,
    this.reason,
    this.previousValue,
    this.newValue,
  });

  final String id;
  final AdminActionType type;
  final String libraryId;
  final String libraryName;
  final String performedBy; // Admin user ID
  final DateTime performedAt;
  final String details;
  final String? reason;
  final String? previousValue;
  final String? newValue;

  @override
  List<Object?> get props => [
    id,
    type,
    libraryId,
    libraryName,
    performedBy,
    performedAt,
    details,
    reason,
    previousValue,
    newValue,
  ];
}

/// Types of admin actions.
enum AdminActionType {
  suspendLibrary,
  unsuspendLibrary,
  extendTrial,
  applyDiscount,
  removeDiscount,
  manualPayment,
  sendNotification,
  applyRetentionOffer,
  addNote,
  updatePricing;

  String get label {
    switch (this) {
      case AdminActionType.suspendLibrary:
        return 'Suspend Library';
      case AdminActionType.unsuspendLibrary:
        return 'Unsuspend Library';
      case AdminActionType.extendTrial:
        return 'Extend Trial';
      case AdminActionType.applyDiscount:
        return 'Apply Discount';
      case AdminActionType.removeDiscount:
        return 'Remove Discount';
      case AdminActionType.manualPayment:
        return 'Manual Payment';
      case AdminActionType.sendNotification:
        return 'Send Notification';
      case AdminActionType.applyRetentionOffer:
        return 'Apply Retention Offer';
      case AdminActionType.addNote:
        return 'Add Note';
      case AdminActionType.updatePricing:
        return 'Update Pricing';
    }
  }

  String get icon {
    switch (this) {
      case AdminActionType.suspendLibrary:
        return '🚫';
      case AdminActionType.unsuspendLibrary:
        return '✅';
      case AdminActionType.extendTrial:
        return '⏰';
      case AdminActionType.applyDiscount:
        return '💰';
      case AdminActionType.removeDiscount:
        return '🚫';
      case AdminActionType.manualPayment:
        return '💳';
      case AdminActionType.sendNotification:
        return '📢';
      case AdminActionType.applyRetentionOffer:
        return '🎁';
      case AdminActionType.addNote:
        return '📝';
      case AdminActionType.updatePricing:
        return '💲';
    }
  }
}

/// Request to suspend a library.
class SuspendLibraryRequest extends Equatable {
  const SuspendLibraryRequest({
    required this.libraryId,
    required this.reason,
    required this.adminId,
  });

  final String libraryId;
  final String reason;
  final String adminId;

  @override
  List<Object?> get props => [libraryId, reason, adminId];
}

/// Request to extend a library's trial period.
class ExtendTrialRequest extends Equatable {
  const ExtendTrialRequest({
    required this.libraryId,
    required this.extensionDays,
    required this.reason,
    required this.adminId,
  });

  final String libraryId;
  final int extensionDays; // Max 7 days
  final String reason;
  final String adminId;

  @override
  List<Object?> get props => [libraryId, extensionDays, reason, adminId];
}

/// Request to apply a custom discount.
class ApplyDiscountRequest extends Equatable {
  const ApplyDiscountRequest({
    required this.libraryId,
    required this.discountPercent,
    required this.validUntil,
    required this.reason,
    required this.adminId,
  });

  final String libraryId;
  final double discountPercent;
  final DateTime validUntil;
  final String reason;
  final String adminId;

  @override
  List<Object?> get props => [
    libraryId,
    discountPercent,
    validUntil,
    reason,
    adminId,
  ];
}

/// Request to remove discount from a library.
class RemoveDiscountRequest extends Equatable {
  const RemoveDiscountRequest({
    required this.libraryId,
    required this.adminId,
    required this.reason,
  });

  final String libraryId;
  final String adminId;
  final String reason;

  @override
  List<Object?> get props => [libraryId, adminId, reason];
}

/// Request to mark payment as received manually.
class ManualPaymentRequest extends Equatable {
  const ManualPaymentRequest({
    required this.subscriptionId,
    required this.amount,
    required this.paymentMethod,
    required this.transactionId,
    required this.notes,
    required this.adminId,
  });

  final String subscriptionId;
  final double amount;
  final String paymentMethod;
  final String transactionId;
  final String notes;
  final String adminId;

  @override
  List<Object?> get props => [
    subscriptionId,
    amount,
    paymentMethod,
    transactionId,
    notes,
    adminId,
  ];
}

/// Library suspension status.
class LibrarySuspensionStatus extends Equatable {
  const LibrarySuspensionStatus({
    required this.libraryId,
    required this.isSuspended,
    this.suspendedAt,
    this.suspendedBy,
    this.suspensionReason,
  });

  final String libraryId;
  final bool isSuspended;
  final DateTime? suspendedAt;
  final String? suspendedBy;
  final String? suspensionReason;

  @override
  List<Object?> get props => [
    libraryId,
    isSuspended,
    suspendedAt,
    suspendedBy,
    suspensionReason,
  ];
}
