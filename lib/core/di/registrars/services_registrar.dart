import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../../../data/providers/firebase_otp_provider.dart';
import '../../../data/providers/otp_provider.dart';
import '../../../data/providers/sms_portals_otp_provider.dart';
import '../../../data/services/analytics_service_impl.dart';
import '../../../data/services/app_rating_service.dart';
import '../../../data/services/connectivity_service.dart';
import '../../../data/services/crashlytics_service.dart';
import '../../../data/services/device_info_service.dart';
import '../../../data/services/fcm_token_service.dart';
import '../../../data/services/invoice_pdf_service.dart';
import '../../../data/services/member_export_service.dart';
import '../../../data/services/location_service_impl.dart';
import '../../../data/services/local_notification_service.dart';
import '../../../data/services/otp_quota_service.dart';
import '../../../data/services/promo_seen_service.dart';
import '../../../data/services/review_prompt_service.dart';
import '../../../data/services/storage_service.dart' as data_storage;
import '../../../data/services/user_session_service.dart';
import '../../../domain/repositories/user_session_repository.dart';
import '../../../domain/services/location_service.dart';
import '../../../domain/services/storage_service.dart' as domain_storage;
import '../../config/sms_portals_config.dart';
import '../../services/analytics_service.dart';

void registerDataLayerServices(GetIt sl) {
  sl.registerLazySingleton<DeviceInfoService>(
    () => DeviceInfoService(sharedPreferences: sl()),
  );

  // Location Service
  sl.registerLazySingleton<LocationService>(() => const LocationServiceImpl());

  // PDF Service
  sl.registerLazySingleton<InvoicePdfService>(() => const InvoicePdfService());

  // Member Excel Export Service
  sl.registerLazySingleton<MemberExportService>(() => const MemberExportService());

  // Local Notification Service (for displaying foreground notifications)
  sl.registerLazySingleton<LocalNotificationService>(
    () => LocalNotificationService(),
  );

  // FCM Token Service
  sl.registerLazySingleton<FcmTokenService>(
    () => FcmTokenService(
      messaging: sl(),
      notificationRepository: sl(),
      localNotificationService: sl(),
    ),
  );

  // Crashlytics Service
  // Only register if Crashlytics is available (iOS/Android)
  final isCrashlyticsSupported =
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;
  sl.registerLazySingleton<CrashlyticsService>(() {
    FirebaseCrashlytics? crashlyticsInstance;
    if (isCrashlyticsSupported) {
      try {
        crashlyticsInstance = sl<FirebaseCrashlytics>();
      } catch (e) {
        // Crashlytics not available, use null
        if (kDebugMode) {
          debugPrint('FirebaseCrashlytics not available: $e');
        }
      }
    }
    return CrashlyticsService(crashlytics: crashlyticsInstance);
  });

  // Connectivity Service
  sl.registerLazySingleton<ConnectivityService>(
    () => ConnectivityService(connectivity: sl()),
  );

  // Storage Service (data layer implementation)
  sl.registerLazySingleton<data_storage.StorageService>(
    () => data_storage.StorageService(storage: sl()),
  );

  // Storage Service (domain interface) - register implementation as interface
  sl.registerLazySingleton<domain_storage.StorageService>(
    () => sl<data_storage.StorageService>(),
  );

  // OTP Quota Service - Tracks Firebase OTP usage
  sl.registerLazySingleton<OtpQuotaService>(() => OtpQuotaService(sl()));

  // Firebase OTP Provider (free 10 OTPs/day)
  sl.registerLazySingleton<FirebaseOtpProvider>(
    () => FirebaseOtpProvider(firebaseAuth: sl()),
  );

  // SMS Portals OTP Provider (paid backup)
  sl.registerLazySingleton<SmsPortalsOtpProvider>(() {
    return SmsPortalsOtpProvider(
      apiKey: SmsPortalsConfig.apiKey,
      senderId: SmsPortalsConfig.senderId,
      dltTemplateId: SmsPortalsConfig.dltTemplateId,
      firestore: sl(),
    );
  });

  // Main OTP Provider - Uses Firebase first, falls back to SMS Portals
  // Note: The actual provider selection is now done in AuthRepository
  sl.registerLazySingleton<OtpProvider>(() => sl<SmsPortalsOtpProvider>());

  // User Session Service (for tracking app usage)
  sl.registerLazySingleton<UserSessionService>(
    () => UserSessionService(sl<UserSessionRepository>()),
  );

  // Analytics Service
  sl.registerLazySingleton<AnalyticsService>(
    () => AnalyticsServiceImpl(analytics: sl(), firestore: sl()),
  );

  // App Rating Service (in-app review + store fallback)
  sl.registerLazySingleton<AppRatingService>(() => AppRatingService());

  // Review Prompt Service (smart timing for review requests)
  sl.registerLazySingleton<ReviewPromptService>(
    () => ReviewPromptService(sharedPreferences: sl(), appRatingService: sl()),
  );

  // Promo Seen Service (tracks which promos owner has seen)
  sl.registerLazySingleton<PromoSeenService>(
    () => PromoSeenService(sl()),
  );
}
