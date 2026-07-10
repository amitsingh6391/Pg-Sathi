import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/custom_slot.dart';
import '../../../domain/entities/membership.dart';
import '../../../domain/entities/slot.dart';
import '../../../domain/usecases/get_student_memberships.dart';
import '../../../domain/usecases/send_payment_reminder.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/attendance_cubit.dart';
import '../cubit/student_home_state.dart';
import '../cubit/student_payment_cubit.dart';
import '../screens/payment_screen.dart';
import 'check_in_out_card.dart';
import 'membership_widgets.dart';

int _calendarDaysUntil(DateTime from, DateTime to) {
  final fromDay = DateTime(from.year, from.month, from.day);
  final toDay = DateTime(to.year, to.month, to.day);
  return toDay.difference(fromDay).inDays;
}

String _paidUpcomingActivationCaption(int calendarDaysUntilStart) {
  if (calendarDaysUntilStart <= 0) {
    return 'Paid upcoming plan starts when your current plan ends';
  }
  if (calendarDaysUntilStart == 1) {
    return 'Upcoming plan activates tomorrow';
  }
  return 'Upcoming plan activates in $calendarDaysUntilStart days';
}

/// Membership Card - Clean, professional design.
class UnifiedMembershipCard extends StatelessWidget {
  const UnifiedMembershipCard({
    super.key,
    required this.info,
    required this.userId,
    this.documentStatus = DocumentVerificationStatus.none,
    this.onCardTap,
    this.onViewAttendance,
    this.onViewInvoices,
    this.onViewDocuments,
  });

  final StudentMembershipInfo info;
  final String userId;
  final DocumentVerificationStatus documentStatus;
  final VoidCallback? onCardTap;
  final VoidCallback? onViewAttendance;
  final VoidCallback? onViewInvoices;
  final VoidCallback? onViewDocuments;

