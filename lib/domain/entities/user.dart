import 'package:equatable/equatable.dart';

/// Represents a user of the study library system.
/// Can be a student or library owner/admin.
class User extends Equatable {
  const User({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.email,
    this.deviceId,
    this.avatarUrl,
    this.isPhoneVerified = false,
    this.isProfileComplete = false,
    // Student profile fields
    this.examPreparingFor,
    this.isAccessCardIssued = false,
    this.address,
    this.gender,
    // Owner settings (only relevant for owners)
    this.showOtherLibraries = true,
    this.showMyLibraryInListing = true,
    this.autoWhatsAppInvoicesEnabled = true,
    this.autoWhatsAppFeeRemindersEnabled = true,
    this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final UserRole role;
  final String? email;

  /// Device ID stored for analytics/tracking purposes only.
  /// Multiple users can share the same device.
  final String? deviceId;

  /// URL to user's avatar image. Null means default avatar.
  final String? avatarUrl;
  final bool isPhoneVerified;

  /// Whether user has completed their profile (set name, etc.).
  final bool isProfileComplete;

  /// Student's target exam (optional).
  final String? examPreparingFor;

  /// Whether access card has been issued to student.
  final bool isAccessCardIssued;

  /// Student's address (optional).
  final String? address;

  /// Student's gender (optional).
  final String? gender;

  /// Owner settings: Whether students can see library listing in their dashboard.
  /// Only relevant for owners. Default: true (backward compatible).
  final bool showOtherLibraries;

  /// Owner settings: Whether this owner's library should be visible in marketplace/listing.
  /// Only relevant for owners. Default: true (backward compatible).
  final bool showMyLibraryInListing;

  /// Owner settings: Whether invoices should be sent automatically on WhatsApp.
  /// Only relevant for owners. Default: true (backward compatible).
  final bool autoWhatsAppInvoicesEnabled;

  /// Owner settings: Whether fee/payment reminders should be sent automatically on WhatsApp.
  /// Only relevant for owners. Default: true (backward compatible).
  final bool autoWhatsAppFeeRemindersEnabled;

  final DateTime? createdAt;

  /// Returns display name for UI.
  /// If profile is incomplete, generates a random username like "Reader_4821".
  String get displayName {
    if (isProfileComplete && name.isNotEmpty) {
      return name;
    }
    // Generate consistent random username based on user ID
    final hash = id.hashCode.abs() % 10000;
    return 'Reader_$hash';
  }

  /// Returns initials for avatar placeholder.
  String get initials {
    if (isProfileComplete && name.isNotEmpty) {
      final parts = name.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      }
      return name[0].toUpperCase();
    }
    return 'R';
  }

  /// Generates a default avatar URL based on user ID.
  /// Uses DiceBear API for consistent avatars.
  String get defaultAvatarUrl {
    // Use a deterministic seed based on user ID for consistent avatar
    return 'https://api.dicebear.com/7.x/initials/svg?seed=$id&backgroundColor=4f46e5';
  }

  /// Returns the avatar URL to display (custom or default).
  String get effectiveAvatarUrl => avatarUrl ?? defaultAvatarUrl;

  @override
  List<Object?> get props => [
    id,
    name,
    phone,
    role,
    email,
    deviceId,
    avatarUrl,
    isPhoneVerified,
    isProfileComplete,
    examPreparingFor,
    isAccessCardIssued,
    address,
    gender,
    showOtherLibraries,
    showMyLibraryInListing,
    autoWhatsAppInvoicesEnabled,
    autoWhatsAppFeeRemindersEnabled,
    createdAt,
  ];

  User copyWith({
    String? id,
    String? name,
    String? phone,
    UserRole? role,
    String? email,
    String? deviceId,
    String? avatarUrl,
    bool? isPhoneVerified,
    bool? isProfileComplete,
    String? examPreparingFor,
    bool? isAccessCardIssued,
    String? address,
    String? gender,
    bool? showOtherLibraries,
    bool? showMyLibraryInListing,
    bool? autoWhatsAppInvoicesEnabled,
    bool? autoWhatsAppFeeRemindersEnabled,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      email: email ?? this.email,
      deviceId: deviceId ?? this.deviceId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      examPreparingFor: examPreparingFor ?? this.examPreparingFor,
      isAccessCardIssued: isAccessCardIssued ?? this.isAccessCardIssued,
      address: address ?? this.address,
      gender: gender ?? this.gender,
      showOtherLibraries: showOtherLibraries ?? this.showOtherLibraries,
      showMyLibraryInListing:
          showMyLibraryInListing ?? this.showMyLibraryInListing,
      autoWhatsAppInvoicesEnabled:
          autoWhatsAppInvoicesEnabled ?? this.autoWhatsAppInvoicesEnabled,
      autoWhatsAppFeeRemindersEnabled:
          autoWhatsAppFeeRemindersEnabled ??
          this.autoWhatsAppFeeRemindersEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Creates a copy with profile marked as complete.
  User markProfileComplete({required String name, String? avatarUrl}) {
    return copyWith(name: name, avatarUrl: avatarUrl, isProfileComplete: true);
  }
}

/// User roles within the system.
enum UserRole { student, owner, admin }
