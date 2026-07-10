import 'package:cloud_firestore/cloud_firestore.dart';

/// Data Transfer Object for Membership entity.
class MembershipDto {
  const MembershipDto({
    required this.id,
    required this.libraryId,
    required this.plan,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.phoneNumber,
    this.userId,
    this.studentName,
    this.assignedSeatId,
    this.slot,
    this.slotId,
    this.createdAt,
    this.paymentMethod,
    this.paymentStatus,
    this.paymentBreakdown,
    this.assignedByOwner,
    this.customDurationDays,
    this.customDurationMonths,
  });

  final String id;

  /// User ID - nullable for unregistered members.
  final String? userId;

  /// Student name - optional, used for unregistered students.
  final String? studentName;
  final String libraryId;
  final String plan;
  final Timestamp startDate;
  final Timestamp endDate;
  final String status;

  /// Phone number - always required.
  final String phoneNumber;
  final String? assignedSeatId;
  final String? slot; // 'morning' or 'evening' (legacy)
  final String? slotId; // Custom slot ID
  final Timestamp? createdAt;

  /// Payment method: 'online', 'cash', or 'upi'.
  final String? paymentMethod;

  /// Payment status: 'pending', 'markedPaid', or 'autoPaid'.
  final String? paymentStatus;

  /// Payment breakdown for partial payments.
  /// Map with keys: amountPaid, amountRemaining, notes
  final Map<String, dynamic>? paymentBreakdown;

  /// Whether assigned by owner without student login.
  final bool? assignedByOwner;

  /// Custom duration in days (optional).
  final int? customDurationDays;

  /// Custom duration in months (optional).
  final int? customDurationMonths;

  factory MembershipDto.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return MembershipDto(
      id: doc.id,
      userId: data['userId'] as String?,
      studentName: data['studentName'] as String?,
      libraryId: data['libraryId'] as String,
      plan: data['plan'] as String,
      startDate: data['startDate'] as Timestamp,
      endDate: data['endDate'] as Timestamp,
      status: data['status'] as String,
      phoneNumber: data['phoneNumber'] as String? ?? '',
      assignedSeatId: data['assignedSeatId'] as String?,
      slot: data['slot'] as String?,
      slotId: data['slotId'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      paymentMethod: data['paymentMethod'] as String?,
      paymentStatus: data['paymentStatus'] as String?,
      paymentBreakdown: data['paymentBreakdown'] as Map<String, dynamic>?,
      assignedByOwner: data['assignedByOwner'] as bool? ?? false,
      customDurationDays: data['customDurationDays'] as int?,
      customDurationMonths: data['customDurationMonths'] as int?,
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'libraryId': libraryId,
      'plan': plan,
      'startDate': startDate,
      'endDate': endDate,
      'status': status,
      'phoneNumber': phoneNumber,
      'assignedSeatId': assignedSeatId,
      'slot': slot,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
    // Only include userId if it's not null (for unregistered memberships)
    if (userId != null) {
      map['userId'] = userId;
    }
    if (studentName != null && studentName!.isNotEmpty) {
      map['studentName'] = studentName;
    }
    if (slotId != null) {
      map['slotId'] = slotId;
    }
    if (paymentMethod != null) {
      map['paymentMethod'] = paymentMethod;
    }
    if (paymentStatus != null) {
      map['paymentStatus'] = paymentStatus;
    }
    if (paymentBreakdown != null) {
      map['paymentBreakdown'] = paymentBreakdown;
    }
    if (assignedByOwner == true) {
      map['assignedByOwner'] = assignedByOwner;
    }
    if (customDurationDays != null) {
      map['customDurationDays'] = customDurationDays;
    }
    if (customDurationMonths != null) {
      map['customDurationMonths'] = customDurationMonths;
    }
    return map;
  }

  static const String collectionName = 'memberships';
}
