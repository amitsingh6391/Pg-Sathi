import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/whatsapp_credits.dart';
import '../../../domain/usecases/whatsapp_credits_usecases.dart';

/// Drives the WhatsApp credits wallet screen: loading the balance and
/// crediting a purchased pack after payment succeeds.
class WhatsAppCreditsCubit extends Cubit<WhatsAppCreditsState> {
  WhatsAppCreditsCubit({
    required this.getWhatsAppCredits,
    required this.addWhatsAppCredits,
  }) : super(const WhatsAppCreditsState());

  final GetWhatsAppCredits getWhatsAppCredits;
  final AddWhatsAppCredits addWhatsAppCredits;

  String? _ownerId;

  Future<void> load(String ownerId) async {
    _ownerId = ownerId;
    emit(state.copyWith(status: WhatsAppCreditsStatus.loading));
    final result = await getWhatsAppCredits(ownerId);
    result.fold(
      (f) => emit(state.copyWith(
        status: WhatsAppCreditsStatus.error,
        errorMessage: f.message ?? 'Failed to load credits',
      )),
      (credits) => emit(state.copyWith(
        status: WhatsAppCreditsStatus.loaded,
        credits: credits,
      )),
    );
  }

  /// Called after a successful Razorpay payment to add the pack's credits.
  Future<void> creditPurchasedPack({
    required WhatsAppCreditPack pack,
    required double amountPaid,
    String? paymentId,
  }) async {
    final ownerId = _ownerId;
    if (ownerId == null) return;

    emit(state.copyWith(status: WhatsAppCreditsStatus.purchasing));
    final result = await addWhatsAppCredits(
      AddWhatsAppCreditsParams(
        ownerId: ownerId,
        pack: pack,
        amountPaid: amountPaid,
        paymentId: paymentId,
      ),
    );
    result.fold(
      (f) => emit(state.copyWith(
        status: WhatsAppCreditsStatus.error,
        errorMessage: f.message ?? 'Failed to add credits',
      )),
      (credits) => emit(state.copyWith(
        status: WhatsAppCreditsStatus.purchaseSuccess,
        credits: credits,
        lastPurchasedCredits: pack.credits,
      )),
    );
  }
}

enum WhatsAppCreditsStatus {
  initial,
  loading,
  loaded,
  purchasing,
  purchaseSuccess,
  error,
}

class WhatsAppCreditsState extends Equatable {
  const WhatsAppCreditsState({
    this.status = WhatsAppCreditsStatus.initial,
    this.credits,
    this.errorMessage,
    this.lastPurchasedCredits,
  });

  final WhatsAppCreditsStatus status;
  final WhatsAppCredits? credits;
  final String? errorMessage;
  final int? lastPurchasedCredits;

  bool get isLoading => status == WhatsAppCreditsStatus.loading;
  bool get isPurchasing => status == WhatsAppCreditsStatus.purchasing;
  int get availableCredits => credits?.availableCredits ?? 0;

  WhatsAppCreditsState copyWith({
    WhatsAppCreditsStatus? status,
    WhatsAppCredits? credits,
    String? errorMessage,
    int? lastPurchasedCredits,
  }) {
    return WhatsAppCreditsState(
      status: status ?? this.status,
      credits: credits ?? this.credits,
      errorMessage: errorMessage,
      lastPurchasedCredits: lastPurchasedCredits ?? this.lastPurchasedCredits,
    );
  }

  @override
  List<Object?> get props =>
      [status, credits, errorMessage, lastPurchasedCredits];
}
