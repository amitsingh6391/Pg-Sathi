import 'package:equatable/equatable.dart';

class WhatsAppCredits extends Equatable {
  const WhatsAppCredits({
    required this.ownerId,
    required this.totalCredits,
    required this.usedCredits,
    this.updatedAt,
  });

  /// Free credits granted to every owner before they need to buy any.
  static const int freeCredits = 7;

  final String ownerId;
  final int totalCredits;
  final int usedCredits;
  final DateTime? updatedAt;

  /// Wallet for an owner who has never been seeded yet — shows the free grant.
  factory WhatsAppCredits.initial(String ownerId) => WhatsAppCredits(
        ownerId: ownerId,
        totalCredits: freeCredits,
        usedCredits: 0,
      );

  /// Remaining credits the owner can still spend (never negative).
  int get availableCredits {
    final remaining = totalCredits - usedCredits;
    return remaining > 0 ? remaining : 0;
  }

  bool get hasCredits => availableCredits > 0;
  bool get isEmpty => availableCredits <= 0;

  WhatsAppCredits copyWith({
    String? ownerId,
    int? totalCredits,
    int? usedCredits,
    DateTime? updatedAt,
  }) {
    return WhatsAppCredits(
      ownerId: ownerId ?? this.ownerId,
      totalCredits: totalCredits ?? this.totalCredits,
      usedCredits: usedCredits ?? this.usedCredits,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [ownerId, totalCredits, usedCredits, updatedAt];
}

/// A purchasable pack of WhatsApp credits.
class WhatsAppCreditPack extends Equatable {
  const WhatsAppCreditPack({
    required this.id,
    required this.credits,
    required this.price,
    this.label,
  });

  /// Unique pack id (used as the planId on the purchase record).
  final String id;

  /// Number of credits added to the wallet on purchase.
  final int credits;

  /// Price in INR (before any payment-gateway charge).
  final double price;

  /// Optional marketing label (e.g. "Best value").
  final String? label;

  /// Per-message cost shown to the owner, e.g. "₹0.20/msg".
  double get perMessagePaise => (price / credits) * 100;

  /// Available credit packs (≈20 paise/credit with small bulk bonuses).
  static const List<WhatsAppCreditPack> packs = [
    WhatsAppCreditPack(id: 'wa_pack_49', credits: 250, price: 49),
    WhatsAppCreditPack(
      id: 'wa_pack_99',
      credits: 550,
      price: 99,
      label: 'Popular',
    ),
    WhatsAppCreditPack(
      id: 'wa_pack_199',
      credits: 1200,
      price: 199,
      label: 'Best value',
    ),
  ];

  /// Free credit pack granted when an owner buys a subscription plan:
  /// 1 month → ₹49 pack, 3 months → ₹99 pack, 6/12 months → ₹199 pack.
  static WhatsAppCreditPack? bonusForSubscriptionMonths(int months) {
    if (months >= 6) return byId('wa_pack_199');
    if (months >= 3) return byId('wa_pack_99');
    if (months >= 1) return byId('wa_pack_49');
    return null;
  }

  static WhatsAppCreditPack? byId(String id) {
    for (final p in packs) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  List<Object?> get props => [id, credits, price, label];
}
