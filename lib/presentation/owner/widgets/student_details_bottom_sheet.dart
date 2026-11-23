import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:unicons/unicons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/library.dart';
import '../../../domain/usecases/get_occupied_seats.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/student_details_cubit.dart';
import '../../../domain/entities/membership.dart';
import '../../core/widgets/premium_kit.dart';
import 'occupied_seats/resident_status.dart';
import 'student_details_sections.dart';

/// Premium student details bottom sheet with expandable sections
class StudentDetailsBottomSheet extends StatelessWidget {
  const StudentDetailsBottomSheet({
    super.key,
    required this.seatInfo,
    required this.library,
  });

  final OccupiedSeatInfo seatInfo;
  final Library library;

  @override
  Widget build(BuildContext context) {
    final isUnregistered = seatInfo.membership.userId == null;

    return BlocProvider(
      create: (_) {
        final cubit = sl<StudentDetailsCubit>();
        if (isUnregistered) {
          cubit.loadUnregisteredData(
            membershipId: seatInfo.membership.id,
            phoneNumber: seatInfo.membership.phoneNumber,
          );
        } else {
          cubit.loadStudentData(
            studentId: seatInfo.membership.userId!,
            libraryId: library.id,
          );
        }
        return cubit;
      },
      child: _StudentDetailsContent(seatInfo: seatInfo, library: library),
    );
  }
}

class _StudentDetailsContent extends StatelessWidget {
  const _StudentDetailsContent({required this.seatInfo, required this.library});

