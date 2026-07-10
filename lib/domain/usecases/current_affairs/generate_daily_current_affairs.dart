import 'package:cloud_functions/cloud_functions.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/failure.dart';
import '../../entities/current_affair.dart';
import 'current_affairs_usecases.dart';

/// In-app fallback for daily current affairs generation.
///
/// Triggered when the student screen loads and no articles exist for today.
/// Delegates to the [generateCurrentAffairsOnDemand] Firebase Cloud Function,
/// which fetches real RSS headlines and generates Hindi articles via Groq.
/// The primary source is the scheduled Cloud Functions (8 AM / 2 PM / 6 PM IST).
class GenerateDailyCurrentAffairs {
  const GenerateDailyCurrentAffairs({
    required this.functions,
    required this.firebaseAuth,
  });

  final FirebaseFunctions functions;
  final FirebaseAuth firebaseAuth;

  Future<Either<Failure, List<CurrentAffair>>> call({
    bool sendNotification = true,
  }) async {
    try {
      // Force-refresh the ID token so context.auth is never null in the
      // Cloud Function even after a long idle session.
      final user = firebaseAuth.currentUser;
      if (user == null) {
        return const Left(CurrentAffairsFailure(message: 'Not signed in'));
      }
      try {
        final token = await user.getIdToken(true);
        debugPrint('[Daily Generate] Token refreshed: ${token != null ? "OK" : "null"}');
      } catch (e) {
        debugPrint('[Daily Generate] Token refresh error: $e');
        return Left(CurrentAffairsFailure(
          message: 'Auth token refresh failed. Please sign out and sign in again.',
        ));
      }

      final callable =
          functions.httpsCallable('generateCurrentAffairsOnDemand');
      await callable.call<Map<String, dynamic>>({'count': 3});
      // Articles saved server-side — cubit will reload on Right().
      return const Right([]);
    } on FirebaseFunctionsException catch (e) {
      return Left(
        CurrentAffairsFailure(
            message: e.message ?? 'Cloud Function error: ${e.code}'),
      );
    } catch (e) {
      return Left(
        CurrentAffairsFailure(message: 'Auto-generation failed: $e'),
      );
    }
  }
}
