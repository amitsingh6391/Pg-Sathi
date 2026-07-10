import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/app_version.dart';
import '../../../domain/usecases/check_version_update.dart';

part 'version_check_state.dart';

/// Cubit for managing app version check and force update.
class VersionCheckCubit extends Cubit<VersionCheckState> {
  VersionCheckCubit({required this.checkVersionUpdate})
    : super(const VersionCheckState());

  final CheckVersionUpdate checkVersionUpdate;

  /// Checks if app update is required.
  Future<void> checkVersion() async {
    if (isClosed) return;
    emit(state.copyWith(status: VersionCheckStatus.checking));

    final result = await checkVersionUpdate(const CheckVersionUpdateParams());

    if (isClosed) return;

    result.fold(
      (failure) {
        if (!isClosed) {
          emit(
            state.copyWith(
              status: VersionCheckStatus.noUpdateRequired,
              errorMessage: failure.message,
            ),
          );
        }
      },
      (appVersion) {
        if (isClosed) return;
        if (appVersion.isUpdateRequired && appVersion.isForceUpdateRequired) {
          emit(
            state.copyWith(
              status: VersionCheckStatus.updateRequired,
              appVersion: appVersion,
            ),
          );
        } else {
          emit(
            state.copyWith(
              status: VersionCheckStatus.noUpdateRequired,
              appVersion: appVersion,
            ),
          );
        }
      },
    );
  }

  /// Opens the update URL (Play Store/App Store).
  Future<void> openUpdateUrl() async {
    String? url = state.appVersion?.updateUrl;

    // If no URL provided, use default Play Store/App Store URL
    if (url == null || url.isEmpty) {
      url = _getDefaultStoreUrl();
    }

    if (url == null || url.isEmpty) {
      return;
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Silently fail - user can manually update
    }
  }

  /// Gets default store URL based on platform.
  String? _getDefaultStoreUrl() {
    if (kIsWeb) {
      return null; // No app store for web
    }

    if (Platform.isAndroid) {
      return AppConstants.playStoreUrl;
    } else if (Platform.isIOS) {
      return AppConstants.appStoreUrl;
    }

    return null;
  }
}
