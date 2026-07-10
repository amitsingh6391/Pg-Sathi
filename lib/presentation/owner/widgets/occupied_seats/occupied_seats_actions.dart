import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../core/app_ui_constants.dart';
import '../../../../domain/entities/custom_slot.dart';
import '../../../../domain/entities/library.dart';
import '../../../../domain/entities/membership.dart';
import '../../../../domain/entities/payment.dart';
import '../../../../domain/repositories/auth_repository.dart';
import '../../../../domain/repositories/payment_repository.dart';
import '../../../../domain/usecases/get_occupied_seats.dart';
import '../../cubit/membership_assignment_cubit.dart';
import '../../cubit/occupied_seats_cubit.dart';
import '../../cubit/occupied_seats_state.dart';
import '../../screens/membership_assignment_screen.dart';
import '../refund_payment_bottom_sheet.dart';
import 'edit_membership_bottom_sheet.dart';

// Re-export payment actions so callers only need one import
export 'occupied_seats_payment_actions.dart';

// ---------------------------------------------------------------------------
// Utility functions
// ---------------------------------------------------------------------------

/// Calculates the full payment amount for a membership,
/// considering custom slot prices and payment breakdown history.
double calculateFullPaymentAmount(
  Membership membership,
  List<CustomSlot> customSlots,
) {
  // IMPORTANT: If membership already has payment breakdown, use the amount BEFORE discount
  // This ensures we show the original seat price, not the discounted price
  if (membership.paymentBreakdown != null) {
    return membership.paymentBreakdown!.hasDiscount
        ? membership.paymentBreakdown!.totalAmountBeforeDiscount
        : membership.paymentBreakdown!.totalAmount;
  }

  // If membership has a custom slot, calculate based on slot price
  if (membership.slotId != null && membership.slotId!.isNotEmpty) {
    try {
      final customSlot = customSlots.firstWhere(
        (slot) => slot.id == membership.slotId,
      );
      // Calculate based on EFFECTIVE duration (accounts for custom duration) and slot price (monthly)
      final months = membership.effectiveDurationInDays / 30.0;
      return customSlot.price * months;
    } catch (_) {
      // Custom slot not found, fall through to hardcoded values
    }
  }

  // Fallback to hardcoded values for legacy slots
  switch (membership.plan) {
    case MembershipPlan.daily:
      return 50.0;
    case MembershipPlan.weekly:
      return 300.0;
    case MembershipPlan.monthly:
      return 1000.0;
    case MembershipPlan.quarterly:
      return 2500.0;
    case MembershipPlan.yearly:
      return 8000.0;
  }
}

/// Sorts seats based on the provided sort criteria.
List<OccupiedSeatInfo> sortOccupiedSeats(
  List<OccupiedSeatInfo> seats,
  SortBy sortBy,
) {
  final sorted = List<OccupiedSeatInfo>.from(seats);

  switch (sortBy) {
    case SortBy.seatNumber:
      sorted.sort((a, b) {
        final bySeat = a.seatNumber.compareTo(b.seatNumber);
        if (bySeat != 0) return bySeat;
        return a.seatId.compareTo(b.seatId);
      });
      break;
    case SortBy.dateExpiring:
      sorted.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
      break;
    case SortBy.status:
      sorted.sort((a, b) {
        final aStatus = a.isExpired ? 2 : (a.isExpiringSoon ? 1 : 0);
        final bStatus = b.isExpired ? 2 : (b.isExpiringSoon ? 1 : 0);
        return aStatus.compareTo(bStatus);
      });
      break;
    case SortBy.name:
      sorted.sort((a, b) => a.displayName.compareTo(b.displayName));
      break;
    case SortBy.daysRemaining:
      sorted.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
      break;
    case SortBy.addedDate:
      sorted.sort((a, b) {
        final aDate = a.membership.createdAt ?? DateTime(1970);
        final bDate = b.membership.createdAt ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });
      break;
  }

  return sorted;
}

// ---------------------------------------------------------------------------
// Snackbar helper
// ---------------------------------------------------------------------------

