import 'package:equatable/equatable.dart';

/// Summary information about a library for admin analytics.
/// Contains key metrics and contact information for quick access.
class LibrarySummary extends Equatable {
  const LibrarySummary({
    required this.libraryId,
    required this.libraryName,
    required this.ownerId,
    required this.ownerName,
    required this.ownerPhone,
    required this.totalSeats,
    required this.activeMemberships,
    required this.occupancyPercent,
    required this.createdAt,
    this.area,
    this.subscriptionStatus,
    this.subscriptionEndDate,
    this.lastActivityAt,
  });

  final String libraryId;
  final String libraryName;
  final String ownerId;
  final String ownerName;
  final String ownerPhone;
  final int totalSeats;
  final int activeMemberships;
  final double occupancyPercent;
  final DateTime createdAt;
  final String? area;
  final String? subscriptionStatus;
  final DateTime? subscriptionEndDate;
  final DateTime? lastActivityAt;

  /// Formatted occupancy for display.
  String get formattedOccupancy => '${occupancyPercent.toStringAsFixed(0)}%';

  /// Days remaining until subscription expires.
  /// Returns null if no subscription or already expired.
  int? get daysRemaining {
    if (subscriptionEndDate == null) return null;
    final now = DateTime.now();
    if (now.isAfter(subscriptionEndDate!)) return null;
    return subscriptionEndDate!.difference(now).inDays;
  }

  /// Whether subscription is expired.
  bool get isSubscriptionExpired {
    if (subscriptionEndDate == null) return false;
    return DateTime.now().isAfter(subscriptionEndDate!);
  }

  /// Formatted phone number with country code for WhatsApp.
  String get whatsappPhoneNumber {
    final cleaned = ownerPhone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.startsWith('91')) return cleaned;
    if (cleaned.length == 10) return '91$cleaned';
    return cleaned;
  }

  /// WhatsApp chat URL.
  String get whatsappUrl => 'https://wa.me/$whatsappPhoneNumber';

  @override
  List<Object?> get props => [
    libraryId,
    libraryName,
    ownerId,
    ownerName,
    ownerPhone,
    totalSeats,
    activeMemberships,
    occupancyPercent,
    createdAt,
    area,
    subscriptionStatus,
    subscriptionEndDate,
    lastActivityAt,
  ];

  LibrarySummary copyWith({
    String? libraryId,
    String? libraryName,
    String? ownerId,
    String? ownerName,
    String? ownerPhone,
    int? totalSeats,
    int? activeMemberships,
    double? occupancyPercent,
    DateTime? createdAt,
    String? area,
    String? subscriptionStatus,
    DateTime? subscriptionEndDate,
    DateTime? lastActivityAt,
  }) {
    return LibrarySummary(
      libraryId: libraryId ?? this.libraryId,
      libraryName: libraryName ?? this.libraryName,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      totalSeats: totalSeats ?? this.totalSeats,
      activeMemberships: activeMemberships ?? this.activeMemberships,
      occupancyPercent: occupancyPercent ?? this.occupancyPercent,
      createdAt: createdAt ?? this.createdAt,
      area: area ?? this.area,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionEndDate: subscriptionEndDate ?? this.subscriptionEndDate,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
    );
  }
}
