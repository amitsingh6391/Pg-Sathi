import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/app_ui_constants.dart';
import '../../../../domain/entities/custom_slot.dart';
import '../../../../domain/entities/library.dart';
import '../../../../domain/entities/membership.dart';
import '../../../../domain/entities/slot.dart';
import '../../../../domain/usecases/get_occupied_seats.dart';
import '../student_details_bottom_sheet.dart';
import 'student_card_sections.dart';

/// Tenant card with clean design matching app's design language.
/// Extracted from occupied_seats_screen.dart for maintainability.
class OccupiedSeatsStudentCard extends StatelessWidget {
  const OccupiedSeatsStudentCard({
    super.key,
    required this.seatInfo,
    required this.isActionInProgress,
    required this.onCancel,
    required this.onEdit,
    required this.onSendReminder,
    required this.onConvertPending,
    required this.libraryId,
    required this.customSlots,
    required this.library,
    this.highlightQuery,
    this.onReassign,
    this.onRefund,
    this.showExpired = false,
  });

  final OccupiedSeatInfo seatInfo;
  final bool isActionInProgress;
  final VoidCallback onCancel;
  final VoidCallback onEdit;
  final VoidCallback onSendReminder;
  final void Function(OccupiedSeatInfo seat, {bool forUpcomingPlan})
  onConvertPending;
  final VoidCallback? onReassign;
  final VoidCallback? onRefund;
  final String libraryId;
  final List<CustomSlot> customSlots;
  final Library library;
  final String? highlightQuery;
  final bool showExpired;

  @override
  Widget build(BuildContext context) {
    final isPending = seatInfo.isReserved;
    final hasPartialPayment = seatInfo.membership.hasPartialPayment;
    final isExpiring = seatInfo.isExpiringSoon;
    final isExpired = seatInfo.isExpired;
    // Check if there is an active upcoming plan (payment complete, status = active).
    // If there is, hide Reassign and Remind buttons
    final hasActiveUpcomingPlan =
        seatInfo.upcomingMembership != null &&
        seatInfo.upcomingMembership!.status == MembershipStatus.active;
    final needsFuturePlanPayment = seatInfo.hasFuturePendingPlanNeedingPayment;
    VoidCallback? onCompletePayment;
    if (!isPending && !isExpired) {
      if (hasPartialPayment) {
        onCompletePayment = () => onConvertPending(seatInfo);
      } else if (needsFuturePlanPayment) {
        onCompletePayment = () =>
            onConvertPending(seatInfo, forUpcomingPlan: true);
      }
    }
    final slotName = _getSlotName(seatInfo, customSlots);
    final slotTiming = _getSlotTiming(seatInfo, customSlots);
    final paymentNotes = seatInfo.membership.paymentBreakdown?.notes;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _showStudentDetails(context, seatInfo),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              // Header: Avatar/Photo + Name + Status
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile pic or bed badge
                    _buildProfileWithSeat(isPending),
                    const SizedBox(width: 14),
                    // Name and phone
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildHighlightedText(
                                  seatInfo.displayName,
                                  highlightQuery,
                                  const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1a1a2e),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              // Show "Today" badge when expiring today (daysRemaining == 0)
                              if (isExpiring &&
                                  !isPending &&
                                  seatInfo.daysRemaining == 0)
                                _buildExpiryBadge()
                              // Show "Expired" badge only if truly expired (daysRemaining < 0)
                              else if (isExpired && !isPending)
                                _buildExpiredBadge()
                              // Show expiry badge for other expiring cases (1-7 days)
                              else if (isExpiring && !isPending && !isExpired)
                                _buildExpiryBadge()
                              // Show active badge for non-expiring, non-expired stays
                              else if (!isExpired && !isExpiring && !isPending)
                                _buildActiveBadge(),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (seatInfo.studentPhone != null)
                            _buildHighlightedText(
                              seatInfo.studentPhone!,
                              highlightQuery,
                              TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Divider
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: Colors.grey.shade100,
              ),

              // Details Grid (2x2)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoTile(
                            'Plan',
                            slotName ?? '—',
                            Icons.meeting_room_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoTile(
                            'Stay Type',
                            slotTiming ?? '—',
                            Icons.schedule_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoTile(
                            'Stay',
                            seatInfo.membership.planDisplayLabel,
                            Icons.card_membership_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoTile(
                            'Expires',
                            DateFormat(
                              'dd MMM yyyy',
                            ).format(seatInfo.membership.endDate),
                            Icons.event_outlined,
                            valueColor: isExpiring
                                ? Colors.orange.shade700
                                : null,
                          ),
                        ),
                      ],
                    ),

                    // Upcoming Stay Notice
                    if (seatInfo.upcomingMembership != null) ...[
                      const SizedBox(height: 16),
                      _buildUpcomingMembershipNotice(
                        seatInfo.upcomingMembership!,
                      ),
                    ],

