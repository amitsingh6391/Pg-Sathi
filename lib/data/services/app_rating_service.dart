import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';

class AppRatingService {
  AppRatingService({InAppReview? inAppReview})
      : _inAppReview = inAppReview ?? InAppReview.instance;

  final InAppReview _inAppReview;


  Future<bool> requestReview() async {
    if (kIsWeb) return false;

    try {
      final isAvailable = await _inAppReview.isAvailable();
      if (isAvailable) {
        await _inAppReview.requestReview();
        return true;
      }
    } catch (e) {
      debugPrint('AppRatingService: In-app review failed: $e');
    }

    // Fallback: open store listing directly.
    return openStoreListing();
  }

  /// Opens the platform-specific store listing in an external browser/app.
  Future<bool> openStoreListing() async {
    if (kIsWeb) return false;

    try {
      final uri = Uri.parse(
        Platform.isIOS
            ? AppConstants.appStoreUrl
            : AppConstants.playStoreUrl,
      );
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('AppRatingService: Failed to open store listing: $e');
      return false;
    }
  }
}
