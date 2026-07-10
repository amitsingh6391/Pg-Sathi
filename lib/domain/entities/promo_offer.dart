import 'package:equatable/equatable.dart';

/// Represents a promotional offer displayed to library owners.
/// Managed by admin via Firestore, shown as fullscreen popup on dashboard.
class PromoOffer extends Equatable {
  const PromoOffer({
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

  /// Full promotional image URL (Firebase Storage or CDN)
  final String imageUrl;

  /// Call-to-action button text (e.g., "I'm Interested", "Get 30% Off")
  final String ctaText;

  final PromoCtaAction ctaAction;
  final String? ctaValue;
  final String? description;
  final PromoTargetAudience targetAudience;
  final PromoDisplayFrequency displayFrequency;

  /// When to start showing (null = immediately)
  final DateTime? startDate;

  /// When to stop showing (null = never expires)
  final DateTime? endDate;

  final int priority;
  final bool isActive;
  final DateTime createdAt;

  /// Check if promo is currently valid to display
  bool get isValidForDisplay {
    if (!isActive) return false;
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }

  @override
  List<Object?> get props => [
        id,
        title,
        imageUrl,
        ctaText,
        ctaAction,
        ctaValue,
        description,
        targetAudience,
        displayFrequency,
        startDate,
        endDate,
        priority,
        isActive,
        createdAt,
      ];
}

/// Action types for promo CTA button
enum PromoCtaAction {
  /// Open WhatsApp with pre-filled message
  whatsapp,

  /// Open external URL in browser
  link,

  /// Navigate to in-app screen
  screen,

  /// Just dismiss (for announcement-only promos)
  dismiss,
}

/// Target audience for promo offers
enum PromoTargetAudience {
  /// All users (owners + students)
  all,

  /// All library owners only
  allOwners,

  /// All students only
  allStudents,

  /// Only free tier owners (0-7 seats, no subscription)
  freeTier,

  /// Only owners with active paid subscription
  paid,

  /// Owners with expired subscription
  expired,

  /// Owners pending subscription verification
  pendingVerification,

  /// New owners (registered within last 7 days)
  newOwners,

  /// Students with active membership
  activeMembership,

  /// Students with expired membership
  expiredMembership,

  /// Students with no membership
  noMembership,
}

/// How frequently to display the promo
enum PromoDisplayFrequency {
  /// Show once ever per owner
  once,

  /// Show once per day
  daily,

  /// Show every session (app open)
  session,
}

/// Represents an interaction with a promo offer
class PromoInteraction extends Equatable {
  const PromoInteraction({
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
  final PromoInteractionAction action;
  final DateTime timestamp;

  @override
  List<Object?> get props => [
        id,
        promoOfferId,
        ownerId,
        libraryId,
        action,
        timestamp,
      ];
}

/// Types of interactions with a promo
enum PromoInteractionAction {
  /// Owner saw the promo
  viewed,

  /// Owner dismissed without clicking CTA
  dismissed,

  /// Owner clicked the CTA button
  clicked,
}
