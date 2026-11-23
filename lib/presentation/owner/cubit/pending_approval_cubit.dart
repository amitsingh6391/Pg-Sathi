import 'dart:developer';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/services/membership_notification_service.dart';
import '../../../domain/entities/invoice.dart';
import '../../../domain/entities/membership.dart';
import '../../../domain/entities/payment.dart';
import '../../../domain/repositories/membership_repository.dart';
import '../../../domain/repositories/payment_repository.dart';
import '../../../domain/repositories/slot_repository.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../../domain/repositories/whatsapp_notification_repository.dart';
import '../../../domain/usecases/generate_invoice.dart';
import 'pending_approval_state.dart';

export 'pending_approval_state.dart';

/// Owner-side cubit for resident bed requests (memberships awaiting approval).
///
/// Approve: membership becomes active, resident is notified, and (optionally)
/// the first payment record + invoice are created.
/// Reject: membership is cancelled and the resident is notified with an
/// optional reason.
class PendingApprovalCubit extends Cubit<PendingApprovalState> {
  PendingApprovalCubit({
    required this.membershipRepository,
    required this.notificationService,
    required this.userRepository,
    required this.slotRepository,
    required this.paymentRepository,
    this.generateInvoice,
    this.whatsAppNotificationRepository,
  }) : super(const PendingApprovalState());

  final MembershipRepository membershipRepository;
  final MembershipNotificationService notificationService;
  final UserRepository userRepository;
  final SlotRepository slotRepository;
  final PaymentRepository paymentRepository;
  final GenerateInvoice? generateInvoice;
  final WhatsAppNotificationRepository? whatsAppNotificationRepository;

  String? _libraryId;
  String _ownerId = '';

  Future<void> loadPendingApprovals(String libraryId, {String? ownerId}) async {
    _libraryId = libraryId;
    if (ownerId != null) _ownerId = ownerId;
    emit(state.copyWith(status: PendingApprovalStatus.loading));

    final result = await membershipRepository.getPendingSeatRequestMemberships(
      libraryId,
    );
    if (isClosed) return;

    await result.fold(
      (failure) async => emit(
        state.copyWith(
          status: PendingApprovalStatus.error,
          errorMessage: failure.message ?? 'Failed to load bed requests',
        ),
      ),
      (memberships) async {
        final userNames = <String, String>{};
        final slotNames = <String, String>{};
        final slotPrices = <String, double>{};

        final userIds = memberships
            .where((m) => m.userId != null)
            .map((m) => m.userId!)
            .toSet();
        final hasSlots = memberships.any(
          (m) => m.slotId != null && m.slotId!.isNotEmpty,
        );

        if (userIds.isNotEmpty) {
          final usersResult = await userRepository.getUsersByIds(
            userIds.toList(),
          );
          usersResult.fold((_) {}, (users) {
            for (final entry in users.entries) {
              final user = entry.value;
              userNames[entry.key] = user.name.isNotEmpty
                  ? user.name
                  : user.phone;
            }
          });
        }

        if (hasSlots) {
          final slotsResult = await slotRepository.getSlotsByLibraryId(
            libraryId,
          );
          slotsResult.fold((_) {}, (slots) {
            for (final slot in slots) {
              slotNames[slot.id] = slot.name;
              slotPrices[slot.id] = slot.price;
            }
          });
        }

        if (isClosed) return;
        emit(
          state.copyWith(
            status: PendingApprovalStatus.loaded,
            memberships: memberships,
            userNames: userNames,
            slotNames: slotNames,
            slotPrices: slotPrices,
          ),
        );
      },
    );
  }

  /// Approves a bed request. When [recordPayment] is true the first payment is
  /// recorded as received and an invoice is generated.
  Future<void> approveMembership({
    required Membership membership,
    required String libraryName,
    bool recordPayment = true,
  }) async {
    if (state.processingIds.contains(membership.id)) return;
    _setProcessing(membership.id, true);

    // The request did not reserve the bed, so make sure nobody else took it
    // in the meantime.
    final conflict = await _findBedConflict(membership);
    if (conflict != null) {
      _setProcessing(membership.id, false);
      emit(
        state.copyWith(
          errorMessage:
              'Bed ${membership.assignedSeatId} is already occupied until '
              '${conflict.endDate.toString().split(' ')[0]}. Reject this '
              'request or free the bed first.',
        ),
      );
      return;
    }

    final approved = recordPayment
        ? membership.approve().copyWith(
            paymentStatus: MembershipPaymentStatus.markedPaid,
          )
        : membership.approve();
    final result = await membershipRepository.updateMembership(approved);
    if (isClosed) return;

    await result.fold(
      (failure) async {
        _setProcessing(membership.id, false);
        emit(
          state.copyWith(
            errorMessage: failure.message ?? 'Failed to approve request',
          ),
        );
      },
      (_) async {
        _removeRequest(membership.id, info: 'Request approved');
        _notifyStudentApproved(membership, libraryName);
        if (recordPayment) {
          await _createPaymentAndInvoice(approved);
        }
      },
    );
  }

  Future<void> rejectMembership({
    required Membership membership,
    required String libraryName,
    String? reason,
  }) async {
    if (state.processingIds.contains(membership.id)) return;
    _setProcessing(membership.id, true);

    final rejected = membership.copyWith(status: MembershipStatus.cancelled);
    final result = await membershipRepository.updateMembership(rejected);
    if (isClosed) return;

    result.fold(
      (failure) {
        _setProcessing(membership.id, false);
        emit(
          state.copyWith(
            errorMessage: failure.message ?? 'Failed to reject request',
          ),
        );
      },
      (_) {
        _removeRequest(membership.id, info: 'Request rejected');
        _notifyStudentRejected(membership, libraryName, reason);
      },
    );
  }

