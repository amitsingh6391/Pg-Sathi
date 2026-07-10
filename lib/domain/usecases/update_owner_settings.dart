import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/user.dart';
import '../repositories/user_repository.dart';

/// Use case for updating owner visibility settings.
/// Only applicable for owners.
class UpdateOwnerSettings implements UseCase<User, UpdateOwnerSettingsParams> {
  const UpdateOwnerSettings({required this.userRepository});

  final UserRepository userRepository;

  @override
  Future<Either<Failure, User>> call(UpdateOwnerSettingsParams params) async {
    // Get current user
    final currentUserResult = await userRepository.getUserById(params.ownerId);

    return currentUserResult.fold((failure) => Left(failure), (
      currentUser,
    ) async {
      // Update only the settings fields (atomic update)
      final updatedUser = currentUser.copyWith(
        showOtherLibraries: params.showOtherLibraries,
        showMyLibraryInListing: params.showMyLibraryInListing,
        autoWhatsAppInvoicesEnabled:
            params.autoWhatsAppInvoicesEnabled ??
            currentUser.autoWhatsAppInvoicesEnabled,
        autoWhatsAppFeeRemindersEnabled:
            params.autoWhatsAppFeeRemindersEnabled ??
            currentUser.autoWhatsAppFeeRemindersEnabled,
      );

      return await userRepository.updateUser(updatedUser);
    });
  }
}

/// Parameters for UpdateOwnerSettings use case.
class UpdateOwnerSettingsParams extends Equatable {
  const UpdateOwnerSettingsParams({
    required this.ownerId,
    required this.showOtherLibraries,
    required this.showMyLibraryInListing,
    this.autoWhatsAppInvoicesEnabled,
    this.autoWhatsAppFeeRemindersEnabled,
  });

  final String ownerId;
  final bool showOtherLibraries;
  final bool showMyLibraryInListing;
  final bool? autoWhatsAppInvoicesEnabled;
  final bool? autoWhatsAppFeeRemindersEnabled;

  @override
  List<Object?> get props => [
    ownerId,
    showOtherLibraries,
    showMyLibraryInListing,
    autoWhatsAppInvoicesEnabled,
    autoWhatsAppFeeRemindersEnabled,
  ];
}
