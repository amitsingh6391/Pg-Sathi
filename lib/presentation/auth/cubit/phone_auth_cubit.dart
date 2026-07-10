import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/services/analytics_service.dart';
import '../../../data/services/device_info_service.dart';
import '../../../data/services/fcm_token_service.dart';
import '../../../data/services/user_session_service.dart';
import '../../../domain/core/usecase.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/device_session_repository.dart';
import '../../../domain/usecases/check_auth_status.dart';
import '../../../domain/usecases/delete_account.dart';
import '../../../domain/usecases/send_otp.dart';
import '../../../domain/usecases/sign_out.dart';
import '../../../domain/usecases/verify_otp.dart';
import '../../core/cubit/notification_permission_cubit.dart';
import 'phone_auth_state.dart';

/// Cubit for managing phone authentication state.
/// Delegates all business logic to use cases.
class PhoneAuthCubit extends Cubit<PhoneAuthState> {
  PhoneAuthCubit({
    required this.sendOtpUseCase,
    required this.verifyOtpUseCase,
    required this.checkAuthStatusUseCase,
    required this.signOutUseCase,
    required this.deleteAccountUseCase,
    required this.authRepository,
    required this.analyticsService,
  }) : super(const PhoneAuthState.initial(selectedRole: UserRole.student));

  final SendOtp sendOtpUseCase;
  final VerifyOtp verifyOtpUseCase;
  final CheckAuthStatus checkAuthStatusUseCase;
  final SignOut signOutUseCase;
  final DeleteAccount deleteAccountUseCase;
  final AuthRepository authRepository;
  final AnalyticsService analyticsService;

  StreamSubscription<User?>? _authSubscription;

  // Store current form values
  UserRole _selectedRole = UserRole.student;
  String? _phoneNumber;
  String? _verificationId;

  /// Checks initial authentication status.
  Future<void> checkAuthStatus() async {
    if (isClosed) return;
    emit(const PhoneAuthState.checkingAuth());

    final result = await checkAuthStatusUseCase(const CheckAuthStatusParams());

    if (isClosed) return;
    result.fold((failure) => emit(PhoneAuthState.error(failure: failure)), (
      authStatus,
    ) async {
      if (authStatus.isAuthenticated && authStatus.user != null) {
        final user = authStatus.user!;

        // Check if device session is revoked
        final isRevoked = await _checkDeviceSessionRevoked(user.id);
        if (isRevoked) {
          // Force logout if session is revoked
          debugPrint('DeviceSession: Session revoked, forcing logout');
          await signOut();
          return;
        }

        emit(PhoneAuthState.authenticated(user: user));
        // Set analytics user context
        _setAnalyticsContext(user);
        // Sync FCM token if user is already authenticated
        _syncFcmToken(user.id);
        // Create/update device session
        _createDeviceSession(user);
        // Start session tracking
        _startUserSession(user);
      } else {
        emit(PhoneAuthState.initial(selectedRole: _selectedRole));
      }
    });
  }

  /// Sets the selected role.
  void setRole(UserRole role) {
    _selectedRole = role;
    state.mapOrNull(
      initial: (s) => emit(s.copyWith(selectedRole: role)),
      sendingOtp: (s) => emit(s.copyWith(selectedRole: role)),
      otpSent: (s) => emit(s.copyWith(selectedRole: role)),
      error: (s) => emit(s.copyWith(selectedRole: role)),
    );
  }

  /// Sends OTP to the given phone number.
  /// Expects fully-formed phone number with country code (e.g., +911234567890).
  Future<void> sendOtp(String phoneNumber) async {
    if (isClosed) return;
    _phoneNumber = phoneNumber;

    emit(
      PhoneAuthState.sendingOtp(
        phoneNumber: phoneNumber,
        selectedRole: _selectedRole,
      ),
    );

    final result = await sendOtpUseCase(
      SendOtpParams(phoneNumber: phoneNumber),
    );

    if (isClosed) return;
    result.fold(
      (failure) => emit(
        PhoneAuthState.error(
          failure: failure,
          phoneNumber: phoneNumber,
          selectedRole: _selectedRole,
        ),
      ),
      (verificationId) {
        _verificationId = verificationId;
        emit(
          PhoneAuthState.otpSent(
            phoneNumber: phoneNumber,
            verificationId: verificationId,
            selectedRole: _selectedRole,
          ),
        );
      },
    );
  }

