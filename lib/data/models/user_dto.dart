import 'package:cloud_firestore/cloud_firestore.dart';

/// Data Transfer Object for User entity.
/// Maps Firebase document data to/from domain entity.
class UserDto {
  const UserDto({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.email,
    this.deviceId,
    this.avatarUrl,
    this.isPhoneVerified = false,
    this.isProfileComplete = false,
    this.examPreparingFor,
    this.isAccessCardIssued = false,
    this.address,
    this.gender,
    this.showOtherLibraries = true,
    this.showMyLibraryInListing = true,
    this.autoWhatsAppInvoicesEnabled = true,
    this.autoWhatsAppFeeRemindersEnabled = true,
    this.createdAt,
    this.managedByOwnerId,
    this.managedLibraryIds = const [],
  });

  final String id;
  final String name;
  final String phone;
  final String role;
  final String? email;
  final String? deviceId;
  final String? avatarUrl;
  final bool isPhoneVerified;
  final bool isProfileComplete;
  final String? examPreparingFor;
  final bool isAccessCardIssued;
  final String? address;
  final String? gender;
  final bool showOtherLibraries;
  final bool showMyLibraryInListing;
  final bool autoWhatsAppInvoicesEnabled;
  final bool autoWhatsAppFeeRemindersEnabled;
  final Timestamp? createdAt;
  final String? managedByOwnerId;
  final List<String> managedLibraryIds;

  factory UserDto.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return UserDto(
      id: doc.id,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      role: data['role'] as String? ?? 'student',
      email: data['email'] as String?,
      deviceId: data['deviceId'] as String?,
      avatarUrl: data['avatarUrl'] as String?,
      isPhoneVerified: data['isPhoneVerified'] as bool? ?? false,
      isProfileComplete: data['isProfileComplete'] as bool? ?? false,
      examPreparingFor: data['examPreparingFor'] as String?,
      isAccessCardIssued: data['isAccessCardIssued'] as bool? ?? false,
      address: data['address'] as String?,
      gender: data['gender'] as String?,
      showOtherLibraries: data['showOtherLibraries'] as bool? ?? true,
      showMyLibraryInListing: data['showMyLibraryInListing'] as bool? ?? true,
      autoWhatsAppInvoicesEnabled:
          data['autoWhatsAppInvoicesEnabled'] as bool? ?? true,
      autoWhatsAppFeeRemindersEnabled:
          data['autoWhatsAppFeeRemindersEnabled'] as bool? ?? true,
      createdAt: data['createdAt'] as Timestamp?,
      managedByOwnerId: data['managedByOwnerId'] as String?,
      managedLibraryIds: readManagedLibraryIds(data),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'phone': phone,
      'role': role,
      if (email != null) 'email': email,
      if (deviceId != null) 'deviceId': deviceId,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'isPhoneVerified': isPhoneVerified,
      'isProfileComplete': isProfileComplete,
      if (examPreparingFor != null) 'examPreparingFor': examPreparingFor,
      'isAccessCardIssued': isAccessCardIssued,
      if (address != null) 'address': address,
      if (gender != null) 'gender': gender,
      'showOtherLibraries': showOtherLibraries,
      'showMyLibraryInListing': showMyLibraryInListing,
      'autoWhatsAppInvoicesEnabled': autoWhatsAppInvoicesEnabled,
      'autoWhatsAppFeeRemindersEnabled': autoWhatsAppFeeRemindersEnabled,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      if (managedByOwnerId != null) 'managedByOwnerId': managedByOwnerId,
      if (managedLibraryIds.isNotEmpty) ...{
        'managedLibraryIds': managedLibraryIds,
        // Legacy single-id field, kept for compatibility.
        'managedLibraryId': managedLibraryIds.first,
      },
    };
  }

  /// Reads a library id list, falling back to the legacy single id field.
  static List<String> readManagedLibraryIds(
    Map<String, dynamic>? data, {
    String listKey = 'managedLibraryIds',
    String legacyKey = 'managedLibraryId',
  }) {
    final ids = data?[listKey];
    if (ids is List) return ids.whereType<String>().toList();
    final legacy = data?[legacyKey];
    return legacy is String ? [legacy] : const [];
  }

  static const String collectionName = 'users';
}
