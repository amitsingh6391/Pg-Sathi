import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/membership.dart';
import 'package:pg_manager/domain/entities/payment.dart';
import 'package:pg_manager/domain/entities/payment_breakdown.dart';
import 'package:pg_manager/domain/repositories/membership_repository.dart';
import 'package:pg_manager/domain/repositories/payment_repository.dart';
import 'package:pg_manager/domain/usecases/mark_payment_received.dart';
import 'package:mocktail/mocktail.dart';

class MockMembershipRepository extends Mock implements MembershipRepository {}

class MockPaymentRepository extends Mock implements PaymentRepository {}

Membership _sampleMembership({required PaymentMode paymentMethod}) {
  return Membership(
    id: 'm1',
    libraryId: 'lib1',
    plan: MembershipPlan.monthly,
    startDate: DateTime(2025, 1, 1),
    endDate: DateTime(2025, 2, 1),
    status: MembershipStatus.pendingPayment,
    phoneNumber: '999',
    userId: 'u1',
    paymentMethod: paymentMethod,
    paymentStatus: MembershipPaymentStatus.pending,
    paymentBreakdown: const PaymentBreakdown(
      amountPaid: 1000,
      amountRemaining: 0,
    ),
  );
}

void main() {
  late MockMembershipRepository membershipRepo;
  late MockPaymentRepository paymentRepo;
  late MarkPaymentReceived useCase;

  setUpAll(() {
    registerFallbackValue(_sampleMembership(paymentMethod: PaymentMode.cash));
    registerFallbackValue(
      Payment.createCashPayment(
        id: 'fallback',
        membershipId: 'm',
        userId: 'u',
        libraryId: 'l',
        amount: 0,
      ),
    );
  });

  setUp(() {
    membershipRepo = MockMembershipRepository();
    paymentRepo = MockPaymentRepository();
    useCase = MarkPaymentReceived(
      membershipRepository: membershipRepo,
      paymentRepository: paymentRepo,
      generateInvoice: null,
    );
  });

  group('MarkPaymentReceived', () {
    test(
      'should_create_payment_with_upi_mode_when_membership_uses_upi',
      () async {
        final membership = _sampleMembership(paymentMethod: PaymentMode.upi);
        when(
          () => membershipRepo.getMembershipById('m1'),
        ).thenAnswer((_) async => Right(membership));
        when(
          () => paymentRepo.getPaymentsByMembershipId('m1'),
        ).thenAnswer((_) async => const Right(<Payment>[]));
        when(() => membershipRepo.updateMembership(any())).thenAnswer((
          inv,
        ) async {
          return Right(inv.positionalArguments[0] as Membership);
        });
        when(() => paymentRepo.createPayment(any())).thenAnswer((inv) async {
          return Right(inv.positionalArguments[0] as Payment);
        });

        final result = await useCase(
          const MarkPaymentReceivedParams(
            membershipId: 'm1',
            ownerId: 'owner1',
          ),
        );

        expect(result.isRight(), isTrue);
        final captured =
            verify(() => paymentRepo.createPayment(captureAny()))
                .captured
                .single as Payment;
        expect(captured.mode, PaymentMode.upi);
        expect(captured.status, PaymentStatus.success);
      },
    );

    test(
      'should_create_payment_with_cash_mode_when_membership_uses_cash',
      () async {
        final membership = _sampleMembership(paymentMethod: PaymentMode.cash);
        when(
          () => membershipRepo.getMembershipById('m1'),
        ).thenAnswer((_) async => Right(membership));
        when(
          () => paymentRepo.getPaymentsByMembershipId('m1'),
        ).thenAnswer((_) async => const Right(<Payment>[]));
        when(() => membershipRepo.updateMembership(any())).thenAnswer((
          inv,
        ) async {
          return Right(inv.positionalArguments[0] as Membership);
        });
        when(() => paymentRepo.createPayment(any())).thenAnswer((inv) async {
          return Right(inv.positionalArguments[0] as Payment);
        });

        final result = await useCase(
          const MarkPaymentReceivedParams(
            membershipId: 'm1',
            ownerId: 'owner1',
          ),
        );

        expect(result.isRight(), isTrue);
        final captured =
            verify(() => paymentRepo.createPayment(captureAny()))
                .captured
                .single as Payment;
        expect(captured.mode, PaymentMode.cash);
        expect(captured.status, PaymentStatus.success);
      },
    );

    test(
      'should_leave_payment_status_pending_when_activating_from_pending_payment_with_remaining_balance',
      () async {
        final membership = Membership(
          id: 'm1',
          libraryId: 'lib1',
          plan: MembershipPlan.monthly,
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 2, 1),
          status: MembershipStatus.pendingPayment,
          phoneNumber: '999',
          userId: 'u1',
          paymentMethod: PaymentMode.cash,
          paymentStatus: MembershipPaymentStatus.pending,
          paymentBreakdown: const PaymentBreakdown(
            amountPaid: 400,
            amountRemaining: 600,
          ),
        );
        when(
          () => membershipRepo.getMembershipById('m1'),
        ).thenAnswer((_) async => Right(membership));
        when(
          () => paymentRepo.getPaymentsByMembershipId('m1'),
        ).thenAnswer((_) async => const Right(<Payment>[]));
        when(() => membershipRepo.updateMembership(any())).thenAnswer((
          inv,
        ) async {
          return Right(inv.positionalArguments[0] as Membership);
        });
        when(() => paymentRepo.createPayment(any())).thenAnswer((inv) async {
          return Right(inv.positionalArguments[0] as Payment);
        });

        final result = await useCase(
          const MarkPaymentReceivedParams(
            membershipId: 'm1',
            ownerId: 'owner1',
          ),
        );

        expect(result.isRight(), isTrue);
        final saved =
            verify(() => membershipRepo.updateMembership(captureAny()))
                .captured
                .single as Membership;
        expect(saved.status, MembershipStatus.active);
        expect(saved.paymentStatus, MembershipPaymentStatus.pending);
      },
    );

    test(
      'should_process_final_installment_when_active_pending_and_breakdown_fully_paid',
      () async {
        final membership = Membership(
          id: 'm1',
          libraryId: 'lib1',
          plan: MembershipPlan.monthly,
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 2, 1),
          status: MembershipStatus.active,
          phoneNumber: '999',
          userId: 'u1',
          paymentMethod: PaymentMode.cash,
          paymentStatus: MembershipPaymentStatus.pending,
          paymentBreakdown: const PaymentBreakdown(
            amountPaid: 1000,
            amountRemaining: 0,
          ),
        );
        final priorPayment = Payment.createCashPayment(
          id: 'p1',
          membershipId: 'm1',
          userId: 'u1',
          libraryId: 'lib1',
          amount: 400,
        ).approveCashPayment('owner1');

        when(
          () => membershipRepo.getMembershipById('m1'),
        ).thenAnswer((_) async => Right(membership));
        when(() => paymentRepo.getPaymentsByMembershipId('m1')).thenAnswer(
          (_) async => Right(<Payment>[priorPayment]),
        );
        when(() => membershipRepo.updateMembership(any())).thenAnswer((
          inv,
        ) async {
          return Right(inv.positionalArguments[0] as Membership);
        });
        when(() => paymentRepo.createPayment(any())).thenAnswer((inv) async {
          return Right(inv.positionalArguments[0] as Payment);
        });

        final result = await useCase(
          const MarkPaymentReceivedParams(
            membershipId: 'm1',
            ownerId: 'owner1',
          ),
        );

        expect(result.isRight(), isTrue);
        verify(() => paymentRepo.createPayment(captureAny())).called(1);
        final saved =
            verify(() => membershipRepo.updateMembership(captureAny()))
                .captured
                .single as Membership;
        expect(saved.paymentStatus, MembershipPaymentStatus.markedPaid);
      },
    );
  });
}