/// Shows a styled snackbar for action feedback.
void showOccupiedSeatsSnackBar(
  BuildContext context,
  String message, {
  required bool isError,
}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_rounded : Icons.check_circle_rounded,
            color: Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: isError ? Colors.red.shade600 : const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

// ---------------------------------------------------------------------------
// Sort dialog
// ---------------------------------------------------------------------------

/// Shows the sort options bottom sheet.
void showOccupiedSeatsSortDialog(BuildContext context) {
  final cubit = context.read<OccupiedSeatsCubit>();
  final currentSort = cubit.state.sortBy;

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sort By', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _SortOption(
            title: 'By bed number',
            subtitle: 'Bed 1, 2, 3...',
            selected: currentSort == SortBy.seatNumber,
            onTap: () {
              cubit.setSortBy(SortBy.seatNumber);
              Navigator.pop(context);
            },
          ),
          _SortOption(
            title: 'By Added Date',
            subtitle: 'Newest tenants first',
            selected: currentSort == SortBy.addedDate,
            onTap: () {
              cubit.setSortBy(SortBy.addedDate);
              Navigator.pop(context);
            },
          ),
          _SortOption(
            title: 'Expiring Soon First',
            subtitle: 'Stays expiring soon appear first',
            selected: currentSort == SortBy.dateExpiring,
            onTap: () {
              cubit.setSortBy(SortBy.dateExpiring);
              Navigator.pop(context);
            },
          ),
          _SortOption(
            title: 'By Status',
            subtitle: 'Active → Expiring Soon → Expired',
            selected: currentSort == SortBy.status,
            onTap: () {
              cubit.setSortBy(SortBy.status);
              Navigator.pop(context);
            },
          ),
          _SortOption(
            title: 'By Name (A-Z)',
            subtitle: 'Sort alphabetically',
            selected: currentSort == SortBy.name,
            onTap: () {
              cubit.setSortBy(SortBy.name);
              Navigator.pop(context);
            },
          ),
          _SortOption(
            title: 'Days Remaining',
            subtitle: 'Least days left first',
            selected: currentSort == SortBy.daysRemaining,
            onTap: () {
              cubit.setSortBy(SortBy.daysRemaining);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    ),
  );
}

