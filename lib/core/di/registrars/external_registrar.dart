import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

void registerExternalDependencies(GetIt sl) {
  sl.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);

  sl.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);

  sl.registerLazySingleton<FirebaseMessaging>(() => FirebaseMessaging.instance);

  sl.registerLazySingleton<FirebaseAnalytics>(() => FirebaseAnalytics.instance);

  sl.registerLazySingleton<FirebaseFunctions>(() => FirebaseFunctions.instance);

  // Only register Crashlytics on supported platforms (iOS and Android)
  final isCrashlyticsSupported =
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;
  if (isCrashlyticsSupported) {
    sl.registerLazySingleton<FirebaseCrashlytics>(() {
      try {
        return FirebaseCrashlytics.instance;
      } catch (e) {
        // This should not happen on supported platforms, but handle gracefully
        if (kDebugMode) {
          debugPrint('Failed to get FirebaseCrashlytics instance: $e');
        }
        rethrow;
      }
    });
  }

  sl.registerLazySingleton<FirebaseRemoteConfig>(() {
    final remoteConfig = FirebaseRemoteConfig.instance;
    remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(
          seconds: 0,
        ), // Allow immediate fetch for testing
      ),
    );
    // Set default values (used only if Remote Config fetch fails)
    remoteConfig.setDefaults({
      'minimum_required_version': '0.0.0',
      'force_update_enabled': false,
      'update_message': '',
      'update_url': '',
      // Ads feature flags
      'ads_enabled': true,
      'banner_ads_enabled': true,
      'native_ads_enabled': true,
      'ads_test_mode': true, // Default to test mode
      // When true, iOS/iPad owners use the default (Razorpay) subscription
      // flow instead of Apple In-App Purchase.
      'ios_owner_subscription_entry_enabled': false,
      // AI features
      'groq_api_key': '',
      'groq_model': 'llama-3.3-70b-versatile',
      // Tutorial videos (JSON array of {title, url})
      'tutorial_videos': '',
    });
    return remoteConfig;
  });

  sl.registerLazySingleton<FirebaseStorage>(
    () => FirebaseStorage.instanceFor(
      bucket: 'gs://pg-sathi.firebasestorage.app',
    ),
  );

  sl.registerLazySingleton<Connectivity>(() => Connectivity());
}