  @override
  Widget build(BuildContext context) {
    final isPending = info.isPendingPayment;
    final isActive = info.isActive;
    final hasPartialPayment = info.hasPartialPayment;
    final isExpiringSoon =
        info.isActive && info.daysRemaining <= 7 && info.daysRemaining >= 0;
    final isExpired = info.isExpired;
    final customSlot = info.customSlot;
    final derivedSlot = _getDerivedSlot(customSlot);

    return Container(
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(
          color: isExpired
              ? AppUIConstants.error.withValues(alpha: 0.4)
              : isPending
              ? AppUIConstants.warning.withValues(alpha: 0.4)
              : isExpiringSoon
              ? AppUIConstants.warning.withValues(alpha: 0.4)
              : AppUIConstants.border,
        ),
        boxShadow: [AppUIConstants.shadowSm],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildTappableContent(context, customSlot),
          // Show upcoming membership details if merged
          if (info.upcomingMembership != null)
            _buildUpcomingMembershipNotice(context),
          if (isActive && derivedSlot != null)
            _buildCheckInOutSection(derivedSlot),
          if (isActive) _buildQuickActions(context),
          if (hasPartialPayment && isActive)
            _buildCompletePaymentButton(context),
          // Show remind button for expired memberships
          if (isExpired) _buildRemindButton(context),
          // Show renewal button for expiring soon (not expired) OR expired memberships, but not if pending payment
          // Hide if there's an active upcoming plan (don't need to renew if already have upcoming)
          if ((isExpiringSoon || isExpired) &&
              !isPending &&
              !_hasActiveUpcomingPlan())
            _buildRenewalButton(context),
          // Show payment reminder for upcoming membership ONLY if payment is pending
          // Don't show if upcoming membership payment is already complete (status is active)
          if (info.hasUpcomingMembershipPendingPayment)
            _buildUpcomingPaymentButton(context),
        ],
      ),
    );
  }

  Slot? _getDerivedSlot(CustomSlot? customSlot) {
    if (customSlot != null) {
      return customSlot.startTimeOfDay.hour < 14 ? Slot.morning : Slot.evening;
    }
    return info.membership.slot;
  }

  bool _isMorning(CustomSlot? customSlot) {
    final derivedSlot = _getDerivedSlot(customSlot);
    return derivedSlot == Slot.morning ||
        (customSlot != null && customSlot.startTimeOfDay.hour < 14);
  }

  Widget _buildTappableContent(BuildContext context, CustomSlot? customSlot) {
    return GestureDetector(
      onTap: onCardTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          _MembershipHeader(
            libraryName: info.libraryName ?? 'Library',
            seatNumber: info.seatNumber,
            sessionTiming: info.sessionTiming,
            isMorning: _isMorning(customSlot),
            isPending: info.isPendingPayment,
            isActive: info.isActive,
            hasPartialPayment: info.hasPartialPayment,
            isExpired: info.isExpired,
          ),
          _MembershipInfoRow(
            plan: info.membership.plan.name.toUpperCase(),
            daysRemaining: info.daysRemaining,
            validTill: info.validTill,
            paymentAmount: info.paymentAmount,
            isActive: info.isActive,
            isPending: info.isPendingPayment,
          ),
          if (info.isPendingPayment) _buildPendingNotice(),
          if (info.hasPartialPayment && info.isActive)
            _buildPartialPaymentNotice(),
        ],
      ),
    );
  }

  Widget _buildPendingNotice() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppUIConstants.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppUIConstants.warning,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Complete payment to activate membership',
              style: TextStyle(
                color: AppUIConstants.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: AppUIConstants.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildPartialPaymentNotice() {
    final remaining = info.remainingBalance;
    final paid = info.membership.paymentBreakdown?.amountPaid ?? 0.0;
    if (remaining <= 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppUIConstants.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
      ),
      child: Row(
        children: [
          Icon(
            Icons.payments_outlined,
            size: 16,
            color: AppUIConstants.warning,
          ),
          const SizedBox(width: 8),
          Text(
            'Paid: ₹${paid.toStringAsFixed(0)}',
            style: TextStyle(
              color: AppUIConstants.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: AppUIConstants.textTertiary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Remaining: ₹${remaining.toStringAsFixed(0)}',
            style: TextStyle(
              color: AppUIConstants.warning,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckInOutSection(Slot slot) {
    return BlocProvider(
      create: (_) => sl<AttendanceCubit>()
        ..loadTodayAttendance(
          userId: userId,
          libraryId: info.membership.libraryId,
          slot: slot,
        ),
      child: Column(
        children: [
          Divider(height: 1, color: AppUIConstants.divider),
          CheckInOutCard(
            userId: userId,
            libraryId: info.membership.libraryId,
            slot: slot,
            seatNumber: info.seatNumber,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final docButton = _documentButtonConfig;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: MembershipActionButton(
              icon: docButton.icon,
              label: docButton.label,
              onTap: onViewDocuments,
              statusColor: docButton.statusColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: MembershipActionButton(
              icon: Icons.bar_chart_rounded,
              label: 'Attendance',
              onTap: onViewAttendance,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: MembershipActionButton(
              icon: Icons.receipt_long_outlined,
              label: 'Invoices',
              onTap: onViewInvoices,
              isPrimary: true,
            ),
          ),
        ],
      ),
    );
  }

  /// Returns icon, label, and optional accent color based on document status.
  ({IconData icon, String label, Color? statusColor})
      get _documentButtonConfig {
    switch (documentStatus) {
      case DocumentVerificationStatus.verified:
        return (
          icon: Icons.verified_rounded,
          label: 'ID Verified',
          statusColor: AppUIConstants.success,
        );
      case DocumentVerificationStatus.pending:
        return (
          icon: Icons.hourglass_top_rounded,
          label: 'ID Pending',
          statusColor: AppUIConstants.warning,
        );
      case DocumentVerificationStatus.none:
        return (
          icon: Icons.upload_file_rounded,
          label: 'Upload ID',
          statusColor: null,
        );
    }
  }

  Widget _buildCompletePaymentButton(BuildContext context) {
    final remaining = info.remainingBalance;
    if (remaining <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BlocProvider(
                  create: (_) => sl<StudentPaymentCubit>(),
                  child: PaymentScreen(
                    membershipInfo: info,
                    overrideAmount: remaining,
                    isRemainingPayment: true,
                  ),
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppUIConstants.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            ),
          ),
          child: Text(
            'Pay Remaining ₹${remaining.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildRenewalButton(BuildContext context) {
    final isExpired = info.isExpired;
    final daysRemaining = info.daysRemaining;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BlocProvider(
                  create: (_) => sl<StudentPaymentCubit>(),
                  child: PaymentScreen(membershipInfo: info, isRenewal: true),
                ),
              ),
            );
          },
          icon: Icon(
            isExpired ? Icons.refresh_rounded : Icons.update_rounded,
            size: 18,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: isExpired
                ? AppUIConstants.error
                : AppUIConstants.warning,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            ),
          ),
          label: Text(
            isExpired
                ? 'Renew Membership'
                : 'Renew Now (${daysRemaining}d left)',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildRemindButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _sendReminder(context),
          icon: const Icon(Icons.notifications_outlined, size: 18),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppUIConstants.primary,
            side: BorderSide(color: AppUIConstants.primary),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            ),
          ),
          label: const Text(
            'Remind Owner',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingMembershipNotice(BuildContext context) {
    final upcoming = info.upcomingMembership!;
    final dateFormat = DateFormat('MMM dd, yyyy');
    final isActive = upcoming.status == MembershipStatus.active;
    final isPendingPayment = upcoming.status == MembershipStatus.pendingPayment;
    final daysUntilStart = _calendarDaysUntil(
      DateTime.now(),
      upcoming.startDate,
    );
    final paidUpcomingCaption = _paidUpcomingActivationCaption(daysUntilStart);

    // Only show notice if payment is pending, not if payment is complete
    if (!isPendingPayment && isActive) {
      // Payment is complete - show simple activation notice
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppUIConstants.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
          border: Border.all(
            color: AppUIConstants.success.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: AppUIConstants.success,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    paidUpcomingCaption,
                    style: TextStyle(
                      color: AppUIConstants.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Starts: ${dateFormat.format(upcoming.startDate)} • ${upcoming.plan.name.toUpperCase()}',
              style: TextStyle(
                color: AppUIConstants.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    // Payment is pending - show warning notice
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppUIConstants.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
        border: Border.all(
          color: AppUIConstants.warning.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.schedule_outlined,
                color: AppUIConstants.warning,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Upcoming plan pending payment',
                  style: TextStyle(
                    color: AppUIConstants.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Starts: ${dateFormat.format(upcoming.startDate)} • ${upcoming.plan.name.toUpperCase()}',
            style: TextStyle(color: AppUIConstants.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingPaymentButton(BuildContext context) {
    final upcoming = info.upcomingMembership!;
    final paymentAmount = _calculateUpcomingPaymentAmount(upcoming);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            // Create a temporary StudentMembershipInfo for the upcoming membership
            final upcomingInfo = StudentMembershipInfo(
              membership: upcoming,
              library: info.library,
              libraryName: info.libraryName,
              customSlot: info.customSlot,
              daysRemaining: upcoming.daysRemaining(upcoming.startDate),
              isPendingPayment:
                  upcoming.status == MembershipStatus.pendingPayment,
              isActive: false,
              isExpired: false,
            );

            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BlocProvider(
                  create: (_) => sl<StudentPaymentCubit>(),
                  child: PaymentScreen(membershipInfo: upcomingInfo),
                ),
              ),
            );
          },
          icon: const Icon(Icons.payment_outlined, size: 18),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppUIConstants.warning,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            ),
          ),
          label: Text(
            'Pay ₹${paymentAmount.toStringAsFixed(0)} to Activate',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ),
    );
  }

  double _calculateUpcomingPaymentAmount(Membership membership) {
    // Use same logic as StudentMembershipInfo.paymentAmount
    double baseAmount;

    if (info.customSlot != null) {
      final durationInDays = membership.effectiveDurationInDays;
      final months = durationInDays / 30.0;
      baseAmount = info.customSlot!.price * months;
    } else {
      switch (membership.plan) {
        case MembershipPlan.daily:
          baseAmount = 50.0;
          break;
        case MembershipPlan.weekly:
          baseAmount = 300.0;
          break;
        case MembershipPlan.monthly:
          baseAmount = 1000.0;
          break;
        case MembershipPlan.quarterly:
          baseAmount = 2500.0;
          break;
        case MembershipPlan.yearly:
          baseAmount = 8000.0;
          break;
      }
    }

    final discount = membership.paymentBreakdown?.discount ?? 0.0;
    return (baseAmount - discount).clamp(0.0, double.infinity);
  }

  bool _hasActiveUpcomingPlan() {
    // Check if there's an upcoming membership that's active (not pending payment)
    return info.upcomingMembership != null &&
        info.upcomingMembership!.status == MembershipStatus.active;
  }

  Future<void> _sendReminder(BuildContext context) async {
    final useCase = sl<SendPaymentReminder>();
    final result = await useCase(
      SendPaymentReminderParams(membershipId: info.membership.id),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.fold(
              (failure) => failure.message ?? 'Failed to send reminder',
              (_) => 'Reminder sent successfully',
            ),
          ),
          backgroundColor: result.fold(
            (_) => AppUIConstants.error,
            (_) => AppUIConstants.success,
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
          ),
        ),
      );
    }
  }
}

// =============================================================================
// Private Widgets
// =============================================================================

/// Header section of membership card.
class _MembershipHeader extends StatelessWidget {
  const _MembershipHeader({
    required this.libraryName,
    required this.seatNumber,
    required this.sessionTiming,
    required this.isMorning,
    required this.isPending,
    required this.isActive,
    required this.hasPartialPayment,
    required this.isExpired,
  });

  final String libraryName;
  final String seatNumber;
  final String sessionTiming;
  final bool isMorning;
  final bool isPending;
  final bool isActive;
  final bool hasPartialPayment;
  final bool isExpired;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppUIConstants.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            ),
            child: Icon(
              isMorning ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
              color: AppUIConstants.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  libraryName,
                  style: AppUIConstants.headingSm.copyWith(fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  'Seat $seatNumber • $sessionTiming',
                  style: TextStyle(
                    color: AppUIConstants.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          MembershipStatusBadge(
            isPending: isPending,
            isActive: isActive,
            hasPartialPayment: hasPartialPayment,
            isExpired: isExpired,
          ),
        ],
      ),
    );
  }
}

/// Info row showing plan, days left, and amount.
class _MembershipInfoRow extends StatelessWidget {
  const _MembershipInfoRow({
    required this.plan,
    required this.daysRemaining,
    required this.validTill,
    required this.paymentAmount,
    required this.isActive,
    required this.isPending,
  });

  final String plan;
  final int daysRemaining;
  final DateTime validTill;
  final double paymentAmount;
  final bool isActive;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: AppUIConstants.background,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
      ),
      child: Row(
        children: [
          Expanded(
            child: InfoItem(label: 'Plan', value: plan),
          ),
          const InfoDivider(),
          Expanded(
            child: isActive
                ? InfoItem(
                    label: 'Days Left',
                    value: '$daysRemaining',
                    valueColor: daysRemaining <= 7
                        ? AppUIConstants.warning
                        : null,
                  )
                : InfoItem(
                    label: 'Valid Till',
                    value: dateFormat.format(validTill),
                  ),
          ),
          const InfoDivider(),
          Expanded(
            child: InfoItem(
              label: isPending ? 'Due' : 'Paid',
              value: '₹${paymentAmount.toStringAsFixed(0)}',
              valueColor: isPending ? AppUIConstants.warning : null,
            ),
          ),
        ],
      ),
    );
  }
}
