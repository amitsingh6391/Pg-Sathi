import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/user.dart';
import '../../../domain/usecases/update_owner_settings.dart';
import 'owner_settings_state.dart';

/// Cubit for managing owner visibility settings.
class OwnerSettingsCubit extends Cubit<OwnerSettingsState> {
  OwnerSettingsCubit({required this.updateOwnerSettings})
    : super(const OwnerSettingsState());

  final UpdateOwnerSettings updateOwnerSettings;

  /// Loads owner settings from user.
  void loadSettings(User user) {
    emit(
      state.copyWith(
        user: user,
        showOtherLibraries: user.showOtherLibraries,
        showMyLibraryInListing: user.showMyLibraryInListing,
        autoWhatsAppInvoicesEnabled: user.autoWhatsAppInvoicesEnabled,
        autoWhatsAppFeeRemindersEnabled: user.autoWhatsAppFeeRemindersEnabled,
        status: OwnerSettingsStatus.initial,
        clearError: true,
      ),
    );
  }

  /// Updates showOtherLibraries setting.
  Future<void> updateShowOtherLibraries(bool value) async {
    final user = state.user;
    if (user == null) return;

    emit(state.copyWith(showOtherLibraries: value));

    await _saveSettings(
      showOtherLibraries: value,
      showMyLibraryInListing: state.showMyLibraryInListing,
      autoWhatsAppInvoicesEnabled: state.autoWhatsAppInvoicesEnabled,
      autoWhatsAppFeeRemindersEnabled: state.autoWhatsAppFeeRemindersEnabled,
    );
  }

  /// Updates showMyLibraryInListing setting.
  Future<void> updateShowMyLibraryInListing(bool value) async {
    final user = state.user;
    if (user == null) return;

    emit(state.copyWith(showMyLibraryInListing: value));

    await _saveSettings(
      showOtherLibraries: state.showOtherLibraries,
      showMyLibraryInListing: value,
      autoWhatsAppInvoicesEnabled: state.autoWhatsAppInvoicesEnabled,
      autoWhatsAppFeeRemindersEnabled: state.autoWhatsAppFeeRemindersEnabled,
    );
  }

  /// Updates auto WhatsApp invoice setting.
  Future<void> updateAutoWhatsAppInvoices(bool value) async {
    final user = state.user;
    if (user == null) return;

    emit(state.copyWith(autoWhatsAppInvoicesEnabled: value));

    await _saveSettings(
      showOtherLibraries: state.showOtherLibraries,
      showMyLibraryInListing: state.showMyLibraryInListing,
      autoWhatsAppInvoicesEnabled: value,
      autoWhatsAppFeeRemindersEnabled: state.autoWhatsAppFeeRemindersEnabled,
    );
  }

  /// Updates auto WhatsApp fee reminder setting.
  Future<void> updateAutoWhatsAppFeeReminders(bool value) async {
    final user = state.user;
    if (user == null) return;

    emit(state.copyWith(autoWhatsAppFeeRemindersEnabled: value));

    await _saveSettings(
      showOtherLibraries: state.showOtherLibraries,
      showMyLibraryInListing: state.showMyLibraryInListing,
      autoWhatsAppInvoicesEnabled: state.autoWhatsAppInvoicesEnabled,
      autoWhatsAppFeeRemindersEnabled: value,
    );
  }

  /// Saves settings to Firestore (atomic update).
  Future<void> _saveSettings({
    required bool showOtherLibraries,
    required bool showMyLibraryInListing,
    required bool autoWhatsAppInvoicesEnabled,
    required bool autoWhatsAppFeeRemindersEnabled,
  }) async {
    final user = state.user;
    if (user == null) return;

    emit(state.copyWith(status: OwnerSettingsStatus.loading, clearError: true));

    final result = await updateOwnerSettings(
      UpdateOwnerSettingsParams(
        ownerId: user.id,
        showOtherLibraries: showOtherLibraries,
        showMyLibraryInListing: showMyLibraryInListing,
        autoWhatsAppInvoicesEnabled: autoWhatsAppInvoicesEnabled,
        autoWhatsAppFeeRemindersEnabled: autoWhatsAppFeeRemindersEnabled,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: OwnerSettingsStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (updatedUser) => emit(
        state.copyWith(
          user: updatedUser,
          status: OwnerSettingsStatus.success,
          clearError: true,
        ),
      ),
    );
  }
}
