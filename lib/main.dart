import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/config/firebase_options.dart';
import 'package:go_router/go_router.dart';

import 'core/core.dart';
import 'core/services/notification_deep_link.dart';
import 'data/services/crashlytics_service.dart';
import 'data/services/fcm_token_service.dart';
import 'data/services/local_notification_service.dart';
import 'domain/usecases/expire_memberships.dart';
import 'presentation/auth/cubit/phone_auth_cubit.dart';
import 'presentation/core/cubit/version_check_cubit.dart';
import 'presentation/core/widgets/network_status_indicator.dart';

/// Background message handler for FCM.
/// This is a top-level function that must be registered before runApp().
/// It handles notifications when the app is in the background or terminated.
///
/// IMPORTANT: This function must be top-level and have @pragma('vm:entry-point')
/// to work in production builds. Do not move it inside a class.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Initialize Firebase in the background isolate
    // This is required because background handlers run in a separate isolate
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Log the notification for debugging
    debugPrint('FCM: Background message received: ${message.messageId}');
    debugPrint('FCM: Title: ${message.notification?.title}');
    debugPrint('FCM: Body: ${message.notification?.body}');
    debugPrint('FCM: Data: ${message.data}');

    // You can add custom handling here, such as:
    // - Updating local database
    // - Showing local notification
    // - Updating app state
  } catch (e, stackTrace) {
    // Log errors but DO NOT rethrow - this would prevent notification display
    // In production builds, errors here can cause notifications to be dropped
    debugPrint('FCM: Error in background handler: $e');
    debugPrint('FCM: Stack trace: $stackTrace');
    // System will still try to display notification even if handler fails
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with platform-specific options
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable Firestore persistence for faster loading and offline support
  // This reduces server reads by ~36% by caching data locally
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Register background message handler (must be before other FCM calls)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize dependencies (SharedPreferences, PackageInfo, DI registrations)
  await initDependencies();

  // Initialize Crashlytics early so it catches errors during startup
  await sl<CrashlyticsService>().initialize();

  // Initialize Local Notification Service (for foreground notifications)
  sl<LocalNotificationService>();

  // Register notification tap handler for deep linking
  _setupNotificationTapHandler();

  // ---- Non-blocking initializations: run in parallel after runApp() ----
  // These don't need to complete before UI renders.
  _initServicesInBackground();

  runApp(const LibraryManagerApp());
}

/// Pending deep-link path produced by a notification tap.
/// Consumed by [_LibraryManagerAppState] when the app is active.
String? _pendingDeepLink;

/// Sets up handler for notification taps (foreground + background + terminated).
void _setupNotificationTapHandler() {
  // 1. Local notification tap (notification was shown in foreground, tapped later)
  LocalNotificationService.onNotificationTap = (data) {
    debugPrint('[Notification] Local tap: $data');
    _storeDeepLink(data);
  };

  // 2. App was in background (minimized), user tapped system notification
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    debugPrint('[Notification] onMessageOpenedApp: ${message.data}');
    _storeDeepLink(message.data);
  });

  // 3. App was terminated, launched by notification tap
  FirebaseMessaging.instance.getInitialMessage().then((message) {
    if (message != null) {
      debugPrint('[Notification] getInitialMessage: ${message.data}');
      _storeDeepLink(message.data);
    }
  });
}

/// Extracts the deep-link path from notification data and stores it.
///
/// Routing rules live in [NotificationDeepLink.resolve] — a pure,
/// framework-free helper that's unit tested in isolation. This
/// wrapper just glues that decision to the module-level
/// [_pendingDeepLink] slot consumed by the app shell.
void _storeDeepLink(Map<String, dynamic> data) {
  final path = NotificationDeepLink.resolve(data);
  if (path == null) return;
  _pendingDeepLink = path;
  debugPrint('[Notification] Stored deep link: $_pendingDeepLink');
}

/// Runs non-critical service initializations in parallel after [runApp].
///
/// Analytics, FCM token and membership expiry don't need to
  /// complete before the first frame renders — deferring them shaves ~1s
  /// off perceived startup.
void _initServicesInBackground() {
  Future.microtask(() async {
    try {
      // Enable analytics (fire-and-forget)
      FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
      FirebaseAnalytics.instance.logEvent(
        name: 'app_start',
        parameters: {'timestamp': DateTime.now().toIso8601String()},
      );

      await sl<FcmTokenService>().initialize();
    } catch (e) {
      debugPrint('Background init error (non-fatal): $e');
    }

    // Expire memberships after services are ready
    _expireMembershipsInBackground();
  });
}

/// Expires memberships automatically in the background.
/// This runs silently without blocking app startup.
void _expireMembershipsInBackground() {
  // Run asynchronously without awaiting to avoid blocking app startup
  Future.microtask(() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        return;
      }

      final expireMemberships = sl<ExpireMemberships>();
      await expireMemberships(
        ExpireMembershipsParams(currentDate: DateTime.now()),
      );
      // Silently handle success - no UI feedback needed for background operation
    } catch (e) {
      // Silently handle errors - don't interrupt app startup
      // Errors are logged by the use case if needed
    }
  });
}

/// Root application widget.
///
/// Uses [StatefulWidget] so the [GoRouter] is created exactly once in
/// [initState]. A new router on every [build] would reset navigation
/// when Flutter rebuilds the root widget (e.g. after app resume).
///
/// Also observes [AppLifecycleState] to consume pending deep links
/// produced by notification taps when the app was in the background.
class LibraryManagerApp extends StatefulWidget {
  const LibraryManagerApp({super.key});

  @override
  State<LibraryManagerApp> createState() => _LibraryManagerAppState();
}

class _LibraryManagerAppState extends State<LibraryManagerApp>
    with WidgetsBindingObserver {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createRouter();
    WidgetsBinding.instance.addObserver(this);

    // Consume any deep link that was stored before the widget tree was ready
    // (e.g. getInitialMessage for cold-start from notification).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumePendingDeepLink();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  /// When the app resumes from the background, check for a pending deep link
  /// produced by a notification tap handler.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Short delay to let the rendering pipeline settle after resume.
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _consumePendingDeepLink();
      });
    }
  }

  void _consumePendingDeepLink() {
    if (_pendingDeepLink == null) return;

    final currentPath = _router.routerDelegate.currentConfiguration.uri.path;
    final atHome =
        currentPath.startsWith(AppRoutes.studentHome) ||
        currentPath == AppRoutes.ownerDashboard;

    if (!atHome) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _consumePendingDeepLink();
      });
      return;
    }

    final path = _pendingDeepLink!;
    _pendingDeepLink = null;
    debugPrint('[Notification] Consuming deep link: $path');
    _router.push(path);
  }

  @override
  Widget build(BuildContext context) {
    // Provide PhoneAuthCubit globally for sign-out functionality
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<PhoneAuthCubit>()),
        BlocProvider(create: (_) => sl<VersionCheckCubit>()..checkVersion()),
      ],
      child: MaterialApp.router(
        title: 'PG Sathi',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        routerConfig: _router,
        builder: (context, child) {
          return NetworkStatusIndicator(child: child!);
        },
      ),
    );
  }

  ThemeData _buildTheme() {
    // Clean PG palette: neutral charcoal with a restrained blue accent.
    const primaryColor = Color(0xFF1F2937);
    const accentColor = Color(0xFF2563EB);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: accentColor,
        brightness: Brightness.light,
        surface: const Color(0xFFFFFFFF),
        surfaceContainerHighest: const Color(0xFFF8FAFC),
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor.withValues(alpha: 0.3)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryColor),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFF1F5F9),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
