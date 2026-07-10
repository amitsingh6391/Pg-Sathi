import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user.dart';
import '../models/user_dto.dart';

/// Mapper for User entity <-> UserDto conversion.
class UserMapper {
  const UserMapper._();

  static User toEntity(UserDto dto) {
    return User(
      id: dto.id,
      name: dto.name,
      phone: dto.phone,
      role: _parseRole(dto.role),
      email: dto.email,
      deviceId: dto.deviceId,
      avatarUrl: dto.avatarUrl,
      isPhoneVerified: dto.isPhoneVerified,
      isProfileComplete: dto.isProfileComplete,
      examPreparingFor: dto.examPreparingFor,
      isAccessCardIssued: dto.isAccessCardIssued,
      address: dto.address,
      gender: dto.gender,
      showOtherLibraries: dto.showOtherLibraries,
      showMyLibraryInListing: dto.showMyLibraryInListing,
      autoWhatsAppInvoicesEnabled: dto.autoWhatsAppInvoicesEnabled,
      autoWhatsAppFeeRemindersEnabled: dto.autoWhatsAppFeeRemindersEnabled,
      createdAt: dto.createdAt?.toDate(),
    );
  }

  static UserDto toDto(User entity) {
    return UserDto(
      id: entity.id,
      name: entity.name,
      phone: entity.phone,
      role: entity.role.name,
      email: entity.email,
      deviceId: entity.deviceId,
      avatarUrl: entity.avatarUrl,
      isPhoneVerified: entity.isPhoneVerified,
      isProfileComplete: entity.isProfileComplete,
      examPreparingFor: entity.examPreparingFor,
      isAccessCardIssued: entity.isAccessCardIssued,
      address: entity.address,
      gender: entity.gender,
      showOtherLibraries: entity.showOtherLibraries,
      showMyLibraryInListing: entity.showMyLibraryInListing,
      autoWhatsAppInvoicesEnabled: entity.autoWhatsAppInvoicesEnabled,
      autoWhatsAppFeeRemindersEnabled: entity.autoWhatsAppFeeRemindersEnabled,
      createdAt: entity.createdAt != null
          ? Timestamp.fromDate(entity.createdAt!)
          : null,
    );
  }

  static UserRole _parseRole(String role) {
    return UserRole.values.firstWhere(
      (e) => e.name == role,
      orElse: () => UserRole.student,
    );
  }
}
