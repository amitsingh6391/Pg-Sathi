import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/whatsapp_credits.dart';

/// Repository for an owner's WhatsApp credit wallet.
///
/// The Cloud Functions that send WhatsApp messages are the source of truth for
/// credit *deduction*. This repository covers the app-side concerns: reading
/// the balance and adding purchased credits after a successful payment.
abstract class WhatsAppCreditsRepository {
  /// Fetches the wallet for [ownerId]. Returns a seeded free-credit wallet
  /// when the owner has no record yet.
  Future<Either<Failure, WhatsAppCredits>> getCredits(String ownerId);

  /// Atomically adds [credits] to the owner's wallet after a paid purchase.
  /// Seeds the free grant first if the wallet does not exist yet.
  /// Returns the updated wallet.
  Future<Either<Failure, WhatsAppCredits>> addCredits({
    required String ownerId,
    required int credits,
    required String packId,
    required double amountPaid,
    String? paymentId,
  });

  /// Grants free [credits] exactly once per [grantId] (e.g. one grant per
  /// subscription). Calling again with the same [grantId] is a no-op.
  Future<Either<Failure, WhatsAppCredits>> grantBonusCredits({
    required String ownerId,
    required int credits,
    required String packId,
    required String grantId,
  });
}