  final OccupiedSeatInfo seatInfo;
  final Library library;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppUIConstants.border)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppUIConstants.disabled,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Premium Header
          _PremiumHeader(seatInfo: seatInfo),

          // Content
          Expanded(
            child: BlocBuilder<StudentDetailsCubit, StudentDetailsState>(
              builder: (context, state) {
                final isUnregistered = seatInfo.membership.userId == null;

                if (state.isLoading) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    children: [
                      for (var i = 0; i < 3; i++)
                        Container(
                          height: 96,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppUIConstants.surfaceMuted.withValues(
                              alpha: 0.9 - i * 0.25,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppUIConstants.radiusLg,
                            ),
                          ),
                        ),
                    ],
                  );
                }

                if (state.hasError) {
                  return _ErrorState(
                    message: state.errorMessage ?? 'Failed to load data',
                    onRetry: () {
                      if (isUnregistered) {
                        context.read<StudentDetailsCubit>().refreshUnregistered(
                          membershipId: seatInfo.membership.id,
                          phoneNumber: seatInfo.membership.phoneNumber,
                        );
                      } else {
                        context.read<StudentDetailsCubit>().refresh(
                          studentId: seatInfo.membership.userId!,
                          libraryId: library.id,
                        );
                      }
                    },
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  children: [
                    // Unregistered banner
                    if (isUnregistered) ...[
                      _UnregisteredBanner(seatInfo: seatInfo),
                      const SizedBox(height: 12),
                    ],
                    _StaySection(seatInfo: seatInfo),
                    const SizedBox(height: 12),
                    // Profile section (only for registered residents)
                    if (state.student != null)
                      StudentProfileSection(student: state.student!),
                    if (state.student != null) const SizedBox(height: 12),
                    // Invoices (available for both)
                    StudentInvoicesSection(invoices: state.invoices),
                    const SizedBox(height: 12),
                    // Documents (available for both - uses phone as key for unregistered)
                    StudentDocumentsSection(
                      documents: state.documents,
                      studentId: isUnregistered
                          ? seatInfo.membership.phoneNumber
                          : seatInfo.membership.userId!,
                      libraryId: library.id,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Premium header: avatar, name, status pill, bed chip and quick contact buttons.
class _PremiumHeader extends StatelessWidget {
  const _PremiumHeader({required this.seatInfo});

  final OccupiedSeatInfo seatInfo;

  Future<void> _launch(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = residentStatusOf(seatInfo);
    final phone = seatInfo.studentPhone ?? seatInfo.membership.phoneNumber;
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final waNumber = digits.length == 10 ? '91$digits' : digits;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      child: Column(
        children: [
          Row(
            children: [
              ResidentAvatar(
                name: seatInfo.displayName,
                avatarUrl: seatInfo.studentAvatarUrl,
                color: status.color,
                size: 60,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seatInfo.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppUIConstants.headingMd,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        PremiumStatusPill(status.label, color: status.color),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppUIConstants.surfaceMuted,
                            borderRadius: BorderRadius.circular(
                              AppUIConstants.radiusFull,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.bed_rounded,
                                size: 12,
                                color: AppUIConstants.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Bed ${seatInfo.seatId}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppUIConstants.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  UniconsLine.times,
                  color: AppUIConstants.textSecondary,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: AppUIConstants.surfaceMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _QuickContact(
                      icon: Icons.call_rounded,
                      label: 'Call',
                      color: AppUIConstants.success,
                      onTap: () => _launch(Uri(scheme: 'tel', path: phone)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickContact(
                      icon: Icons.chat_rounded,
                      label: 'WhatsApp',
                      color: AppUIConstants.primaryLight,
                      onTap: () =>
                          _launch(Uri.parse('https://wa.me/$waNumber')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickContact extends StatelessWidget {
  const _QuickContact({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stay & bed card built from the membership already on the seat info.
class _StaySection extends StatelessWidget {
  const _StaySection({required this.seatInfo});

  final OccupiedSeatInfo seatInfo;

  @override
  Widget build(BuildContext context) {
    final m = seatInfo.membership;
    final fmt = DateFormat('dd MMM yyyy');
    final status = residentStatusOf(seatInfo);
    final days = seatInfo.daysRemaining;
    final remaining = seatInfo.isReserved
        ? 'Awaiting rent'
        : seatInfo.isExpired
        ? 'Ended ${-days} ${-days == 1 ? 'day' : 'days'} ago'
        : days == 0
        ? 'Ends today'
        : '$days ${days == 1 ? 'day' : 'days'} left';
    final breakdown = m.paymentBreakdown;

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppUIConstants.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bed_rounded,
                  size: 20,
                  color: AppUIConstants.primaryLight,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Stay & Bed', style: AppUIConstants.headingSm),
              ),
              Text(
                remaining,
                style: TextStyle(
                  color: status.color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Fact(label: 'Bed', value: seatInfo.seatId),
              ),
              Expanded(
                child: _Fact(label: 'Plan', value: m.planDisplayLabel),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Fact(label: 'Check-in', value: fmt.format(m.startDate)),
              ),
              Expanded(
                child: _Fact(
                  label: 'Rent due date',
                  value: fmt.format(m.endDate),
                  color: status == ResidentStatus.occupied
                      ? null
                      : status.color,
                ),
              ),
            ],
          ),
          if (breakdown != null && m.hasPartialPayment) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppUIConstants.primaryLight.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
                border: Border.all(
                  color: AppUIConstants.primaryLight.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _Fact(
                      label: 'Paid',
                      value: '₹${breakdown.amountPaid.toStringAsFixed(0)}',
                      color: AppUIConstants.success,
                    ),
                  ),
                  Expanded(
                    child: _Fact(
                      label: 'Balance due',
                      value: '₹${breakdown.amountRemaining.toStringAsFixed(0)}',
                      color: AppUIConstants.primaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (seatInfo.upcomingMembership != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.event_repeat_rounded,
                  size: 16,
                  color: AppUIConstants.primaryLight,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Next stay from ${fmt.format(seatInfo.upcomingMembership!.startDate)}'
                    '${seatInfo.upcomingMembership!.status == MembershipStatus.pendingPayment ? ' (rent pending)' : ''}',
                    style: AppUIConstants.bodySm,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppUIConstants.caption),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color ?? AppUIConstants.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Error state widget
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppUIConstants.error.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(
                UniconsLine.exclamation_triangle,
                size: 40,
                color: AppUIConstants.error,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                color: AppUIConstants.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(UniconsLine.refresh, size: 18),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: AppUIConstants.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner shown for unregistered students with basic info
class _UnregisteredBanner extends StatelessWidget {
  const _UnregisteredBanner({required this.seatInfo});

  final OccupiedSeatInfo seatInfo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppUIConstants.primaryLight.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppUIConstants.primaryLight.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            UniconsLine.user_exclamation,
            size: 22,
            color: AppUIConstants.primaryLight,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Not Registered',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppUIConstants.primaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Resident hasn\'t signed up yet. Showing available data only.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppUIConstants.primaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
