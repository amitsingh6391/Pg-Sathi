import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/user.dart';
import '../../../domain/services/storage_service.dart';
import '../../../domain/usecases/update_user_profile.dart';
import 'profile_state.dart';

/// Cubit for managing user profile state.
/// Handles profile completion flow.
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({required this.updateUserProfile, required this.storageService})
    : super(const ProfileState());

  final UpdateUserProfile updateUserProfile;
  final StorageService storageService;

  /// Loads user data into the cubit.
  void loadUser(User user) {
    emit(
      state.copyWith(
        user: user,
        avatarUrl: user.avatarUrl,
        examPreparingFor: user.examPreparingFor,
        isAccessCardIssued: user.isAccessCardIssued,
        address: user.address,
        gender: user.gender,
        isPromptDismissed: false,
      ),
    );
  }

  /// Dismisses the profile completion prompt temporarily.
  void dismissPrompt() {
    emit(state.copyWith(isPromptDismissed: true));
  }

  /// Updates the name field.
  void updateName(String name) {
    emit(state.copyWith(name: name));
  }

  /// Updates the exam preparing for field.
  void updateExamPreparingFor(String? exam) {
    emit(state.copyWith(examPreparingFor: exam));
  }

  /// Updates the access card issued status.
  void updateAccessCardIssued(bool isIssued) {
    emit(state.copyWith(isAccessCardIssued: isIssued));
  }

  /// Updates the address field.
  void updateAddress(String? address) {
    emit(state.copyWith(address: address));
  }

  /// Updates the gender field.
  void updateGender(String? gender) {
    emit(state.copyWith(gender: gender));
  }

  /// Uploads profile picture and updates avatar URL.
  Future<void> uploadProfilePicture(File imageFile) async {
    final user = state.user;
    if (user == null) return;

    emit(state.copyWith(status: ProfileStatus.saving));

    try {
      final avatarUrl = await storageService.uploadImage(
        file: imageFile,
        path: 'user_avatars/${user.id}/',
      );

      emit(state.copyWith(avatarUrl: avatarUrl));
    } catch (e) {
      emit(
        state.copyWith(
          status: ProfileStatus.error,
          errorMessage: 'Failed to upload profile picture: ${e.toString()}',
        ),
      );
    }
  }

  /// Saves the user profile.
  Future<void> saveProfile() async {
    final user = state.user;
    if (user == null) return;

    emit(state.copyWith(status: ProfileStatus.saving));

    final result = await updateUserProfile(
      UpdateUserProfileParams(
        userId: user.id,
        name: state.name,
        avatarUrl: state.avatarUrl,
        examPreparingFor: state.examPreparingFor,
        isAccessCardIssued: state.isAccessCardIssued,
        address: state.address,
        gender: state.gender,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ProfileStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (updatedUser) => emit(
        state.copyWith(status: ProfileStatus.success, user: updatedUser),
      ),
    );
  }

  /// Resets the cubit state.
  void reset() {
    emit(const ProfileState());
  }
}
