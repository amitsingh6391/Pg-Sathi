import 'package:cloud_firestore/cloud_firestore.dart';

/// Data transfer object for Subscription.
class SubscriptionDto {
  const SubscriptionDto({
    required this.id,
    required this.ownerId,
    required this.libraryId,
    required this.seatCount,
    required this.planId,
    required this.baseMonthlyPrice,
    required this.durationInMonths,
    required this.discountPercent,
    required this.finalAmount,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.transactionId,
    this.paymentProofUrl,
    this.couponCode,
    this.couponDiscount,
    this.adminDiscountPercent,
    this.adminDiscountAmount,
    this.markedPaidAt,
    this.approvedAt,
    this.approvedBy,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
    this.isAdminBypassed = false,
    this.adminBypassNote,
  });

  final String id;
  final String ownerId;
  final String libraryId;
  final int seatCount;
  final String planId;
  final double baseMonthlyPrice;
  final int durationInMonths;
  final double discountPercent;
  final double finalAmount;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final String? transactionId;
  final String? paymentProofUrl;
  final String? couponCode;
  final double? couponDiscount;
  final double? adminDiscountPercent;
  final double? adminDiscountAmount;
  final DateTime? markedPaidAt;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isAdminBypassed;
  final String? adminBypassNote;

  factory SubscriptionDto.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SubscriptionDto(
      id: doc.id,
      ownerId: data['ownerId'] as String,
      libraryId: data['libraryId'] as String,
      seatCount: data['seatCount'] as int,
      planId: data['planId'] as String,
      baseMonthlyPrice: (data['baseMonthlyPrice'] as num).toDouble(),
      durationInMonths: data['durationInMonths'] as int,
      discountPercent: (data['discountPercent'] as num).toDouble(),
      finalAmount: (data['finalAmount'] as num).toDouble(),
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      status: data['status'] as String,
      transactionId: data['transactionId'] as String?,
      paymentProofUrl: data['paymentProofUrl'] as String?,
      couponCode: data['couponCode'] as String?,
      couponDiscount: data['couponDiscount'] != null
          ? (data['couponDiscount'] as num).toDouble()
          : null,
      adminDiscountPercent: data['adminDiscountPercent'] != null
          ? (data['adminDiscountPercent'] as num).toDouble()
          : null,
      adminDiscountAmount: data['adminDiscountAmount'] != null
          ? (data['adminDiscountAmount'] as num).toDouble()
          : null,
      markedPaidAt: data['markedPaidAt'] != null
          ? (data['markedPaidAt'] as Timestamp).toDate()
          : null,
      approvedAt: data['approvedAt'] != null
          ? (data['approvedAt'] as Timestamp).toDate()
          : null,
      approvedBy: data['approvedBy'] as String?,
      rejectionReason: data['rejectionReason'] as String?,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      isAdminBypassed: data['isAdminBypassed'] as bool? ?? false,
      adminBypassNote: data['adminBypassNote'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'libraryId': libraryId,
      'seatCount': seatCount,
      'planId': planId,
      'baseMonthlyPrice': baseMonthlyPrice,
      'durationInMonths': durationInMonths,
      'discountPercent': discountPercent,
      'finalAmount': finalAmount,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'status': status,
      'transactionId': transactionId,
      'paymentProofUrl': paymentProofUrl,
      'couponCode': couponCode,
      'couponDiscount': couponDiscount,
      'adminDiscountPercent': adminDiscountPercent,
      'adminDiscountAmount': adminDiscountAmount,
      'markedPaidAt': markedPaidAt != null
          ? Timestamp.fromDate(markedPaidAt!)
          : null,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'approvedBy': approvedBy,
      'rejectionReason': rejectionReason,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
      'isAdminBypassed': isAdminBypassed,
      'adminBypassNote': adminBypassNote,
    };
  }
}

/// Data transfer object for OwnerTrial.
class OwnerTrialDto {
  const OwnerTrialDto({
    required this.ownerId,
    required this.startDate,
    required this.endDate,
    required this.isUsed,
  });

  final String ownerId;
  final DateTime startDate;
  final DateTime endDate;
  final bool isUsed;

  factory OwnerTrialDto.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OwnerTrialDto(
      ownerId: doc.id,
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      isUsed: data['isUsed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isUsed': isUsed,
    };
  }
}
