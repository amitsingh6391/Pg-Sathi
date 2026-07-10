import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../data/failures/data_failures.dart';
import '../core/core.dart';
import '../entities/membership.dart';
import '../entities/payment.dart';
import '../repositories/membership_repository.dart';
import '../repositories/payment_repository.dart';
import '../repositories/user_repository.dart';

/// Use case for getting all pending cash payments for a library.
/// Used by owner to see list of payments awaiting approval.
class GetPendingCashPayments
    implements
        UseCase<List<PendingCashPaymentInfo>, GetPendingCashPaymentsParams> {
  const GetPendingCashPayments({
    required this.paymentRepository,
    required this.membershipRepository,
    required this.userRepository,
  });

  final PaymentRepository paymentRepository;
  final MembershipRepository membershipRepository;
  final UserRepository userRepository;

  @override
  Future<Either<Failure, List<PendingCashPaymentInfo>>> call(
    GetPendingCashPaymentsParams params,
  ) async {
    try {
      // Get pending cash payments for the library
      final paymentsResult = await paymentRepository.getPendingCashPayments(
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

/// Parameters for GetPendingCashPayments use case.
class GetPendingCashPaymentsParams extends Equatable {
  const GetPendingCashPaymentsParams({required this.libraryId});

  final String libraryId;

  @override
  List<Object?> get props => [libraryId];
}

/// Info about a pending cash payment for display.
class PendingCashPaymentInfo extends Equatable {
  const PendingCashPaymentInfo({
    required this.payment,
    required this.studentName,
    required this.studentPhone,
    required this.seatNumber,
    required this.slot,
    this.membership,
  });

  final Payment payment;
  final String studentName;
  final String studentPhone;
  final String seatNumber;
  final String slot;
  final Membership? membership;

  /// Check if this is a partial payment completion
  bool get isPartialPaymentCompletion => membership?.hasPartialPayment ?? false;

  @override
  List<Object?> get props => [
    payment,
    studentName,
    studentPhone,
    seatNumber,
    slot,
    membership,
  ];
}
