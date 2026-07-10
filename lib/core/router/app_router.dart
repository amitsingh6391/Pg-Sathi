import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../data/services/first_launch_service.dart';
import '../../presentation/auth/screens/phone_auth_screen.dart';
import '../../presentation/onboarding/onboarding.dart';
import '../../presentation/owner/screens/owner_main_navigation_screen.dart';
import '../../presentation/core/screens/privacy_policy_screen.dart';
import '../../presentation/core/screens/terms_of_service_screen.dart';
import '../../presentation/core/widgets/version_check_wrapper.dart';
import '../../presentation/core/widgets/web_content_constraint.dart';
import '../../presentation/owner/screens/payment_reminder_screen.dart';
import '../../presentation/owner/cubit/slot_management_cubit.dart';
import '../../presentation/owner/screens/slot_management_screen.dart';
import '../../presentation/student/screens/student_main_navigation_screen.dart';
import '../../domain/entities/library.dart';
import '../../domain/repositories/library_repository.dart';
import '../../domain/repositories/membership_repository.dart';
import '../../domain/usecases/get_owner_library.dart';
import '../../core/di/injection_container.dart' as di;
import '../di/injection_container.dart';
import '../../presentation/auth/cubit/phone_auth_cubit.dart';
import '../../presentation/student/screens/student_notices_screen.dart';
import '../../presentation/student/screens/student_notice_details_screen.dart';
import '../../presentation/student/cubit/student_notice_cubit.dart';

/// Route names for type-safe navigation.
abstract class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String auth = '/auth';
  static const String studentHome = '/student';
  static const String ownerDashboard = '/owner';
  static const String manageSlots = '/owner/slots';
  static const String firebaseAuthLink = '/link';
}

/// Helper function to get student's library IDs from their memberships.
Future<List<String>> _getStudentLibraryIds(String studentId) async {
  try {
    final membershipRepository = di.sl<MembershipRepository>();
    final result = await membershipRepository.getMembershipsByUserId(studentId);
    return result.fold((_) => [], (memberships) {
      if (memberships.isEmpty) return [];
      // Get all unique library IDs from memberships
      return memberships.map((m) => m.libraryId).toSet().toList();
    });
  } catch (_) {
    return [];
  }
}