  /// Verifies the OTP code.
  Future<void> verifyOtp(String otp) async {
    if (isClosed) return;

    final currentVerificationId = _verificationId;
    final currentPhoneNumber = _phoneNumber;

    if (currentVerificationId == null || currentPhoneNumber == null) {
      return;
    }

    emit(
      PhoneAuthState.verifyingOtp(
        phoneNumber: currentPhoneNumber,
        verificationId: currentVerificationId,
        selectedRole: _selectedRole,
      ),
    );

    // Name is not collected during auth - will be updated later in profile
    final result = await verifyOtpUseCase(
      VerifyOtpParams(
        verificationId: currentVerificationId,
        otp: otp,
        role: _selectedRole,
        name: null,
      ),
    );

    if (isClosed) return;
    result.fold(
      (failure) => emit(
        PhoneAuthState.error(
          failure: failure,
          phoneNumber: currentPhoneNumber,
          verificationId: currentVerificationId,
          selectedRole: _selectedRole,
        ),
      ),
      (user) {
        emit(PhoneAuthState.authenticated(user: user));
        // Set analytics user context
        _setAnalyticsContext(user);
        // Sync FCM token after successful login
        _syncFcmToken(user.id);
        // Create/update device session
        _createDeviceSession(user);
        // Request notification permission immediately after login
        _requestNotificationPermission();
        // Start session tracking
        _startUserSession(user);
      },
    );
  }

  /// Resends OTP to the same phone number.
  Future<void> resendOtp() async {
    final phone = _phoneNumber;
    if (phone == null) return;
    await sendOtp(phone);
  }

  /// Signs out the current user.
  /// Emits [PhoneAuthSigningOut] during sign-out,
  /// then [PhoneAuthSignedOut] on success or [PhoneAuthError] on failure.
  Future<void> signOut() async {
    if (isClosed) return;

    // Get user BEFORE emitting signing out state
    final currentUser = state.mapOrNull(authenticated: (state) => state.user);

    emit(const PhoneAuthState.signingOut());

    // Clean up device session before signing out
    if (currentUser != null) {
      await _cleanupDeviceSessionForUser(currentUser);
    }

    // End user session before signing out
    await _endUserSession();

    final result = await signOutUseCase(const NoParams());

    if (isClosed) return;
    result.fold((failure) => emit(PhoneAuthState.error(failure: failure)), (_) {
      // Clear analytics user context
      analyticsService.clearUserContext();
      // Clear cached values
      _phoneNumber = null;
      _verificationId = null;
      _selectedRole = UserRole.student;
      emit(const PhoneAuthState.signedOut());
    });
  }

  /// Permanently deletes the current account and returns to signed-out state.
  Future<void> deleteAccount() async {
    if (isClosed) return;

    final currentUser = state.mapOrNull(authenticated: (state) => state.user);

    emit(const PhoneAuthState.signingOut());

    if (currentUser != null) {
      await _cleanupDeviceSessionForUser(currentUser);
    }
    await _endUserSession();

    final result = await deleteAccountUseCase(const NoParams());

    if (isClosed) return;
    result.fold((failure) => emit(PhoneAuthState.error(failure: failure)), (_) {
      analyticsService.clearUserContext();
      _phoneNumber = null;
      _verificationId = null;
      _selectedRole = UserRole.student;
      emit(const PhoneAuthState.signedOut());
    });
  }

  /// Resets to initial state for new authentication attempt.
  void reset() {
    _phoneNumber = null;
    _verificationId = null;
    if (!isClosed) {
      emit(PhoneAuthState.initial(selectedRole: _selectedRole));
    }
  }

  /// Goes back to phone input from OTP screen.
  void goBackToPhoneInput() {
    _verificationId = null;
    if (!isClosed) {
      emit(PhoneAuthState.initial(selectedRole: _selectedRole));
    }
  }

  /// Updates the current user (e.g., after profile completion).
  /// This ensures the UI reflects the latest user data.
  void updateUser(User user) {
    if (isClosed) return;
    if (state.isAuthenticated) {
      emit(PhoneAuthState.authenticated(user: user));
      // Update analytics context
      _setAnalyticsContext(user);
      // Sync FCM token when user is updated
      _syncFcmToken(user.id);
    }
  }

  /// Sets analytics user context with user info.
  void _setAnalyticsContext(User user) {
    analyticsService.setUserContext(
      userId: user.id,
      userRole: user.role.name,
      libraryId: user.role == UserRole.owner ? user.id : null,
    );
  }

  /// Syncs FCM token for the authenticated user.
  void _syncFcmToken(String userId) {
    try {
      sl<FcmTokenService>().syncTokenForUser(userId);
    } catch (e) {
      // Silently fail - FCM token sync shouldn't block authentication
      debugPrint('FCM: Failed to sync token: $e');
    }
  }

