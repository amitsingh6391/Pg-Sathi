import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/core.dart';
import '../entities/app_version.dart';
import '../repositories/version_repository.dart';

/// Use case for checking if app update is required.
class CheckVersionUpdate
    implements UseCase<AppVersion, CheckVersionUpdateParams> {
  const CheckVersionUpdate({
    required this.versionRepository,
    required this.packageInfo,
  });

  final VersionRepository versionRepository;
  final PackageInfo packageInfo;

  @override
  Future<Either<Failure, AppVersion>> call(
    CheckVersionUpdateParams params,
  ) async {
    // Get current app version
    final currentVersion = packageInfo.version;

    // Fetch minimum required version
    final minVersionResult = await versionRepository
        .getMinimumRequiredVersion();
    if (minVersionResult.isLeft()) {
      // If we can't fetch remote config, allow app to continue (fail gracefully)
      return Right(
        AppVersion(
          currentVersion: currentVersion,
          minimumRequiredVersion: currentVersion, // Default to current version
          isForceUpdateRequired: false,
        ),
      );
    }

    final minimumRequiredVersion = minVersionResult.fold(
      (_) => currentVersion,
      (version) => version,
    );

    // Check if force update is enabled
    final forceUpdateResult = await versionRepository.isForceUpdateEnabled();
    final isForceUpdateEnabled = forceUpdateResult.fold(
      (_) => false,
      (enabled) => enabled,
    );

    // Get optional update message
    final messageResult = await versionRepository.getUpdateMessage();
    final updateMessage = messageResult.fold((_) => null, (message) => message);

    // Get optional update URL
    final urlResult = await versionRepository.getUpdateUrl();
    final updateUrl = urlResult.fold((_) => null, (url) => url);

    // Create version info
    final appVersion = AppVersion(
      currentVersion: currentVersion,
      minimumRequiredVersion: minimumRequiredVersion,
      isForceUpdateRequired: isForceUpdateEnabled,
      updateMessage: updateMessage,
      updateUrl: updateUrl,
    );

    return Right(appVersion);
  }
}

/// Parameters for CheckVersionUpdate use case.
class CheckVersionUpdateParams extends Equatable {
  const CheckVersionUpdateParams();

  @override
  List<Object?> get props => [];
}
