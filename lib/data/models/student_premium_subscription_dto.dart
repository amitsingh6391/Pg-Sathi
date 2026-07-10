import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/student_premium_subscription.dart';

/// Firestore (de)serialization for [StudentPremiumSubscription].
class StudentPremiumSubscriptionModel {
  const StudentPremiumSubscriptionModel({
    required this.id,
    required this.userId,
    required this.plan,
    required this.amountPaise,
    required this.startedAt,
    required this.validTill,
    required this.isActive,
    required this.createdAt,
    this.paymentId,
    this.paymentProvider,
    this.cancelledAt,
  });

  final String id;
  final String userId;
  final String plan;
  final int amountPaise;
  final DateTime startedAt;
  final DateTime validTill;
  final bool isActive;
  final DateTime createdAt;
  final String? paymentId;
  final String? paymentProvider;
  final DateTime? cancelledAt;

  factory StudentPremiumSubscriptionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return StudentPremiumSubscriptionModel(
      id: doc.id,
      userId: (data['userId'] as String?) ?? '',
      plan: (data['plan'] as String?) ?? 'monthly',
      amountPaise: (data['amountPaise'] as int?) ?? 0,
      startedAt:
          (data['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      validTill:
          (data['validTill'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: (data['isActive'] as bool?) ?? false,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paymentId: data['paymentId'] as String?,
      paymentProvider: data['paymentProvider'] as String?,
      cancelledAt: (data['cancelledAt'] as Timestamp?)?.toDate(),
    );
  }

  factory StudentPremiumSubscriptionModel.fromEntity(
    StudentPremiumSubscription entity,
  ) {
    return StudentPremiumSubscriptionModel(
      id: entity.id,
      userId: entity.userId,
      plan: entity.plan.name,
      amountPaise: entity.amountPaise,
      startedAt: entity.startedAt,
      validTill: entity.validTill,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      paymentId: entity.paymentId,
      paymentProvider: entity.paymentProvider,
      cancelledAt: entity.cancelledAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'plan': plan,
      'amountPaise': amountPaise,
      'startedAt': Timestamp.fromDate(startedAt),
      'validTill': Timestamp.fromDate(validTill),
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'paymentId': paymentId,
      'paymentProvider': paymentProvider,
      'cancelledAt':
          cancelledAt == null ? null : Timestamp.fromDate(cancelledAt!),
    };
  }

  StudentPremiumSubscription toEntity() {
    return StudentPremiumSubscription(
      id: id,
      userId: userId,
      plan: _parsePlan(plan),
      amountPaise: amountPaise,
      startedAt: startedAt,
      validTill: validTill,
      isActive: isActive,
      createdAt: createdAt,
      paymentId: paymentId,
      paymentProvider: paymentProvider,
      cancelledAt: cancelledAt,
    );
  }

  static StudentPremiumPlan _parsePlan(String value) {
    return StudentPremiumPlan.values.firstWhere(
      (e) => e.name == value,
      orElse: () => StudentPremiumPlan.monthly,
    );
  }
}
