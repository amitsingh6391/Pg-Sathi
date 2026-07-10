import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/user.dart';

/// Repository interface for authentication operations.
/// Handles phone OTP authentication with device binding.
abstract class AuthRepository {
  /// Sends OTP to the given phone number.
  /// Returns verification ID on success.
  Future<Either<Failure, String>> sendOtp(String phoneNumber);

  /// Verifies OTP and signs in the user.
  /// Creates user if first time, otherwise retrieves existing user.
  /// Binds user to device on successful verification.
  Future<Either<Failure, User>> verifyOtp({
    required String verificationId,
    required String otp,
    required String deviceId,
    required UserRole role,
    String? name,
  });

  /// Gets the currently authenticated user.
  /// Returns null if not authenticated.
  Future<Either<Failure, User?>> getCurrentUser();

  /// Signs out the current user.
  Future<Either<Failure, void>> signOut();

  /// Permanently deletes the currently authenticated user's account.
  Future<Either<Failure, void>> deleteAccount();

  /// Checks if a device is already bound to an account.
  Future<Either<Failure, User?>> getUserByDeviceId(String deviceId);

  /// Checks if a phone number is already registered.
  Future<Either<Failure, User?>> getUserByPhone(String phoneNumber);

  /// Stream of authentication state changes.
  Stream<User?> get authStateChanges;

  /// Gets the current device ID.
  Future<Either<Failure, String>> getDeviceId();

  /// Updates the user's profile.
  /// Used for completing profile after sign-in.
  Future<Either<Failure, User>> updateUserProfile({
    required String userId,
    required String name,
    String? avatarUrl,
    String? examPreparingFor,
    bool? isAccessCardIssued,
    String? address,
    String? gender,
  });
}
