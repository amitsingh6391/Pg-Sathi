import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/promo_offer.dart';

/// Firestore model for PromoOffer entity
class PromoOfferModel {
  const PromoOfferModel({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.ctaText,
    required this.ctaAction,
    required this.targetAudience,
    required this.displayFrequency,
    required this.priority,
    required this.isActive,
    required this.createdAt,
    this.description,
    this.ctaValue,
    this.startDate,
    this.endDate,
  });

  final String id;
  final String title;
  final String imageUrl;
  final String ctaText;
  final String ctaAction;
  final String? ctaValue;
  final String? description;
  final String targetAudience;
  final String displayFrequency;
  final DateTime? startDate;
  final DateTime? endDate;
  final int priority;
  final bool isActive;
  final DateTime createdAt;

  /// Convert Firestore document to PromoOfferModel
  factory PromoOfferModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return PromoOfferModel(
      id: doc.id,
      title: data['title'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      ctaText: data['ctaText'] as String? ?? 'Continue',
      ctaAction: data['ctaAction'] as String? ?? 'dismiss',
      ctaValue: data['ctaValue'] as String?,
      description: data['description'] as String?,
      targetAudience: data['targetAudience'] as String? ?? 'all',
      displayFrequency: data['displayFrequency'] as String? ?? 'daily',
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      priority: data['priority'] as int? ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert PromoOfferModel to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'imageUrl': imageUrl,
      'ctaText': ctaText,
      'ctaAction': ctaAction,
      'ctaValue': ctaValue,
      'description': description,
      'targetAudience': targetAudience,
      'displayFrequency': displayFrequency,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'priority': priority,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Convert to domain entity
  PromoOffer toEntity() {
    return PromoOffer(
      id: id,
      title: title,
      imageUrl: imageUrl,
      ctaText: ctaText,
      ctaAction: _parseCtaAction(ctaAction),
      ctaValue: ctaValue,
      description: description,
      targetAudience: _parseTargetAudience(targetAudience),
      displayFrequency: _parseDisplayFrequency(displayFrequency),
      startDate: startDate,
      endDate: endDate,
      priority: priority,
      isActive: isActive,
      createdAt: createdAt,
    );
  }

  /// Create from domain entity
  factory PromoOfferModel.fromEntity(PromoOffer entity) {
    return PromoOfferModel(
      id: entity.id,
      title: entity.title,
      imageUrl: entity.imageUrl,
      ctaText: entity.ctaText,
      ctaAction: entity.ctaAction.name,
      ctaValue: entity.ctaValue,
      description: entity.description,
      targetAudience: entity.targetAudience.name,
      displayFrequency: entity.displayFrequency.name,
      startDate: entity.startDate,
      endDate: entity.endDate,
      priority: entity.priority,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
    );
  }

  static PromoCtaAction _parseCtaAction(String value) {
    return PromoCtaAction.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PromoCtaAction.dismiss,
    );
  }

  static PromoTargetAudience _parseTargetAudience(String value) {
    return PromoTargetAudience.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PromoTargetAudience.all,
    );
  }

  static PromoDisplayFrequency _parseDisplayFrequency(String value) {
    return PromoDisplayFrequency.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PromoDisplayFrequency.daily,
    );
  }
}

/// Firestore model for PromoInteraction
class PromoInteractionModel {
  const PromoInteractionModel({
    required this.id,
    required this.promoOfferId,
    required this.ownerId,
    required this.libraryId,
    required this.action,
    required this.timestamp,
  });

  final String id;
  final String promoOfferId;
  final String ownerId;
  final String libraryId;
  final String action;
  final DateTime timestamp;

  /// Convert Firestore document to PromoInteractionModel
  factory PromoInteractionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return PromoInteractionModel(
      id: doc.id,
      promoOfferId: data['promoOfferId'] as String,
      ownerId: data['ownerId'] as String,
      libraryId: data['libraryId'] as String,
      action: data['action'] as String,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'promoOfferId': promoOfferId,
      'ownerId': ownerId,
      'libraryId': libraryId,
      'action': action,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  /// Convert to domain entity
  PromoInteraction toEntity() {
    return PromoInteraction(
      id: id,
      promoOfferId: promoOfferId,
      ownerId: ownerId,
      libraryId: libraryId,
      action: _parseAction(action),
      timestamp: timestamp,
    );
  }

  /// Create from domain entity
  factory PromoInteractionModel.fromEntity(PromoInteraction entity) {
    return PromoInteractionModel(
      id: entity.id,
      promoOfferId: entity.promoOfferId,
      ownerId: entity.ownerId,
      libraryId: entity.libraryId,
      action: entity.action.name,
      timestamp: entity.timestamp,
    );
  }

  static PromoInteractionAction _parseAction(String value) {
    return PromoInteractionAction.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PromoInteractionAction.viewed,
    );
  }
}