  /// Creates/updates device session for the authenticated user.
  Future<void> _createDeviceSession(User user) async {
    try {
      final deviceInfoService = sl<DeviceInfoService>();
      final deviceSessionRepo = sl<DeviceSessionRepository>();

      // Get device ID (it returns Either<Failure, String>)
      final deviceIdResult = await deviceInfoService.getDeviceId();
      final deviceId = deviceIdResult.fold((failure) => null, (id) => id);

      if (deviceId == null) {
        debugPrint('DeviceSession: Failed to get device ID');
        return;
      }

      // Get FCM token
      String? fcmToken;
      try {
        fcmToken = await sl<FcmTokenService>().messaging.getToken();
      } on FirebaseException catch (e) {
        if (e.code == 'apns-token-not-set') {
          debugPrint(
            'DeviceSession: FCM token not ready yet; APNS token is still pending.',
          );
        } else {
          debugPrint('DeviceSession: Failed to get FCM token: $e');
        }
      } catch (e) {
        debugPrint('DeviceSession: Failed to get FCM token: $e');
      }

      // Use platform name as device name
      final deviceName = Platform.operatingSystem;

      await deviceSessionRepo.updateDeviceSession(
        userId: user.id,
        deviceId: deviceId,
        deviceName: deviceName,
        platform: Platform.operatingSystem,
        fcmToken: fcmToken,
      );

      debugPrint('DeviceSession: Created/updated session for device $deviceId');
    } catch (e) {
      // Silently fail - device session shouldn't block authentication
      debugPrint('DeviceSession: Failed to create/update: $e');
    }
  }

  /// Check if the current device session is revoked.
  Future<bool> _checkDeviceSessionRevoked(String userId) async {
    try {
      final deviceInfoService = sl<DeviceInfoService>();
      final deviceSessionRepo = sl<DeviceSessionRepository>();

      // Get device ID
      final deviceIdResult = await deviceInfoService.getDeviceId();
      final deviceId = deviceIdResult.fold((failure) => null, (id) => id);

      if (deviceId == null) {
        return false; // Can't check, allow login
      }

      // Check if session is revoked
      final result = await deviceSessionRepo.isDeviceSessionRevoked(
        userId: userId,
        deviceId: deviceId,
      );

      return result.fold((failure) {
        debugPrint(
          'DeviceSession: Failed to check revoked status: ${failure.message}',
        );
        return false; // On error, allow login
      }, (isRevoked) => isRevoked);
    } catch (e) {
      debugPrint('DeviceSession: Error checking revoked status: $e');
      return false; // On error, allow login
    }
  }

  /// Requests notification permission immediately after login.
  void _requestNotificationPermission() {
    try {
      final permissionCubit = sl<NotificationPermissionCubit>();
      permissionCubit.requestPermission();
    } catch (e) {
      // Silently fail - permission request shouldn't block authentication
      debugPrint('FCM: Failed to request permission: $e');
    }
  }

  /// Starts a user session for tracking app usage.
  Future<void> _startUserSession(User user) async {
    try {
      final sessionService = sl<UserSessionService>();
      await sessionService.startSession(
        userId: user.id,
        role: user.role,
        deviceId: user.deviceId,
      );
      debugPrint('Session: Started session for user ${user.id}');
    } catch (e) {
      // Silently fail - session tracking shouldn't block authentication
      debugPrint('Session: Failed to start session: $e');
    }
  }

  /// Cleans up device session on sign out for a specific user.
  Future<void> _cleanupDeviceSessionForUser(User user) async {
    try {
      final deviceInfoService = sl<DeviceInfoService>();
      final firestore = sl<FirebaseFirestore>();

      // Get device ID
      final deviceIdResult = await deviceInfoService.getDeviceId();
      final deviceId = deviceIdResult.fold((failure) => null, (id) => id);

      if (deviceId == null) return;

      // Directly query and revoke the device session
      final sessionsQuery = await firestore
          .collection('users')
          .doc(user.id)
          .collection('device_sessions')
          .where('deviceId', isEqualTo: deviceId)
          .get();

      if (sessionsQuery.docs.isEmpty) return;

      // Mark all matching sessions as revoked
      for (final doc in sessionsQuery.docs) {
        await doc.reference.update({'isRevoked': true});
      }
    } catch (e) {
      // Silently fail - cleanup shouldn't block sign out
    }
  }

  /// Ends the current user session.
  Future<void> _endUserSession() async {
    try {
      final sessionService = sl<UserSessionService>();
      await sessionService.endSession();
      debugPrint('Session: Ended session');
    } catch (e) {
      // Silently fail - session tracking shouldn't block sign out
      debugPrint('Session: Failed to end session: $e');
    }
  }

  /// Starts listening to auth state changes.
  void listenToAuthChanges() {
    _authSubscription?.cancel();
    _authSubscription = authRepository.authStateChanges.listen((user) {
      if (isClosed) return;

      if (user != null && !state.isAuthenticated) {
        emit(PhoneAuthState.authenticated(user: user));
        _startUserSession(user);
      } else if (user == null && state.isAuthenticated) {
        _endUserSession();
        emit(const PhoneAuthState.signedOut());
      }
    });
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    _endUserSession();
    return super.close();
  }
}
