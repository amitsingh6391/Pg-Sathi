import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/app_ui_constants.dart';
import '../../../../domain/entities/custom_slot.dart';
import '../../../../domain/entities/library.dart';
import '../../../../domain/entities/membership.dart';
import '../../../../domain/entities/slot.dart';
import '../../../../domain/usecases/get_occupied_seats.dart';
import '../student_details_bottom_sheet.dart';
import 'resident_status.dart';
import 'student_card_sections.dart';

/// Resident card, same layout as Library Manager's student card.
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
    final isUpcoming = seatInfo.isUpcoming;

    return Container(
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
              // Header: Avatar + Name + Status
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ResidentAvatar(
                      name: seatInfo.displayName,
                      avatarUrl: seatInfo.studentAvatarUrl,
                      color: isPending
                          ? AppUIConstants.warning
                          : AppUIConstants.primary,
                    ),
                    const SizedBox(width: 14),
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
                              if (isPending)
                                _buildPendingBadge()
                              else if (isUpcoming)
                                _buildUpcomingBadge()
                              else if (isExpired)
                                _buildExpiredBadge()
                              else if (isExpiring)
                                _buildExpiryBadge()
                              else
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
                            'Room',
                            slotName ?? '—',
                            Icons.meeting_room_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoTile(
                            'Bed',
                            seatInfo.seatId,
                            Icons.bed_outlined,
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
                          child: isUpcoming
                              ? _buildInfoTile(
                                  'Starts',
                                  DateFormat(
                                    'dd MMM yyyy',
                                  ).format(seatInfo.membership.startDate),
                                  Icons.play_circle_outline,
                                  valueColor: const Color(0xFF4F46E5),
                                )
                              : _buildInfoTile(
                                  isExpired ? 'Ended' : 'Due date',
                                  DateFormat(
                                    'dd MMM yyyy',
                                  ).format(seatInfo.membership.endDate),
                                  Icons.event_outlined,
                                  valueColor: isExpired
                                      ? Colors.red.shade600
                                      : isExpiring
                                      ? Colors.orange.shade700
                                      : null,
                                ),
                        ),
                      ],
                    ),
                    if (slotTiming != null) ...[
                      const SizedBox(height: 12),
                      _buildInfoTile(
                        'Timing',
                        slotTiming,
                        Icons.schedule_outlined,
                      ),
                    ],

                    // Upcoming stay notice
                    if (seatInfo.upcomingMembership != null) ...[
                      const SizedBox(height: 16),
                      _buildUpcomingMembershipNotice(
                        seatInfo.upcomingMembership!,
                      ),
                    ],

                    // Partial rent section
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

  Widget _badge(
    String label,
    Color bg,
    Color border,
    Color fg, {
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredBadge() => _badge(
    'Expired',
    Colors.red.shade50,
    Colors.red.shade200,
    Colors.red.shade700,
  );

  Widget _buildPendingBadge() => _badge(
    'Pending',
    Colors.amber.shade50,
    Colors.amber.shade200,
    Colors.amber.shade800,
    icon: Icons.hourglass_top_rounded,
  );

  Widget _buildExpiryBadge() {
    final d = seatInfo.daysRemaining;
    final label = d == 0
        ? 'Today'
        : d == 1
        ? 'Tomorrow'
        : '${d}d left';
    return _badge(
      label,
      Colors.orange.shade50,
      Colors.orange.shade200,
      Colors.orange.shade700,
    );
  }

  Widget _buildUpcomingBadge() => _badge(
    'Upcoming',
    const Color(0xFF6366F1).withValues(alpha: 0.08),
    const Color(0xFF6366F1).withValues(alpha: 0.35),
    const Color(0xFF4F46E5),
    icon: Icons.schedule_rounded,
  );

  Widget _buildActiveBadge() => _badge(
    'Active',
    Colors.green.shade50,
    Colors.green.shade200,
    Colors.green.shade700,
    icon: Icons.check_circle,
  );

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
    final color = isActive ? Colors.green.shade700 : Colors.orange.shade700;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isActive ? Icons.check_circle_outline : Icons.schedule_outlined,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isActive
                      ? 'Upcoming stay will start in $daysUntilStart ${daysUntilStart == 1 ? 'day' : 'days'}'
                      : 'Upcoming stay pending rent',
                  style: const TextStyle(
                    color: AppUIConstants.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Starts: ${dateFormat.format(upcoming.startDate)} • ${upcoming.planDisplayLabel}',
            style: AppUIConstants.bodySm,
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
      useSafeArea: false,
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
