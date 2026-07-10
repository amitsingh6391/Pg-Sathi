import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../domain/core/failure.dart';
import '../../../domain/entities/user.dart';

part 'phone_auth_state.freezed.dart';

/// State for phone authentication cubit using Freezed.
@freezed
class PhoneAuthState with _$PhoneAuthState {
  const PhoneAuthState._();

  /// Initial state - waiting for user input.
  const factory PhoneAuthState.initial({
    @Default(UserRole.student) UserRole selectedRole,
  }) = PhoneAuthInitial;

  /// Sending OTP to phone number.
  const factory PhoneAuthState.sendingOtp({
    required String phoneNumber,
    @Default(UserRole.student) UserRole selectedRole,
  }) = PhoneAuthSendingOtp;

  /// OTP sent - waiting for user to enter code.
  const factory PhoneAuthState.otpSent({
    required String phoneNumber,
    required String verificationId,
    @Default(UserRole.student) UserRole selectedRole,
  }) = PhoneAuthOtpSent;

  /// Verifying the OTP code.
  const factory PhoneAuthState.verifyingOtp({
    required String phoneNumber,
    required String verificationId,
    @Default(UserRole.student) UserRole selectedRole,
  }) = PhoneAuthVerifyingOtp;

  /// Checking existing auth status.
  const factory PhoneAuthState.checkingAuth() = PhoneAuthCheckingAuth;

  /// User is authenticated.
  const factory PhoneAuthState.authenticated({required User user}) =
      PhoneAuthAuthenticated;

  /// Signing out in progress.
  const factory PhoneAuthState.signingOut() = PhoneAuthSigningOut;

  /// User has signed out.
  const factory PhoneAuthState.signedOut() = PhoneAuthSignedOut;

  /// Error occurred.
  const factory PhoneAuthState.error({
    required Failure failure,
    String? phoneNumber,
    String? verificationId,
    @Default(UserRole.student) UserRole selectedRole,
  }) = PhoneAuthError;

  /// Whether authentication is complete.
  bool get isAuthenticated => this is PhoneAuthAuthenticated;

  /// Whether OTP can be submitted.
  bool get canSubmitOtp => this is PhoneAuthOtpSent;

  /// Get the current user if authenticated.
  User? get currentUser => mapOrNull(authenticated: (state) => state.user);
}
