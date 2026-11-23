import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/whatsapp_credits.dart';
import '../repositories/whatsapp_credits_repository.dart';

/// Reads an owner's WhatsApp credit wallet.
class GetWhatsAppCredits implements UseCase<WhatsAppCredits, String> {
  const GetWhatsAppCredits({required this.repository});

  final WhatsAppCreditsRepository repository;

  @override
  Future<Either<Failure, WhatsAppCredits>> call(String ownerId) {
    return repository.getCredits(ownerId);
  }
}

/// Adds a purchased credit pack to the wallet after a successful payment.
class AddWhatsAppCredits
    implements UseCase<WhatsAppCredits, AddWhatsAppCreditsParams> {
  const AddWhatsAppCredits({required this.repository});

  final WhatsAppCreditsRepository repository;

  @override
  Future<Either<Failure, WhatsAppCredits>> call(
    AddWhatsAppCreditsParams params,
  ) {
    return repository.addCredits(
      ownerId: params.ownerId,
      credits: params.pack.credits,
      packId: params.pack.id,
      amountPaid: params.amountPaid,
      paymentId: params.paymentId,
    );
  }
}

class AddWhatsAppCreditsParams extends Equatable {
  const AddWhatsAppCreditsParams({
    required this.ownerId,
    required this.pack,
    required this.amountPaid,
    this.paymentId,
  });

  final String ownerId;
  final WhatsAppCreditPack pack;
  final double amountPaid;
  final String? paymentId;

  @override
  List<Object?> get props => [ownerId, pack, amountPaid, paymentId];
}