  // ---------------------------------------------------------------------------

  void _setProcessing(String id, bool processing) {
    if (isClosed) return;
    final ids = {...state.processingIds};
    processing ? ids.add(id) : ids.remove(id);
    emit(state.copyWith(processingIds: ids));
  }

  void _removeRequest(String id, {required String info}) {
    if (isClosed) return;
    final ids = {...state.processingIds}..remove(id);
    emit(
      state.copyWith(
        memberships: state.memberships.where((m) => m.id != id).toList(),
        processingIds: ids,
        infoMessage: info,
      ),
    );
  }

  /// Returns an active/reserved stay that overlaps the requested bed, if any.
  Future<Membership?> _findBedConflict(Membership request) async {
    final seatId = request.assignedSeatId;
    final libraryId = _libraryId ?? request.libraryId;
    if (seatId == null || seatId.trim().isEmpty) return null;

    final result = await membershipRepository
        .getActiveAndReservedMembershipsForLibrary(libraryId);
    return result.fold((_) => null, (all) {
      for (final m in all) {
        if (m.id == request.id) continue;
        if (m.assignedSeatId?.trim().toUpperCase() !=
            seatId.trim().toUpperCase()) {
          continue;
        }
        if (m.status != MembershipStatus.active &&
            m.status != MembershipStatus.pendingPayment) {
          continue;
        }
        if (request.startDate.isBefore(m.endDate)) return m;
      }
      return null;
    });
  }

  void _notifyStudentApproved(Membership membership, String libraryName) {
    if (membership.userId == null) return;
    final slotName = state.slotNames[membership.slotId] ?? '';
    notificationService.notifyStudentSeatRequestApproved(
      studentId: membership.userId!,
      libraryName: libraryName,
      seatId: membership.assignedSeatId ?? '',
      slotName: slotName,
      membershipId: membership.id,
    );
  }

  void _notifyStudentRejected(
    Membership membership,
    String libraryName,
    String? reason,
  ) {
    if (membership.userId == null) return;
    notificationService.notifyStudentSeatRequestRejected(
      studentId: membership.userId!,
      libraryName: libraryName,
      membershipId: membership.id,
      reason: reason,
    );
  }

  /// Creates an approved payment record, generates the invoice and sends it on
  /// WhatsApp. Failures are logged only; the approval itself already succeeded.
  Future<void> _createPaymentAndInvoice(Membership membership) async {
    try {
      final paymentAmount = await _paymentAmount(membership);
      if (paymentAmount <= 0) return;

      final isUpi = membership.paymentMethod == PaymentMode.upi;
      final paymentId = DateTime.now().millisecondsSinceEpoch.toString();
      final userId = membership.userId ?? '';

      final base = isUpi
          ? Payment.createUpiPayment(
              id: paymentId,
              membershipId: membership.id,
              userId: userId,
              libraryId: membership.libraryId,
              amount: paymentAmount,
            )
          : Payment.createCashPayment(
              id: paymentId,
              membershipId: membership.id,
              userId: userId,
              libraryId: membership.libraryId,
              amount: paymentAmount,
            );
      final approvedPayment = isUpi
          ? base.approveUpiPayment(_ownerId)
          : base.approveCashPayment(_ownerId);
      // Keep the UPI reference the resident entered on the bed request.
      final payment = isUpi && membership.upiTransactionId != null
          ? approvedPayment.copyWith(utrNumber: membership.upiTransactionId)
          : approvedPayment;

      final saved = await paymentRepository.createPayment(payment);
      final savedPayment = saved.fold((f) {
        log('PendingApprovalCubit: Failed to create payment - ${f.message}');
        return null;
      }, (p) => p);
      if (savedPayment == null || generateInvoice == null) return;

      final invoiceResult = await generateInvoice!(
        GenerateInvoiceParams(
          membershipId: membership.id,
          paymentId: savedPayment.id,
          paymentDate: DateTime.now(),
          amountPaid: paymentAmount,
          currency: savedPayment.currency,
        ),
      );
      invoiceResult.fold(
        (f) => log('PendingApprovalCubit: Invoice failed - ${f.message}'),
        _sendWhatsAppInvoice,
      );
    } catch (e) {
      log('PendingApprovalCubit: Payment/invoice creation error - $e');
    }
  }

  /// Breakdown total when it carries an amount, otherwise room price scaled by
  /// stay duration (months).
  Future<double> _paymentAmount(Membership membership) async {
    final breakdownTotal = membership.paymentBreakdown?.totalAmount ?? 0.0;
    if (breakdownTotal > 0) return breakdownTotal;

    final slotId = membership.slotId;
    if (slotId != null && slotId.isNotEmpty) {
      final slotResult = await slotRepository.getSlotById(
        membership.libraryId,
        slotId,
      );
      final slot = slotResult.fold((_) => null, (s) => s);
      if (slot != null) {
        return slot.price * (membership.effectiveDurationInDays / 30.0);
      }
    }
    return 0;
  }

  void _sendWhatsAppInvoice(Invoice invoice) {
    final repo = whatsAppNotificationRepository;
    if (repo == null) return;
    repo
        .sendInvoiceWhatsApp(invoice)
        .then(
          (r) => r.fold(
            (f) => log('PendingApprovalCubit: WhatsApp failed - ${f.message}'),
            (_) {},
          ),
        )
        .catchError((Object e) {
          log('PendingApprovalCubit: WhatsApp error - $e');
        });
  }
}
