import 'package:equatable/equatable.dart';

import '../../../domain/entities/user.dart';

/// State for owner settings cubit.
class OwnerSettingsState extends Equatable {
  const OwnerSettingsState({
    this.user,
    this.showOtherLibraries = true,
    this.showMyLibraryInListing = true,
    this.autoWhatsAppInvoicesEnabled = true,
    this.autoWhatsAppFeeRemindersEnabled = true,
    this.status = OwnerSettingsStatus.initial,
    this.errorMessage,
  });

  final User? user;
  final bool showOtherLibraries;
  final bool showMyLibraryInListing;
  final bool autoWhatsAppInvoicesEnabled;
  final bool autoWhatsAppFeeRemindersEnabled;
  final OwnerSettingsStatus status;
  final String? errorMessage;

  OwnerSettingsState copyWith({
    User? user,
    bool? showOtherLibraries,
    bool? showMyLibraryInListing,
    bool? autoWhatsAppInvoicesEnabled,
    bool? autoWhatsAppFeeRemindersEnabled,
    OwnerSettingsStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return OwnerSettingsState(
      user: user ?? this.user,
      showOtherLibraries: showOtherLibraries ?? this.showOtherLibraries,
      showMyLibraryInListing:
          showMyLibraryInListing ?? this.showMyLibraryInListing,
      autoWhatsAppInvoicesEnabled:
          autoWhatsAppInvoicesEnabled ?? this.autoWhatsAppInvoicesEnabled,
      autoWhatsAppFeeRemindersEnabled:
          autoWhatsAppFeeRemindersEnabled ??
          this.autoWhatsAppFeeRemindersEnabled,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    user,
    showOtherLibraries,
    showMyLibraryInListing,
    autoWhatsAppInvoicesEnabled,
    autoWhatsAppFeeRemindersEnabled,
    status,
    errorMessage,
  ];
}

/// Status for owner settings operations.
enum OwnerSettingsStatus { initial, loading, success, error }