                    // Partial Payment Section
                    if (hasPartialPayment) ...[
                      const SizedBox(height: 16),
                      PartialPaymentSection(
                        membership: seatInfo.membership,
                        paymentNotes: paymentNotes,
                      ),
                    ],
                  ],
                ),
              ),

              // Actions Footer
              StudentCardActions(
                isPending: isPending,
                isExpired: isExpired,
                isExpiring: isExpiring,
                hasPartialPayment: hasPartialPayment,
                needsFuturePlanPayment: needsFuturePlanPayment,
                hasActiveUpcomingPlan: hasActiveUpcomingPlan,
                isActionInProgress: isActionInProgress,
                studentPhone: seatInfo.studentPhone,
                onReassign: onReassign,
                onEdit: onEdit,
                onConvertPending: () => onConvertPending(seatInfo),
                onCompletePayment: onCompletePayment,
                onSendReminder: onSendReminder,
                onCancel: onCancel,
                onRefund: onRefund,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileWithSeat(bool isPending) {
    final displayName = seatInfo.displayName;
    final avatarUrl = seatInfo.studentAvatarUrl;
    final initials = displayName.isNotEmpty
        ? displayName
              .split(' ')
              .map((n) => n.isNotEmpty ? n[0] : '')
              .take(2)
              .join()
              .toUpperCase()
        : '?';

    // If user has profile pic, show it with seat badge overlay
    if (avatarUrl != null) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              image: DecorationImage(
                image: NetworkImage(avatarUrl),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Bed badge
          Positioned(
            bottom: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPending
                      ? [const Color(0xFFf59e0b), const Color(0xFFd97706)]
                      : [AppUIConstants.primary, AppUIConstants.primaryLight],
                ),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                seatInfo.seatId,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // No profile pic - show gradient bed badge with initials.
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPending
              ? [const Color(0xFFf59e0b), const Color(0xFFd97706)]
              : [AppUIConstants.primary, AppUIConstants.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            seatInfo.seatId,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          if (isPending)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'PENDING',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 7,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            )
          else
            Text(
              initials,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpiredBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(
        'Expired',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.red.shade700,
        ),
      ),
    );
  }

  Widget _buildExpiryBadge() {
    final daysLabel = seatInfo.daysRemaining == 0
        ? 'Today'
        : seatInfo.daysRemaining == 1
        ? 'Tomorrow'
        : '${seatInfo.daysRemaining}d left';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Text(
        daysLabel,
        style: TextStyle(
          color: Colors.orange.shade700,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildActiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 10, color: Colors.green.shade700),
          const SizedBox(width: 4),
          Text(
            'Active',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade400),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: valueColor ?? const Color(0xFF1a1a2e),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingMembershipNotice(Membership upcoming) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final isActive = upcoming.status == MembershipStatus.active;
    final daysUntilStart = upcoming.startDate.difference(DateTime.now()).inDays;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.green.shade200 : Colors.orange.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isActive ? Icons.check_circle_outline : Icons.schedule_outlined,
                color: isActive
                    ? Colors.green.shade700
                    : Colors.orange.shade700,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isActive
                      ? 'Upcoming stay will start in $daysUntilStart ${daysUntilStart == 1 ? 'day' : 'days'}'
                      : 'Upcoming stay pending rent',
                  style: const TextStyle(
                    color: Color(0xFF1a1a2e),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Starts: ${dateFormat.format(upcoming.startDate)} • ${upcoming.planDisplayLabel}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightedText(
    String text,
    String? query,
    TextStyle baseStyle,
  ) {
    if (query == null || query.trim().isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase().trim();
    final startIndex = lowerText.indexOf(lowerQuery);

    if (startIndex == -1) {
      return Text(
        text,
        style: baseStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final endIndex = startIndex + lowerQuery.length;

    return Text.rich(
      TextSpan(
        children: [
          if (startIndex > 0) TextSpan(text: text.substring(0, startIndex)),
          TextSpan(
            text: text.substring(startIndex, endIndex),
            style: TextStyle(
              backgroundColor: AppUIConstants.accent.withValues(alpha: 0.2),
              fontWeight: FontWeight.bold,
            ),
          ),
          if (endIndex < text.length) TextSpan(text: text.substring(endIndex)),
        ],
        style: baseStyle,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  void _showStudentDetails(BuildContext context, OccupiedSeatInfo seatInfo) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          StudentDetailsBottomSheet(seatInfo: seatInfo, library: library),
    );
  }

  static String? _getSlotName(
    OccupiedSeatInfo seatInfo,
    List<CustomSlot> customSlots,
  ) {
    final membership = seatInfo.membership;
    if (membership.slotId != null) {
      try {
        final customSlot = customSlots.firstWhere(
          (slot) => slot.id == membership.slotId,
        );
        return customSlot.name;
      } catch (_) {
        return null;
      }
    }
    if (membership.slot != null) {
      switch (membership.slot!) {
        case Slot.morning:
          return 'Morning';
        case Slot.evening:
          return 'Evening';
      }
    }
    return null;
  }

  static String? _getSlotTiming(
    OccupiedSeatInfo seatInfo,
    List<CustomSlot> customSlots,
  ) {
    final membership = seatInfo.membership;
    if (membership.slotId != null) {
      try {
        final customSlot = customSlots.firstWhere(
          (slot) => slot.id == membership.slotId,
        );
        return customSlot.displayTime;
      } catch (_) {
        return null;
      }
    }
    if (membership.slot != null) {
      switch (membership.slot!) {
        case Slot.morning:
          return '6:00 AM – 2:00 PM';
        case Slot.evening:
          return '2:00 PM – 10:00 PM';
      }
    }
    return null;
  }
}
