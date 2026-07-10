import 'package:flutter/material.dart';

import '../../../../domain/entities/library.dart';
import '../../../../domain/entities/membership.dart';
import '../../cubit/membership_assignment_state.dart';

/// Fixed app header for tenant stay assignment screen.
class MembershipAppHeader extends StatelessWidget {
  const MembershipAppHeader({
    super.key,
    required this.library,
    this.onBulkImport,
  });

  final Library library;
  final VoidCallback? onBulkImport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 8,
        right: 16,
        bottom: 12,
      ),
      decoration: const BoxDecoration(color: Color(0xFF1E293B)),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Assign Tenant Stay',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  library.name,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Bulk import button removed from header - now shown prominently in main content
        ],
      ),
    );
  }
}

/// Single-step progress indicator showing current assignment phase.
class MembershipProgressIndicator extends StatelessWidget {
  const MembershipProgressIndicator({super.key, required this.step1Complete});

  final bool step1Complete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          _StepIndicator(
            step: 1,
            label: 'Select Bed',
            isComplete: step1Complete,
            isActive: !step1Complete,
          ),
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: step1Complete
                    ? const Color(0xFF10B981)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          _StepIndicator(
            step: 2,
            label: 'Add Tenant',
            isComplete: false,
            isActive: step1Complete,
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.step,
    required this.label,
    required this.isComplete,
    required this.isActive,
  });

  final int step;
  final String label;
  final bool isComplete;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isComplete
        ? const Color(0xFF10B981)
        : isActive
        ? const Color(0xFF6366F1)
        : const Color(0xFF94A3B8);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isComplete || isActive ? color : Colors.transparent,
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: isComplete
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                : Text(
                    step.toString(),
                    style: TextStyle(
                      color: isActive ? Colors.white : color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: isComplete || isActive
                ? const Color(0xFF1E293B)
                : const Color(0xFF94A3B8),
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

/// Summary header card showing PG info and bed availability.
class MembershipSummaryCard extends StatelessWidget {
  const MembershipSummaryCard({
    super.key,
    required this.library,
    required this.state,
  });

  final Library library;
  final MembershipAssignmentState state;

  @override
  Widget build(BuildContext context) {
    // Count occupied seats across all custom slots
    final occupied = state.memberships
        .where(
          (m) =>
              m.assignedSeatId != null &&
              m.slotId != null &&
              m.status == MembershipStatus.active,
        )
        .length;
    final reserved = state.memberships
        .where(
          (m) =>
              m.assignedSeatId != null &&
              m.slotId != null &&
              m.status == MembershipStatus.pendingPayment,
        )
        .length;
    final totalSeats = library.totalSeatCapacity ?? library.capacity;
    final totalAvailable = totalSeats - occupied - reserved;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF334155)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Library Info Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      library.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${library.totalSeatCapacity ?? library.capacity} beds total',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Overall Availability
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: 'Available',
                  value: totalAvailable,
                  color: const Color(0xFF10B981),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                _StatItem(
                  label: 'Occupied',
                  value: occupied,
                  color: Colors.red.shade300,
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                _StatItem(
                  label: 'Reserved',
                  value: reserved,
                  color: Colors.amber.shade300,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
