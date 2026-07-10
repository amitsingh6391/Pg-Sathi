import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../failures/auth_failures.dart';
import '../repositories/auth_repository.dart';

/// Use case for sending OTP to a phone number.
///
/// Validates phone number format before sending.
class SendOtp implements UseCase<String, SendOtpParams> {
  const SendOtp({required this.authRepository});

  final AuthRepository authRepository;

  @override
  Future<Either<Failure, String>> call(SendOtpParams params) async {
    // Validate phone number format
    if (!_isValidPhoneNumber(params.phoneNumber)) {
      return const Left(InvalidPhoneNumberFailure());
    }

    // Send OTP directly - no device binding restrictions
    return authRepository.sendOtp(params.phoneNumber);
  }

  bool _isValidPhoneNumber(String phone) {
    // Basic validation: starts with + and has 10-15 digits
    final phoneRegex = RegExp(r'^\+[1-9]\d{9,14}$');
    return phoneRegex.hasMatch(phone);
  }
}

/// Parameters for SendOtp use case.
class SendOtpParams extends Equatable {
  const SendOtpParams({required this.phoneNumber});

  final String phoneNumber;

  @override
  List<Object?> get props => [phoneNumber];
}
