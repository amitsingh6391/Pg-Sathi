import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../data/failures/data_failures.dart';
import '../core/core.dart';
import '../repositories/membership_repository.dart';
import '../repositories/payment_repository.dart';
import '../repositories/user_repository.dart';
import 'get_pending_cash_payments.dart';

/// Use case for fetching all pending approval payments (cash + UPI).
///
/// Business Rules:
/// - Returns payments with mode = cash or upi
/// - Only returns payments where:
///   - Cash: status = initiated
///   - UPI: status = initiated AND studentMarkedPaidAt != null
class GetPendingApprovalPayments
    implements
        UseCase<
          List<PendingCashPaymentInfo>,
          GetPendingApprovalPaymentsParams
        > {
  const GetPendingApprovalPayments({
    required this.paymentRepository,
    required this.membershipRepository,
    required this.userRepository,
  });

  final PaymentRepository paymentRepository;
  final MembershipRepository membershipRepository;
  final UserRepository userRepository;

  @override
  Future<Either<Failure, List<PendingCashPaymentInfo>>> call(
    GetPendingApprovalPaymentsParams params,
  ) async {
    try {
      // Get all pending approval payments (cash + UPI)
      final paymentsResult = await paymentRepository.getPendingApprovalPayments(
        params.libraryId,
      );

      if (paymentsResult.isLeft()) {
        return Left(paymentsResult.fold((l) => l, (r) => throw Error()));
      }

      final payments = paymentsResult.getOrElse(() => []);
      final pendingInfoList = <PendingCashPaymentInfo>[];

      for (final payment in payments) {
        // Get membership details
        final membershipResult = await membershipRepository.getMembershipById(
          payment.membershipId,
        );
        final membership = membershipResult.fold((failure) => null, (m) => m);

        // Get student details
        final userResult = await userRepository.getUserById(payment.userId);
        final user = userResult.fold((failure) => null, (u) => u);

        pendingInfoList.add(
          PendingCashPaymentInfo(
            payment: payment,
            studentName: user?.displayName ?? 'Unknown',
            studentPhone: user?.phone ?? '',
            seatNumber: membership?.assignedSeatId ?? '-',
            slot: membership?.slot?.displayName ?? '-',
            membership: membership,
          ),
        );
      }

      // Sort by creation date (newest first)
      pendingInfoList.sort(
        (a, b) => (b.payment.createdAt ?? DateTime.now()).compareTo(
          a.payment.createdAt ?? DateTime.now(),
        ),
      );

      return Right(pendingInfoList);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}

/// Parameters for GetPendingApprovalPayments use case.
class GetPendingApprovalPaymentsParams extends Equatable {
  const GetPendingApprovalPaymentsParams({required this.libraryId});

  final String libraryId;

  @override
  List<Object?> get props => [libraryId];
}
