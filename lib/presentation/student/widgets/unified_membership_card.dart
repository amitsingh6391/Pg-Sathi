import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/custom_slot.dart';
import '../../../domain/entities/membership.dart';
import '../../../domain/entities/slot.dart';
import '../../../domain/usecases/get_student_memberships.dart';
import '../../../domain/usecases/send_payment_reminder.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/student_home_state.dart';
import '../cubit/student_payment_cubit.dart';
import '../screens/payment_screen.dart';
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

/// Stay card: ring + PG identity header, key facts, today's check-in panel,
/// quick actions and any payment/renewal calls to action.
class UnifiedMembershipCard extends StatelessWidget {
  const UnifiedMembershipCard({
    super.key,
    required this.info,
    required this.userId,
    this.documentStatus = DocumentVerificationStatus.none,
    this.onCardTap,
    this.onViewInvoices,
    this.onViewDocuments,
  });

  final StudentMembershipInfo info;
  final String userId;
  final DocumentVerificationStatus documentStatus;
  final VoidCallback? onCardTap;
  final VoidCallback? onViewInvoices;
  final VoidCallback? onViewDocuments;

  @override
  Widget build(BuildContext context) {
    final isPending = info.isPendingPayment || info.isPendingApproval;
    final isActive = info.isActive;
    final hasPartialPayment = info.hasPartialPayment;
    final isExpiringSoon =
        info.isActive && info.daysRemaining <= 7 && info.daysRemaining >= 0;
    final isExpired = info.isExpired;
    final customSlot = info.customSlot;

    final accentColor = isExpired
        ? AppUIConstants.error
        : (isPending || isExpiringSoon)
        ? AppUIConstants.warning
        : AppUIConstants.primaryLight;
    final radius = BorderRadius.circular(AppUIConstants.radiusLg);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [AppUIConstants.shadowSm],
      ),
      child: Material(
        color: AppUIConstants.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: (isExpired || isPending || isExpiringSoon)
                ? accentColor.withValues(alpha: 0.5)
                : AppUIConstants.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _buildTappableContent(context, customSlot, accentColor),
            if (info.upcomingMembership != null)
              _buildUpcomingMembershipNotice(context),
            if (isActive) _buildQuickActions(context),
            if (hasPartialPayment && isActive)
              _buildCompletePaymentButton(context),
            if (isExpired) _buildRemindButton(context),
            // Renewal: expiring soon or expired, not while payment is pending
            // and not if an active upcoming plan already exists.
            if ((isExpiringSoon || isExpired) &&
                !isPending &&
                !_hasActiveUpcomingPlan())
              _buildRenewalButton(context),
            if (info.hasUpcomingMembershipPendingPayment)
              _buildUpcomingPaymentButton(context),
          ],
        ),
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
    return _getDerivedSlot(customSlot) == Slot.morning ||
        (customSlot != null && customSlot.startTimeOfDay.hour < 14);
  }

  Widget _buildTappableContent(
    BuildContext context,
    CustomSlot? customSlot,
    Color accentColor,
  ) {
    return InkWell(
      onTap: onCardTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onCardTap!();
            },
      child: Column(
        children: [
          _MembershipHeader(
            pgName: info.libraryName ?? 'PG',
            seatNumber: info.seatNumber,
            sessionTiming: info.sessionTiming,
            isMorning: _isMorning(customSlot),
            isPending: info.isPendingPayment || info.isPendingApproval,
            isActive: info.isActive,
            hasPartialPayment: info.hasPartialPayment,
            isExpired: info.isExpired,
            daysRemaining: info.daysRemaining,
            startDate: info.membership.startDate,
            endDate: info.membership.endDate,
            ringColor: accentColor,
          ),
          _MembershipInfoRow(
            plan: info.membership.plan.name.toUpperCase(),
            startDate: info.membership.startDate,
            validTill: info.validTill,
            paymentAmount: info.paymentAmount,
            isPending: info.isPendingPayment || info.isPendingApproval,
          ),
          if (info.isPendingPayment)
            _notice(
              color: AppUIConstants.warning,
              icon: Icons.info_outline_rounded,
              title: 'Complete payment to activate your stay',
              trailing: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppUIConstants.warning,
              ),
            ),
          if (info.isPendingApproval)
            _notice(
              color: AppUIConstants.warning,
              icon: Icons.hourglass_top_rounded,
              title: 'Request sent - waiting for the PG owner to approve',
            ),
          if (info.hasPartialPayment && info.isActive)
            _buildPartialPaymentNotice(),
        ],
      ),
    );
  }

  Widget _notice({
    required Color color,
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppUIConstants.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle, style: AppUIConstants.bodySm),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildPartialPaymentNotice() {
    final remaining = info.remainingBalance;
    final paid = info.membership.paymentBreakdown?.amountPaid ?? 0.0;
    if (remaining <= 0) return const SizedBox.shrink();
    final total = paid + remaining;
    final frac = total <= 0 ? 0.0 : paid / total;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppUIConstants.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(
          color: AppUIConstants.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Paid ₹${paid.toStringAsFixed(0)}',
                style: AppUIConstants.bodySm,
              ),
              const Spacer(),
              Text(
                'Remaining ₹${remaining.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppUIConstants.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: frac.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 6,
                backgroundColor: AppUIConstants.surfaceMuted,
                valueColor: const AlwaysStoppedAnimation(
                  AppUIConstants.warning,
                ),
              ),
            ),
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
              icon: Icons.receipt_long_rounded,
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

  ButtonStyle _ctaStyle(Color bg, {Color fg = Colors.white}) {
    return ElevatedButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: fg,
      padding: const EdgeInsets.symmetric(vertical: 14),
      elevation: 0,
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
      ),
    );
  }

  Widget _buildCompletePaymentButton(BuildContext context) {
    final remaining = info.remainingBalance;
    if (remaining <= 0) return const SizedBox.shrink();

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
                  child: PaymentScreen(
                    membershipInfo: info,
                    overrideAmount: remaining,
                    isRemainingPayment: true,
                  ),
                ),
              ),
            );
          },
          icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
          style: _ctaStyle(AppUIConstants.accent),
          label: Text('Pay remaining ₹${remaining.toStringAsFixed(0)}'),
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
          style: isExpired
              ? _ctaStyle(AppUIConstants.error)
              : _ctaStyle(AppUIConstants.warning, fg: Colors.black87),
          label: Text(
            isExpired ? 'Renew stay' : 'Renew now (${daysRemaining}d left)',
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
          icon: const Icon(Icons.notifications_active_outlined, size: 18),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppUIConstants.primaryLight,
            side: const BorderSide(color: AppUIConstants.primary),
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
            ),
          ),
          label: const Text('Remind owner'),
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
    final startsLine =
        'Starts ${dateFormat.format(upcoming.startDate)} - ${upcoming.plan.name.toUpperCase()}';

    // Payment complete: simple activation notice.
    if (!isPendingPayment && isActive) {
      return _notice(
        color: AppUIConstants.success,
        icon: Icons.event_repeat_rounded,
        title: _paidUpcomingActivationCaption(daysUntilStart),
        subtitle: startsLine,
      );
    }

    return _notice(
      color: AppUIConstants.warning,
      icon: Icons.schedule_rounded,
      title: 'Next plan is waiting for payment',
      subtitle: startsLine,
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
              isPendingApproval:
                  upcoming.status == MembershipStatus.pendingApproval,
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
          icon: const Icon(Icons.payment_rounded, size: 18),
          style: _ctaStyle(AppUIConstants.warning, fg: Colors.black87),
          label: Text('Pay ₹${paymentAmount.toStringAsFixed(0)} to activate'),
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
    // Check if there's an upcoming stay that's active (not pending payment)
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

/// Header: stay-duration ring beside PG identity, bed and timing.
class _MembershipHeader extends StatelessWidget {
  const _MembershipHeader({
    required this.pgName,
    required this.seatNumber,
    required this.sessionTiming,
    required this.isMorning,
    required this.isPending,
    required this.isActive,
    required this.hasPartialPayment,
    required this.isExpired,
    required this.daysRemaining,
    required this.startDate,
    required this.endDate,
    required this.ringColor,
  });

  final String pgName;
  final String seatNumber;
  final String sessionTiming;
  final bool isMorning;
  final bool isPending;
  final bool isActive;
  final bool hasPartialPayment;
  final bool isExpired;
  final int daysRemaining;
  final DateTime startDate;
  final DateTime endDate;
  final Color ringColor;

  double get _progress {
    if (isPending) return 0;
    if (isExpired) return 1;
    final total = endDate.difference(startDate).inHours;
    if (total <= 0) return 1;
    return DateTime.now().difference(startDate).inHours / total;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: const BoxDecoration(color: AppUIConstants.surface),
      child: Row(
        children: [
          StayProgressRing(
            progress: _progress,
            size: 78,
            strokeWidth: 7,
            color: ringColor,
            trackColor: AppUIConstants.background.withValues(alpha: 0.6),
            child: isActive
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$daysRemaining',
                        style: AppUIConstants.statValue.copyWith(fontSize: 22),
                      ),
                      const Text('days left', style: AppUIConstants.caption),
                    ],
                  )
                : Icon(
                    isExpired
                        ? Icons.event_busy_rounded
                        : Icons.hourglass_top_rounded,
                    color: ringColor,
                    size: 28,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MembershipStatusBadge(
                  isPending: isPending,
                  isActive: isActive,
                  hasPartialPayment: hasPartialPayment,
                  isExpired: isExpired,
                ),
                const SizedBox(height: 8),
                Text(
                  pgName,
                  style: AppUIConstants.headingMd,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.bed_rounded,
                      size: 14,
                      color: AppUIConstants.primaryLight,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Bed $seatNumber',
                      style: const TextStyle(
                        color: AppUIConstants.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      isMorning
                          ? Icons.wb_sunny_outlined
                          : Icons.nights_stay_outlined,
                      size: 14,
                      color: AppUIConstants.textTertiary,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        sessionTiming,
                        style: AppUIConstants.bodySm,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Key facts strip: plan, check-in date, valid till, rent.
class _MembershipInfoRow extends StatelessWidget {
  const _MembershipInfoRow({
    required this.plan,
    required this.startDate,
    required this.validTill,
    required this.paymentAmount,
    required this.isPending,
  });

  final String plan;
  final DateTime startDate;
  final DateTime validTill;
  final double paymentAmount;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d');

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppUIConstants.surfaceMuted,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: InfoItem(
              label: 'Checked in',
              value: dateFormat.format(startDate),
            ),
          ),
          const InfoDivider(),
          Expanded(
            child: InfoItem(
              label: 'Valid till',
              value: dateFormat.format(validTill),
            ),
          ),
          const InfoDivider(),
          Expanded(
            child: InfoItem(
              label: isPending ? 'Rent due' : 'Rent paid',
              value: '₹${paymentAmount.toStringAsFixed(0)}',
              valueColor: isPending ? AppUIConstants.warning : null,
            ),
          ),
        ],
      ),
    );
  }
}