class _SortOption extends StatelessWidget {
  const _SortOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? AppUIConstants.primary
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle,
                  color: AppUIConstants.primary,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cancel stay dialog
// ---------------------------------------------------------------------------

/// Shows the cancel/remove stay confirmation dialog.
void showCancelMembershipDialog(
  BuildContext context, {
  required OccupiedSeatInfo seatInfo,
  required OccupiedSeatsCubit cubit,
}) {
  final isPending = seatInfo.isReserved;

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(
            isPending ? Icons.delete_rounded : Icons.cancel_rounded,
            color: Colors.red.shade600,
          ),
          const SizedBox(width: 12),
          Text(isPending ? 'Remove Pending' : 'Cancel Stay'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade600, Colors.amber.shade700],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    seatInfo.seatId,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (isPending) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Pending',
                      style: TextStyle(
                        color: Colors.amber.shade800,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isPending
                ? 'This will remove the pending reservation and free up the bed.'
                : 'This will cancel the stay and free up the bed.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_rounded,
                  size: 18,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This action cannot be undone.',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Keep'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () {
            Navigator.of(dialogContext).pop();
            cubit.cancel(membershipId: seatInfo.membership.id);
          },
          child: Text(isPending ? 'Remove' : 'Cancel'),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Refund handler
// ---------------------------------------------------------------------------

/// Handles the refund flow: validates payment state and shows refund sheet.
Future<void> handleOccupiedSeatsRefund(
  BuildContext context, {
  required OccupiedSeatInfo seatInfo,
  required OccupiedSeatsCubit cubit,
}) async {
  final authRepo = sl<AuthRepository>();
  final userResult = await authRepo.getCurrentUser();
  final ownerId = userResult.fold((_) => null, (user) => user?.id);

  if (ownerId == null) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Failed to get current user'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  final paymentRepo = sl<PaymentRepository>();
  final paymentsResult = await paymentRepo.getPaymentByMembershipId(
    seatInfo.membership.id,
  );

  await paymentsResult.fold(
    (failure) async {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load payment: ${failure.message}'),
          backgroundColor: Colors.red,
        ),
      );
    },
    (payment) async {
      if (!context.mounted) return;

      if (payment == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No payment found for this stay'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (payment.status != PaymentStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only successful payments can be refunded'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (payment.isRefunded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment already refunded'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final result = await showRefundPaymentBottomSheet(
        context: context,
        payment: payment,
        studentName: seatInfo.displayName,
        ownerId: ownerId,
      );

      if (result == true && context.mounted) {
        cubit.refresh();
      }
    },
  );
}

// ---------------------------------------------------------------------------
// Edit stay dialog
// ---------------------------------------------------------------------------

/// Shows the edit stay bottom sheet with available beds.
void showEditSeatDialog(
  BuildContext context, {
  required OccupiedSeatInfo seatInfo,
  required Library library,
  required List<CustomSlot> customSlots,
  required OccupiedSeatsCubit cubit,
}) {
  final currentSeatId = seatInfo.seatId;
  final currentSlot = seatInfo.membership.slot;
  final currentSlotId = seatInfo.membership.slotId;

  List<String> availableSeats;
  if (currentSlotId != null) {
    CustomSlot? customSlot;
    try {
      customSlot = customSlots.firstWhere((slot) => slot.id == currentSlotId);
    } catch (_) {
      customSlot = null;
    }

    final slotCapacity = customSlot?.capacity ?? library.capacity;
    final allSeats = List.generate(slotCapacity, (i) => 'B${i + 1}');

    final occupiedSeats = cubit.state.occupiedSeats
        .where(
          (s) =>
              s.membership.slotId == currentSlotId && s.seatId != currentSeatId,
        )
        .map((s) => s.seatId)
        .toSet();

    availableSeats = allSeats.where((s) => !occupiedSeats.contains(s)).toList();
    if (!availableSeats.contains(currentSeatId)) {
      availableSeats.add(currentSeatId);
    }
    availableSeats.sort();
  } else if (currentSlot != null) {
    availableSeats = cubit.getAvailableSeatsForSlot(currentSlot);
    if (!availableSeats.contains(currentSeatId)) {
      availableSeats.add(currentSeatId);
    }
    availableSeats.sort();
  } else {
    availableSeats = [];
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => EditMembershipBottomSheet(
      seatInfo: seatInfo,
      library: library,
      customSlots: customSlots,
      availableSeats: availableSeats,
      onUpdate:
          ({
            String? newSeatId,
            DateTime? newStartDate,
            DateTime? newEndDate,
            String? newStudentName,
          }) async {
            await cubit.updateMembershipDetails(
              membershipId: seatInfo.membership.id,
              newSeatId: newSeatId,
              newStartDate: newStartDate,
              newEndDate: newEndDate,
              newStudentName: newStudentName,
            );
          },
    ),
  );
}

// ---------------------------------------------------------------------------
// Navigate to reassign
// ---------------------------------------------------------------------------

/// Navigates to the tenant stay assignment screen for reassigning a bed.
void navigateToReassign(
  BuildContext context, {
  required OccupiedSeatInfo seatInfo,
  required Library library,
  required OccupiedSeatsCubit cubit,
}) {
  Navigator.of(context)
      .push(
        MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => sl<MembershipAssignmentCubit>()
              ..loadMemberships(
                libraryId: library.id,
                ownerId: library.ownerId,
              ),
            child: MembershipAssignmentScreen(
              library: library,
              prefilledSeatId: seatInfo.seatId,
              prefilledSlotId: seatInfo.membership.slotId,
              prefilledMembership: seatInfo.membership,
            ),
          ),
        ),
      )
      .then((_) {
        if (context.mounted) {
          cubit.refresh();
        }
      });
}
