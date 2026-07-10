import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/user.dart';
import '../failures/auth_failures.dart';
import '../repositories/auth_repository.dart';

/// Use case for verifying OTP and completing authentication.
///
/// On successful verification:
/// - Creates new user if first time registration
/// - Binds user to current device
/// - Returns authenticated user
class VerifyOtp implements UseCase<User, VerifyOtpParams> {
  const VerifyOtp({required this.authRepository});

  final AuthRepository authRepository;

  @override
  Future<Either<Failure, User>> call(VerifyOtpParams params) async {
    // Validate OTP format
    if (!_isValidOtp(params.otp)) {
      return const Left(InvalidOtpFailure(message: 'OTP must be 6 digits'));
    }

    // Get device ID
    final deviceIdResult = await authRepository.getDeviceId();

    return deviceIdResult.fold((failure) => Left(failure), (deviceId) async {
      // Verify OTP with Firebase and create/update user
      return authRepository.verifyOtp(
        verificationId: params.verificationId,
        otp: params.otp,
        deviceId: deviceId,
        role: params.role,
        name: params.name,
      );
    });
  }

  bool _isValidOtp(String otp) {
    return otp.length == 6 && RegExp(r'^\d{6}$').hasMatch(otp);
  }
}

/// Parameters for VerifyOtp use case.
class VerifyOtpParams extends Equatable {
  const VerifyOtpParams({
    required this.verificationId,
    required this.otp,
    required this.role,
    this.name,
  });

  final String verificationId;
  final String otp;
  final UserRole role;
  final String? name;

  @override
  List<Object?> get props => [verificationId, otp, role, name];
}
