import 'package:equatable/equatable.dart';

/// Represents a discount coupon for subscriptions.
class Coupon extends Equatable {
  const Coupon({
    required this.code,
    required this.discountPercent,
    required this.isActive,
    this.description,
    this.maxUses,
    this.currentUses = 0,
    this.validFrom,
    this.validUntil,
    this.createdAt,
  });

  final String code;
  final double discountPercent;
  final bool isActive;
  final String? description;
  final int? maxUses;
  final int currentUses;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final DateTime? createdAt;

  /// Checks if coupon is valid for use.
  bool isValid(DateTime currentDate) {
    if (!isActive) return false;

    if (validFrom != null && currentDate.isBefore(validFrom!)) {
      return false;
    }

    if (validUntil != null && currentDate.isAfter(validUntil!)) {
      return false;
    }

    if (maxUses != null && currentUses >= maxUses!) {
      return false;
    }

    return true;
  }

  @override
  List<Object?> get props => [
    code,
    discountPercent,
    isActive,
    description,
    maxUses,
    currentUses,
    validFrom,
    validUntil,
    createdAt,
  ];

  Coupon copyWith({
    String? code,
    double? discountPercent,
    bool? isActive,
    String? description,
    int? maxUses,
    int? currentUses,
    DateTime? validFrom,
    DateTime? validUntil,
    DateTime? createdAt,
  }) {
    return Coupon(
      code: code ?? this.code,
      discountPercent: discountPercent ?? this.discountPercent,
      isActive: isActive ?? this.isActive,
      description: description ?? this.description,
      maxUses: maxUses ?? this.maxUses,
      currentUses: currentUses ?? this.currentUses,
      validFrom: validFrom ?? this.validFrom,
      validUntil: validUntil ?? this.validUntil,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Increments the usage count.
  Coupon incrementUsage() {
    return copyWith(currentUses: currentUses + 1);
  }
}
