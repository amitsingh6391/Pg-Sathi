import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../../domain/core/auth_constants.dart';
import '../../domain/core/failure.dart';
import '../../domain/entities/user.dart';
import '../../domain/failures/auth_failures.dart';
import '../../domain/repositories/auth_repository.dart';
import '../failures/data_failures.dart';
import '../mappers/user_mapper.dart';
import '../models/user_dto.dart';
import '../providers/firebase_otp_provider.dart';
import '../providers/otp_provider.dart';
import '../providers/sms_portals_otp_provider.dart';
import '../services/device_info_service.dart';
import '../services/otp_quota_service.dart';
import '../utils/firebase_error_handler.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this.firebaseAuth,
    required this.firestore,
    required this.deviceInfoService,
    required this.otpProvider,
    required this.functions,
    required this.firebaseOtpProvider,
    required this.smsPortalsOtpProvider,
    required this.otpQuotaService,
    required this.remoteConfig,
  });

  final firebase_auth.FirebaseAuth firebaseAuth;
  final FirebaseFunctions functions;
  final FirebaseFirestore firestore;
  final DeviceInfoService deviceInfoService;
  final OtpProvider otpProvider;
  final FirebaseOtpProvider firebaseOtpProvider;
  final SmsPortalsOtpProvider smsPortalsOtpProvider;
  final OtpQuotaService otpQuotaService;
  final FirebaseRemoteConfig remoteConfig;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      firestore.collection(UserDto.collectionName);

  @override
  Future<Either<Failure, String>> sendOtp(String phoneNumber) async {
    // Priority 0: Test numbers always use Firebase (bypass all checks)
    if (AuthConstants.isTestNumber(phoneNumber)) {
      return firebaseOtpProvider.sendOtp(phoneNumber);
    }

    // Mobile can complete the full login with Firebase Phone Auth alone.
    // SMS Portals requires createCustomToken Cloud Function after OTP verify,
    // which is only available after the Firebase project is on Blaze.
    if (!kIsWeb) {
      final result = await firebaseOtpProvider.sendOtp(phoneNumber);

      return result.fold((failure) => Left(failure), (verificationId) async {
        await otpQuotaService.incrementFirebaseOtpCount();
        return Right(verificationId);
      });
    }

    // Remote Config Priority 1: Force Firebase only (ignore quota)
    final forceFirebaseOtp = remoteConfig.getBool('force_firebase_otp');

    if (forceFirebaseOtp) {
      // Emergency override - always use Firebase (even if quota exceeded)
      // Use this when SMS Portals service is down
      final result = await firebaseOtpProvider.sendOtp(phoneNumber);

      return result.fold(
        (failure) => Left(failure), // Don't fallback, let it fail
        (verificationId) async {
          await otpQuotaService.incrementFirebaseOtpCount();
          return Right(verificationId);
        },
      );
    }

    // Remote Config Priority 2: Force SMS Portals
    final forceSmsOtp = remoteConfig.getBool('force_sms_otp');

    if (forceSmsOtp) {
      // Emergency override - always use SMS Portals
      return smsPortalsOtpProvider.sendOtp(phoneNumber);
    }

    // Normal flow: Check Firebase OTP quota
    final canUseFirebase = await otpQuotaService.canUseFirebaseOtp();

    if (canUseFirebase) {
      // Try Firebase OTP (free)
      final result = await firebaseOtpProvider.sendOtp(phoneNumber);

      return result.fold(
        (failure) async {
          // Firebase failed, fall back to SMS Portals
          return smsPortalsOtpProvider.sendOtp(phoneNumber);
        },
        (verificationId) async {
          // Firebase OTP sent successfully, increment count
          await otpQuotaService.incrementFirebaseOtpCount();
          return Right(verificationId);
        },
      );
    } else {
      // Quota exhausted (10/day), use SMS Portals
      return smsPortalsOtpProvider.sendOtp(phoneNumber);
    }
  }

  @override
  Future<Either<Failure, User>> verifyOtp({
    required String verificationId,
    required String otp,
    required String deviceId,
    required UserRole role,
    String? name,
  }) async {
    try {
      // Detect which provider sent the OTP. SMS Portals may create a
      // Firestore session, but login must still work if unauthenticated
      // Firestore rules are not deployed yet.
      QuerySnapshot<Map<String, dynamic>>? otpSessionQuery;
      try {
        otpSessionQuery = await firestore
            .collection('otp_sessions')
            .where('verificationId', isEqualTo: verificationId)
            .limit(1)
            .get();
      } catch (e) {
        debugPrint('Auth: OTP session lookup skipped: $e');
      }

      final localSmsPhoneNumber = smsPortalsOtpProvider.phoneNumberForSession(
        verificationId,
      );
      final isSmsPortalsOtp =
          (otpSessionQuery?.docs.isNotEmpty ?? false) ||
          localSmsPhoneNumber != null;
      String? phoneNumber;

      if (isSmsPortalsOtp) {
        // SMS Portals OTP - has Firestore session
        phoneNumber = (otpSessionQuery?.docs.isNotEmpty ?? false)
            ? otpSessionQuery!.docs.first.data()['phoneNumber'] as String?
            : localSmsPhoneNumber;

        if (phoneNumber == null) {
          return const Left(InvalidOtpFailure());
        }

        // Verify with SMS Portals provider
        final verifyResult = await smsPortalsOtpProvider.verifyOtp(
          phoneNumber: phoneNumber,
          verificationId: verificationId,
          otp: otp,
        );

        if (verifyResult.isLeft()) {
          return verifyResult.fold(
            (failure) => Left(failure),
            (_) => const Left(InvalidOtpFailure()),
          );
        }

        // Clean up Firestore session if it was stored.
        if (otpSessionQuery?.docs.isNotEmpty ?? false) {
          await otpSessionQuery!.docs.first.reference.delete();
        }

        // Create Firebase Auth user via custom token
        try {
          final callable = functions.httpsCallable('createCustomToken');
          final result = await callable.call<Map<String, dynamic>>({
            'phoneNumber': phoneNumber,
          });

          final customToken = result.data['customToken'] as String;
          await firebaseAuth.signInWithCustomToken(customToken);
        } catch (e) {
          return Left(ServerFailure(message: 'Failed to authenticate: $e'));
        }
      } else {
        // Firebase OTP - no Firestore session, verify directly
        final verifyResult = await firebaseOtpProvider.verifyOtp(
          phoneNumber: '', // Not needed for Firebase verification
          verificationId: verificationId,
          otp: otp,
        );

        if (verifyResult.isLeft()) {
          return verifyResult.fold(
            (failure) => Left(failure),
            (_) => const Left(InvalidOtpFailure()),
          );
        }

        // Firebase provider signed us in, get phone from current user
        phoneNumber = firebaseAuth.currentUser?.phoneNumber;
        if (phoneNumber == null) {
          return const Left(InvalidOtpFailure());
        }
      }

      // Now get/create user in Firestore with Firebase UID
      final firebaseUser = firebaseAuth.currentUser;
      if (firebaseUser == null) {
        return const Left(ServerFailure(message: 'Firebase Auth failed'));
      }

      final userId = firebaseUser.uid;
      final userDoc = await _usersCollection.doc(userId).get();

      User user;
      if (userDoc.exists) {
        // Existing user - update device binding
        final existingDto = UserDto.fromFirestore(userDoc);
        user = UserMapper.toEntity(
          existingDto,
        ).copyWith(deviceId: deviceId, isPhoneVerified: true);

        await _usersCollection.doc(userId).update({
          'deviceId': deviceId,
          'isPhoneVerified': true,
        });
      } else {
        // New user - create in Firestore
        user = User(
          id: userId,
          name: name ?? 'User',
          phone: phoneNumber,
          role: role,
          deviceId: deviceId,
          isPhoneVerified: true,
          createdAt: DateTime.now(),
        );

        final dto = UserMapper.toDto(user);
        await _usersCollection.doc(userId).set(dto.toFirestore());
      }

      return Right(user);
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

  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    try {
      final firebaseUser = firebaseAuth.currentUser;
      if (firebaseUser == null) {
        return const Right(null);
      }

      final userDoc = await _usersCollection.doc(firebaseUser.uid).get();
      if (!userDoc.exists) {
        return const Right(null);
      }

      final dto = UserDto.fromFirestore(userDoc);
      return Right(UserMapper.toEntity(dto));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        await firebaseAuth.signOut();
        debugPrint(
          'Auth: Signed out stale cached user after permission denial.',
        );
        return const Right(null);
      }
      return FirebaseErrorHandler.guard(() => Future.error(e, e.stackTrace));
    } catch (e, stackTrace) {
      return FirebaseErrorHandler.guard(() => Future.error(e, stackTrace));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    return FirebaseErrorHandler.guard(() async {
      await firebaseAuth.signOut();
    });
  }

  @override
  Future<Either<Failure, void>> deleteAccount() async {
    try {
      final firebaseUser = firebaseAuth.currentUser;
      if (firebaseUser == null) {
        return const Left(ServerFailure(message: 'No signed-in user found'));
      }

      final userRef = _usersCollection.doc(firebaseUser.uid);
      final batch = firestore.batch();

      final deviceSessions = await userRef.collection('device_sessions').get();
      for (final session in deviceSessions.docs) {
        batch.delete(session.reference);
      }
      batch.delete(userRef);
      await batch.commit();

      await firebaseUser.delete();
      await firebaseAuth.signOut();

      return const Right(null);
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return const Left(
          ServerFailure(
            message: 'Please sign out, sign in again, and retry deletion.',
          ),
        );
      }
      return Left(
        ServerFailure(message: e.message ?? 'Account deletion failed'),
      );
    } catch (e, stackTrace) {
      return FirebaseErrorHandler.guard(() => Future.error(e, stackTrace));
    }
  }

  @override
  Future<Either<Failure, User?>> getUserByDeviceId(String deviceId) async {
    return FirebaseErrorHandler.guard(() async {
      final query = await _usersCollection
          .where('deviceId', isEqualTo: deviceId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return null;
      }

      final dto = UserDto.fromFirestore(query.docs.first);
      return UserMapper.toEntity(dto);
    });
  }

  @override
  Future<Either<Failure, User?>> getUserByPhone(String phoneNumber) async {
    return FirebaseErrorHandler.guard(() async {
      final query = await _usersCollection
          .where('phone', isEqualTo: phoneNumber)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return null;
      }

      final dto = UserDto.fromFirestore(query.docs.first);
      return UserMapper.toEntity(dto);
    });
  }

  @override
  Stream<User?> get authStateChanges {
    return firebaseAuth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) {
        return null;
      }

      final userDoc = await _usersCollection.doc(firebaseUser.uid).get();
      if (!userDoc.exists) {
        return null;
      }

      final dto = UserDto.fromFirestore(userDoc);
      return UserMapper.toEntity(dto);
    });
  }

  @override
  Future<Either<Failure, String>> getDeviceId() {
    return deviceInfoService.getDeviceId();
  }

  @override
  Future<Either<Failure, User>> updateUserProfile({
    required String userId,
    required String name,
    String? avatarUrl,
    String? examPreparingFor,
    bool? isAccessCardIssued,
    String? address,
    String? gender,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      // Update profile fields in Firestore
      final updateData = <String, dynamic>{
        'name': name,
        'isProfileComplete': true,
      };

      if (avatarUrl != null) {
        updateData['avatarUrl'] = avatarUrl;
      }
      if (examPreparingFor != null) {
        updateData['examPreparingFor'] = examPreparingFor;
      }
      if (isAccessCardIssued != null) {
        updateData['isAccessCardIssued'] = isAccessCardIssued;
      }
      if (address != null) {
        updateData['address'] = address;
      }
      if (gender != null) {
        updateData['gender'] = gender;
      }

      await _usersCollection.doc(userId).update(updateData);

      // Fetch and return updated user
      final userDoc = await _usersCollection.doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('User not found after update');
      }

      final dto = UserDto.fromFirestore(userDoc);
      return UserMapper.toEntity(dto);
    });
  }
}
