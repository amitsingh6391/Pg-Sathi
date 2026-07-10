import 'package:dartz/dartz.dart';

import '../../domain/core/failure.dart';

/// Abstract interface for OTP providers.
abstract class OtpProvider {
  /// Returns the verification ID on success.
  Future<Either<Failure, String>> sendOtp(String phoneNumber);

  /// Returns true if verification is successful.
  Future<Either<Failure, bool>> verifyOtp({
    required String phoneNumber,
    required String verificationId,
    required String otp,
  });

  /// Get the provider name for logging/debugging
  String get providerName;
}
