import 'dart:developer';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/membership.dart';
import '../../../domain/entities/payment.dart';
import '../../../domain/repositories/payment_repository.dart';
import '../../../domain/usecases/handle_payment_failure.dart';
import '../../../domain/usecases/initiate_cash_payment.dart';
import '../../../domain/usecases/initiate_upi_payment.dart';
import '../../../domain/usecases/mark_upi_as_paid.dart';
import '../../../domain/usecases/renew_membership.dart';
import 'student_payment_state.dart';

/// Cubit for student payment flow.
///
/// Flow (Cash):
/// 1. Student selects cash payment
/// 2. Cash payment record created with pending status
/// 3. Student waits for owner approval
/// 4. On owner approval → membership activated
///
/// Flow (UPI):
/// 1. Student selects UPI payment
/// 2. UPI payment record created
/// 3. Student opens UPI app and pays owner directly
/// 4. Student marks as paid (optionally with UTR/proof)
/// 5. Owner approves → membership activated
class StudentPaymentCubit extends Cubit<StudentPaymentState> {
  StudentPaymentCubit({
    required this.handlePaymentFailure,
    required this.initiateCashPayment,
    required this.initiateUpiPayment,
    required this.markUpiAsPaid,
    required this.paymentRepository,
    required this.renewMembershipUseCase,
  }) : super(const StudentPaymentState());

  final HandlePaymentFailure handlePaymentFailure;
  final InitiateCashPayment initiateCashPayment;
  final InitiateUpiPayment initiateUpiPayment;
  final MarkUpiAsPaid markUpiAsPaid;
  final PaymentRepository paymentRepository;
  final RenewMembership renewMembershipUseCase;

  /// Checks if there's an existing pending payment for the membership.
  /// Call this when loading the payment screen.
  Future<void> checkForExistingPayment(String membershipId) async {
    final result = await paymentRepository.getPaymentByMembershipId(
      membershipId,
    );

    result.fold(
      (failure) {
        // No existing payment or error - continue normally
        log('StudentPaymentCubit: No existing payment found for membership');
      },
      (payment) {
        if (payment != null && payment.status == PaymentStatus.initiated) {
          if (payment.mode == PaymentMode.cash) {
            log(
              'StudentPaymentCubit: Found pending cash payment: ${payment.id}',
            );
            emit(state.copyWith(existingCashPayment: payment));
          } else if (payment.mode == PaymentMode.upi) {
            log(
              'StudentPaymentCubit: Found pending UPI payment: ${payment.id}',
            );
            emit(
              state.copyWith(
                existingCashPayment: payment,
                status: payment.studentMarkedPaidAt != null
                    ? StudentPaymentStatus.upiPending
                    : StudentPaymentStatus.upiAwaitingPayment,
                payment: payment,
              ),
            );
          }
        }
      },
    );
  }

  /// Handles payment failure.
  Future<void> handleFailure({
    required String paymentId,
    required String reason,
  }) async {
    emit(state.copyWith(status: StudentPaymentStatus.failed));

    final result = await handlePaymentFailure(
      HandlePaymentFailureParams(paymentId: paymentId, reason: reason),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(status: StudentPaymentStatus.failed, failure: failure),
      ),
      (failResult) => emit(
        state.copyWith(
          status: StudentPaymentStatus.failed,
          payment: failResult.payment,
        ),
      ),
    );
  }

  /// Initiates cash payment (pending owner approval).
  Future<void> startCashPayment({
    required String membershipId,
    required String userId,
    required String libraryId,
    required double amount,
  }) async {
    emit(
      state.copyWith(
        status: StudentPaymentStatus.initiating,
        clearFailure: true,
      ),
    );

    final result = await initiateCashPayment(
      InitiateCashPaymentParams(
        membershipId: membershipId,
        userId: userId,
        libraryId: libraryId,
        amount: amount,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(status: StudentPaymentStatus.failed, failure: failure),
      ),
      (payment) => emit(
        state.copyWith(
          status: StudentPaymentStatus.cashPending,
          payment: payment,
        ),
      ),
    );
  }

  /// Initiates UPI payment (direct to owner).
  Future<void> startUpiPayment({
    required String membershipId,
    required String userId,
    required String libraryId,
    required double amount,
  }) async {
    emit(
      state.copyWith(
        status: StudentPaymentStatus.initiating,
        clearFailure: true,
      ),
    );

    final result = await initiateUpiPayment(
      InitiateUpiPaymentParams(
        membershipId: membershipId,
        userId: userId,
        libraryId: libraryId,
        amount: amount,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(status: StudentPaymentStatus.failed, failure: failure),
      ),
      (payment) => emit(
        state.copyWith(
          status: StudentPaymentStatus.upiAwaitingPayment,
          payment: payment,
        ),
      ),
    );
  }

  /// Student marks UPI payment as completed (optionally with UTR/proof).
  Future<void> markUpiPaymentAsPaid({
    required String paymentId,
    String? utrNumber,
    String? paymentProofUrl,
  }) async {
    emit(
      state.copyWith(
        status: StudentPaymentStatus.initiating,
        clearFailure: true,
      ),
    );

    final result = await markUpiAsPaid(
      MarkUpiAsPaidParams(
        paymentId: paymentId,
        utrNumber: utrNumber,
        paymentProofUrl: paymentProofUrl,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(status: StudentPaymentStatus.failed, failure: failure),
      ),
      (payment) => emit(
        state.copyWith(
          status: StudentPaymentStatus.upiPending,
          payment: payment,
        ),
      ),
    );
  }

  /// Renews membership (creates new membership starting from expiry date).
  Future<void> renewMembership({
    required String currentMembershipId,
    required String userId,
    required String libraryId,
    required double amount,
    required PaymentMode paymentMethod,
    required MembershipPlan plan,
  }) async {
    emit(
      state.copyWith(
        status: StudentPaymentStatus.initiating,
        clearFailure: true,
      ),
    );

    final result = await renewMembershipUseCase(
      RenewMembershipParams(
        currentMembershipId: currentMembershipId,
        plan: plan,
        amount: amount,
        paymentMethod: paymentMethod,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(status: StudentPaymentStatus.failed, failure: failure),
      ),
      (renewResult) {
        final payment = renewResult.payment;
        if (payment == null) {
          // Membership created but payment failed - show success but note payment needed
          emit(
            state.copyWith(
              status: StudentPaymentStatus.success,
              payment: null,
            ),
          );
        } else if (payment.mode == PaymentMode.cash) {
          emit(
            state.copyWith(
              status: StudentPaymentStatus.cashPending,
              payment: payment,
            ),
          );
        } else {
          emit(
            state.copyWith(
              status: StudentPaymentStatus.upiAwaitingPayment,
              payment: payment,
            ),
          );
        }
      },
    );
  }

  /// Resets state.
  void reset() {
    emit(const StudentPaymentState());
  }
}