/// Creates and configures the app router.
GoRouter createRouter() {
  return GoRouter(
    initialLocation: kIsWeb ? AppRoutes.auth : AppRoutes.splash,
    debugLogDiagnostics: true,
    routes: [
      // Splash Screen (Mobile only)
      if (!kIsWeb)
        GoRoute(
          path: AppRoutes.splash,
          name: 'splash',
          builder: (context, state) => VersionCheckWrapper(
            child: SplashScreen(
              onInitializationComplete: () async {
                final firstLaunchService = sl<FirstLaunchService>();
                final shouldShowOnboarding = firstLaunchService
                    .shouldShowOnboarding();

                if (shouldShowOnboarding) {
                  context.go(AppRoutes.onboarding);
                } else {
                  context.go(AppRoutes.auth);
                }

                return shouldShowOnboarding;
              },
            ),
          ),
        ),

      // Onboarding Screen
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (context, state) => OnboardingScreen(
          onComplete: () async {
            final firstLaunchService = sl<FirstLaunchService>();
            await firstLaunchService.markOnboardingComplete();
            if (context.mounted) context.go(AppRoutes.auth);
          },
        ),
      ),

      // Auth Screen
      GoRoute(
        path: AppRoutes.auth,
        name: 'auth',
        builder: (context, state) => kIsWeb
            ? WebContentConstraint(
                child: const VersionCheckWrapper(child: PhoneAuthScreen()),
              )
            : const VersionCheckWrapper(child: PhoneAuthScreen()),
      ),

      // Student Home with Bottom Navigation
      GoRoute(
        path: AppRoutes.studentHome,
        name: 'studentHome',
        builder: (context, state) {
          final userId = state.uri.queryParameters['userId'] ?? '';
          return kIsWeb
              ? WebContentConstraint(
                  child: StudentMainNavigationScreen(userId: userId),
                )
              : StudentMainNavigationScreen(userId: userId);
        },
      ),

      // Owner Dashboard (with bottom navigation)
      GoRoute(
        path: AppRoutes.ownerDashboard,
        name: 'ownerDashboard',
        builder: (context, state) => kIsWeb
            ? const WebContentConstraint(child: OwnerMainNavigationScreen())
            : const OwnerMainNavigationScreen(),
      ),

      // Slot Management Screen
      GoRoute(
        path: '/owner/slots',
        name: 'slotManagement',
        builder: (context, state) {
          final libraryId = state.uri.queryParameters['libraryId'] ?? '';
          if (libraryId.isEmpty) {
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: const Center(child: Text('PG profile ID is required')),
            );
          }
          return FutureBuilder(
            future: _getLibraryById(libraryId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final library = snapshot.data;
              if (library == null) {
                return Scaffold(
                  appBar: AppBar(title: const Text('Error')),
                  body: const Center(child: Text('PG profile not found')),
                );
              }
              return BlocProvider(
                create: (_) => di.sl<SlotManagementCubit>(),
                child: SlotManagementScreen(library: library),
              );
            },
          );
        },
      ),

      // Send Notifications Screen
      GoRoute(
        path: '/owner/send-notification',
        name: 'sendNotification',
        builder: (context, state) {
          final ownerId = state.uri.queryParameters['ownerId'] ?? '';
          if (ownerId.isEmpty) {
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: const Center(child: Text('Owner ID is required')),
            );
          }

          // Fetch library and show screen
          return FutureBuilder(
            future: _getLibraryForOwnerId(ownerId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final library = snapshot.data;
              if (library == null) {
                return Scaffold(
                  appBar: AppBar(title: const Text('Error')),
                  body: const Center(child: Text('PG profile not found')),
                );
              }

              return PaymentReminderScreen(library: library);
            },
          );
        },
      ),

      // Privacy Policy
      GoRoute(
        path: '/privacy-policy',
        name: 'privacyPolicy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),

      // Terms of Service
      GoRoute(
        path: '/terms-of-service',
        name: 'termsOfService',
        builder: (context, state) => const TermsOfServiceScreen(),
      ),

      GoRoute(
        path: '/student/tools/notice-board',
        name: 'studentNoticeBoard',
        builder: (context, state) {
          final authState = context.read<PhoneAuthCubit>().state;
          final user = authState.currentUser;
          if (user == null) {
            return const Scaffold(body: Center(child: Text('User not found')));
          }

          final studentId = user.id;

          return FutureBuilder<List<String>>(
            future: _getStudentLibraryIds(studentId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final libraryIds = snapshot.data ?? [];
              if (libraryIds.isEmpty) {
                return const Scaffold(
                  body: Center(child: Text('No active PG stay found')),
                );
              }

              return StudentNoticesScreen(
                libraryIds: libraryIds,
                studentId: studentId,
              );
            },
          );
        },
      ),

      // Notice Detail (deep-link from notification tap)
      GoRoute(
        path: '/student/notices/:id',
        name: 'noticeDetail',
        builder: (context, state) {
          final authState = context.read<PhoneAuthCubit>().state;
          final noticeId = state.pathParameters['id'] ?? '';
          final user = authState.currentUser;
          if (user == null) {
            return const Scaffold(body: Center(child: Text('User not found')));
          }

          return BlocProvider(
            create: (_) => di.sl<StudentNoticeCubit>(),
            child: Builder(
              builder: (context) => FutureBuilder(
                future: context.read<StudentNoticeCubit>().getNotice(noticeId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final notice = snapshot.data;
                  if (notice == null) {
                    return Scaffold(
                      appBar: AppBar(title: const Text('Not Found')),
                      body: const Center(child: Text('Notice not found')),
                    );
                  }
                  return StudentNoticeDetailsScreen(
                    notice: notice,
                    studentId: user.id,
                    studentName: user.name,
                  );
                },
              ),
            ),
          );
        },
      ),

      // Firebase Auth callback route
      GoRoute(
        path: AppRoutes.firebaseAuthLink,
        name: 'firebaseAuthLink',
        redirect: (context, state) => AppRoutes.auth,
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page not found: ${state.uri.path}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.auth),
              child: const Text('Go to Home'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Extension methods for navigation.
extension AppNavigator on BuildContext {
  /// Navigate to student home screen.
  void goToStudentHome({required String userId}) {
    go(
      Uri(
        path: AppRoutes.studentHome,
        queryParameters: {'userId': userId},
      ).toString(),
    );
  }

  /// Navigate to owner dashboard.
  void goToOwnerDashboard() {
    go(AppRoutes.ownerDashboard);
  }

  /// Navigate to auth screen.
  void goToAuth() {
    go(AppRoutes.auth);
  }

  /// Navigate to slot management screen.
  void goToSlotManagement({required String libraryId}) {
    push(
      Uri(
        path: AppRoutes.manageSlots,
        queryParameters: {'libraryId': libraryId},
      ).toString(),
    );
  }
}

/// Helper function to get library by ID for routing.
Future<Library?> _getLibraryById(String libraryId) async {
  final libraryRepository = di.sl<LibraryRepository>();
  final result = await libraryRepository.getLibraryById(libraryId);
  return result.fold((_) => null, (library) => library);
}

/// Helper function to get library by owner ID for routing.
Future<Library?> _getLibraryForOwnerId(String ownerId) async {
  final getOwnerLibrary = di.sl<GetOwnerLibrary>();
  final result = await getOwnerLibrary(GetOwnerLibraryParams(ownerId: ownerId));
  return result.fold((_) => null, (library) => library);
}
