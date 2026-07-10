import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../../domain/core/failure.dart';
import '../../domain/failures/auth_failures.dart';
import '../failures/data_failures.dart';
import 'otp_provider.dart';

/// Firebase implementation of OTP provider.
/// Uses Firebase Phone Authentication.
class FirebaseOtpProvider implements OtpProvider {
  FirebaseOtpProvider({required this.firebaseAuth});

  final firebase_auth.FirebaseAuth firebaseAuth;

  @override
  String get providerName => 'Firebase';

  @override
  Future<Either<Failure, String>> sendOtp(String phoneNumber) async {
    final completer = Completer<Either<Failure, String>>();

    await firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) async {
        // Auto-verification (Android only)
        // We'll handle this in verifyOtp
      },
      verificationFailed: (e) {
        if (e.code == 'too-many-requests') {
          completer.complete(const Left(TooManyRequestsFailure()));
        } else if (e.code == 'invalid-phone-number') {
          completer.complete(const Left(InvalidPhoneNumberFailure()));
        } else if (_isSmsRegionDisabled(e)) {
          completer.complete(
            const Left(
              OtpSendFailure(
                message:
                    'OTP is not enabled for this country yet. Please contact support.',
              ),
            ),
          );
        } else {
          completer.complete(Left(OtpSendFailure(message: e.message)));
        }
      },
      codeSent: (verificationId, resendToken) {
        completer.complete(Right(verificationId));
      },
      codeAutoRetrievalTimeout: (verificationId) {
        // Timeout for auto-retrieval
        if (!completer.isCompleted) {
          completer.complete(Right(verificationId));
        }
      },
      timeout: const Duration(seconds: 60),
    );

    return completer.future;
  }

  bool _isSmsRegionDisabled(firebase_auth.FirebaseAuthException e) {
    final message = e.message?.toLowerCase() ?? '';
    return message.contains('region enabled') ||
        message.contains('sms region') ||
        message.contains('not enabled for this region');
  }

  @override
  Future<Either<Failure, bool>> verifyOtp({
    required String phoneNumber,
    required String verificationId,
    required String otp,
  }) async {
    try {
      // Create credential
      final credential = firebase_auth.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      // Sign in with credential
      final userCredential = await firebaseAuth.signInWithCredential(
        credential,
      );
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        return const Left(NotAuthenticatedFailure());
      }

      return const Right(true);
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code') {
        return const Left(InvalidOtpFailure());
      } else if (e.code == 'session-expired') {
        return const Left(OtpExpiredFailure());
      }
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}
