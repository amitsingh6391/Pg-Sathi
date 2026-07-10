import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/core/failure.dart';
import '../../domain/failures/auth_failures.dart';
import '../failures/data_failures.dart';
import 'otp_provider.dart';

/// SMS Portals implementation of OTP provider.
/// Sends OTP via SMS Portals bulk SMS service.
class SmsPortalsOtpProvider implements OtpProvider {
  SmsPortalsOtpProvider({
    required this.apiKey,
    required this.senderId,
    required this.dltTemplateId,
    required this.firestore,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String apiKey;
  final String senderId;
  final String dltTemplateId;
  final FirebaseFirestore firestore;
  final http.Client _httpClient;

  // Store OTPs temporarily in memory (for verification)
  final Map<String, _OtpSession> _otpSessions = {};

  @override
  String get providerName => 'SMS Portals';

  @override
  Future<Either<Failure, String>> sendOtp(String phoneNumber) async {
    try {
      // Clean phone number - remove +, spaces, and country code (91)
      // API expects 10-digit number without country code
      var cleanPhone = phoneNumber.replaceAll('+', '').replaceAll(' ', '');
      // Remove country code if present (91 for India)
      if (cleanPhone.startsWith('91') && cleanPhone.length > 10) {
        cleanPhone = cleanPhone.substring(2);
      }

      // Generate 6-digit OTP
      final otp = _generateOtp();

      // Format message according to DLT template
      // Template: "Hi Your User OTP is: {#var#} Thank you ! {#var#}  PTPSMS"
      // Note: Must match EXACTLY including spacing - two spaces before PTPSMS
      final message = 'Hi Your User OTP is: $otp Thank you ! PG Sathi  PTPSMS';

      // Build API URL
      final url = Uri.parse(
        'http://sms.smsportals.org/api_v2/message/send'
        '?api_key=$apiKey'
        '&dlt_template_id=$dltTemplateId'
        '&sender_id=$senderId'
        '&mobile_no=$cleanPhone'
        '&message=${Uri.encodeComponent(message)}'
        '&unicode=0',
      );

      // Send HTTP GET request
      final response = await _httpClient
          .get(url)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // Parse JSON response
        try {
          final jsonResponse =
              json.decode(response.body) as Map<String, dynamic>;
          final success = jsonResponse['success'] as bool? ?? false;

          if (!success) {
            final error = jsonResponse['error'] ?? 'Unknown error';
            return Left(OtpSendFailure(message: 'SMS API error: $error'));
          }
        } catch (e) {
          // Could not parse JSON, assuming success
        }

        // Store OTP session in memory
        final sessionId = _generateSessionId();
        _otpSessions[sessionId] = _OtpSession(
          phoneNumber: phoneNumber,
          otp: otp,
          createdAt: DateTime.now(),
        );

        // Firestore storage is useful for cross-instance verification, but OTP
        // delivery must not fail if unauthenticated rules are not deployed yet.
        try {
          await firestore.collection('otp_sessions').doc(sessionId).set({
            'verificationId': sessionId,
            'phoneNumber': phoneNumber,
            'createdAt': FieldValue.serverTimestamp(),
            'expiresAt': DateTime.now()
                .add(const Duration(minutes: 10))
                .toIso8601String(),
          });
        } catch (e) {
          debugPrint('SMS OTP: Firestore session write skipped: $e');
        }

        // Clean up old sessions (older than 10 minutes)
        _cleanupOldSessions();

        // Return session ID as verification ID
        return Right(sessionId);
      } else if (response.statusCode == 429) {
        return const Left(TooManyRequestsFailure());
      } else {
        return Left(
          OtpSendFailure(
            message:
                'Failed to send OTP: ${response.statusCode} - ${response.body}',
          ),
        );
      }
    } on TimeoutException {
      return const Left(
        OtpSendFailure(message: 'Request timeout. Please try again.'),
      );
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> verifyOtp({
    required String phoneNumber,
    required String verificationId,
    required String otp,
  }) async {
    try {
      // Get OTP session
      final session = _otpSessions[verificationId];

      if (session == null) {
        return const Left(
          OtpExpiredFailure(message: 'OTP session not found or expired'),
        );
      }

      // Check if OTP has expired (10 minutes)
      final now = DateTime.now();
      final difference = now.difference(session.createdAt);
      if (difference.inMinutes > 10) {
        _otpSessions.remove(verificationId);
        return const Left(
          OtpExpiredFailure(
            message: 'OTP has expired. Please request a new one.',
          ),
        );
      }

      // Verify OTP
      if (session.otp == otp) {
        // Remove session after successful verification
        _otpSessions.remove(verificationId);
        return const Right(true);
      } else {
        return const Left(
          InvalidOtpFailure(message: 'Invalid OTP. Please try again.'),
        );
      }
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  /// Returns the phone number for an in-memory SMS OTP session.
  String? phoneNumberForSession(String verificationId) {
    return _otpSessions[verificationId]?.phoneNumber;
  }

  /// Generate a 6-digit OTP
  String _generateOtp() {
    final random = Random.secure();
    final otp = random.nextInt(900000) + 100000; // 100000 to 999999
    return otp.toString();
  }

  /// Generate a unique session ID
  String _generateSessionId() {
    final random = Random.secure();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = random.nextInt(999999);
    return '$timestamp-$randomPart';
  }

  /// Clean up OTP sessions older than 10 minutes
  void _cleanupOldSessions() {
    final now = DateTime.now();
    _otpSessions.removeWhere((key, session) {
      return now.difference(session.createdAt).inMinutes > 10;
    });
  }

  /// Dispose method to clean up resources
  void dispose() {
    _otpSessions.clear();
    _httpClient.close();
  }
}

/// Internal class to store OTP session data
class _OtpSession {
  _OtpSession({
    required this.phoneNumber,
    required this.otp,
    required this.createdAt,
  });

  final String phoneNumber;
  final String otp;
  final DateTime createdAt;
}
