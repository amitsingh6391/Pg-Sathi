import 'package:equatable/equatable.dart';

/// Represents a tenant's stay and bed allocation in a PG.
class TenantStay extends Equatable {
  const TenantStay({
    required this.id,
    required this.pgPropertyId,
    required this.roomId,
    required this.bedId,
    required this.tenantName,
    required this.phoneNumber,
    required this.startDate,
    required this.monthlyRent,
    this.userId,
    this.expectedCheckoutDate,
    this.actualCheckoutDate,
    this.securityDeposit = 0,
    this.status = TenantStayStatus.pendingPayment,
    this.paymentStatus = TenantPaymentStatus.pending,
    this.createdAt,
  });

  final String id;
  final String pgPropertyId;
  final String roomId;
  final String bedId;
  final String tenantName;
  final String phoneNumber;
  final DateTime startDate;
  final double monthlyRent;
  final String? userId;
  final DateTime? expectedCheckoutDate;
  final DateTime? actualCheckoutDate;
  final double securityDeposit;
  final TenantStayStatus status;
  final TenantPaymentStatus paymentStatus;
  final DateTime? createdAt;

  bool get isUnregistered => userId == null;

  bool isActive(DateTime currentDate) {
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

    return status == TenantStayStatus.active &&
        !currentDateOnly.isBefore(startDateOnly) &&
        actualCheckoutDate == null;
  }

  bool get isPendingPayment => status == TenantStayStatus.pendingPayment;
  bool get isCheckedOut => status == TenantStayStatus.checkedOut;

  TenantStay copyWith({
    String? id,
    String? pgPropertyId,
    String? roomId,
    String? bedId,
    String? tenantName,
    String? phoneNumber,
    DateTime? startDate,
    double? monthlyRent,
    String? userId,
    DateTime? expectedCheckoutDate,
    DateTime? actualCheckoutDate,
    double? securityDeposit,
    TenantStayStatus? status,
    TenantPaymentStatus? paymentStatus,
    DateTime? createdAt,
  }) {
    return TenantStay(
      id: id ?? this.id,
      pgPropertyId: pgPropertyId ?? this.pgPropertyId,
      roomId: roomId ?? this.roomId,
      bedId: bedId ?? this.bedId,
      tenantName: tenantName ?? this.tenantName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      startDate: startDate ?? this.startDate,
      monthlyRent: monthlyRent ?? this.monthlyRent,
      userId: userId ?? this.userId,
      expectedCheckoutDate: expectedCheckoutDate ?? this.expectedCheckoutDate,
      actualCheckoutDate: actualCheckoutDate ?? this.actualCheckoutDate,
      securityDeposit: securityDeposit ?? this.securityDeposit,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  TenantStay activate() {
    return copyWith(
      status: TenantStayStatus.active,
      paymentStatus: TenantPaymentStatus.markedPaid,
    );
  }

  TenantStay checkout(DateTime checkoutDate) {
    return copyWith(
      status: TenantStayStatus.checkedOut,
      actualCheckoutDate: checkoutDate,
    );
  }

  TenantStay cancel() {
    return copyWith(status: TenantStayStatus.cancelled);
  }

  @override
  List<Object?> get props => [
    id,
    pgPropertyId,
    roomId,
    bedId,
    tenantName,
    phoneNumber,
    startDate,
    monthlyRent,
    userId,
    expectedCheckoutDate,
    actualCheckoutDate,
    securityDeposit,
    status,
    paymentStatus,
    createdAt,
  ];
}

enum TenantStayStatus {
  pendingPayment,
  active,
  checkedOut,
  cancelled,
  suspended,
}

enum TenantPaymentStatus { pending, markedPaid, autoPaid }
