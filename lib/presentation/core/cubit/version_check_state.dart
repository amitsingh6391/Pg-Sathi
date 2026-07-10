part of 'version_check_cubit.dart';

/// Status for version check operations.
enum VersionCheckStatus { initial, checking, updateRequired, noUpdateRequired }

/// State for VersionCheckCubit.
class VersionCheckState extends Equatable {
  const VersionCheckState({
    this.status = VersionCheckStatus.initial,
    this.appVersion,
    this.errorMessage,
  });

  final VersionCheckStatus status;
  final AppVersion? appVersion;
  final String? errorMessage;

  bool get isChecking => status == VersionCheckStatus.checking;
  bool get isUpdateRequired => status == VersionCheckStatus.updateRequired;
  bool get isNoUpdateRequired => status == VersionCheckStatus.noUpdateRequired;

  VersionCheckState copyWith({
    VersionCheckStatus? status,
    AppVersion? appVersion,
    String? errorMessage,
    bool clearError = false,
  }) {
    return VersionCheckState(
      status: status ?? this.status,
      appVersion: appVersion ?? this.appVersion,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, appVersion, errorMessage];
}
