import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:unicons/unicons.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/library.dart';
import '../../../domain/usecases/get_occupied_seats.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/student_details_cubit.dart';
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
  const _StudentDetailsContent({
    required this.seatInfo,
    required this.library,
  });

  final OccupiedSeatInfo seatInfo;
  final Library library;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
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
                  return const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Color(0xFF6366F1),
                    ),
                  );
                }

                if (state.hasError) {
                  return _ErrorState(
                    message: state.errorMessage ?? 'Failed to load data',
                    onRetry: () {
                      if (isUnregistered) {
                        context
                            .read<StudentDetailsCubit>()
                            .refreshUnregistered(
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

                final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                final todayAttendance = state.attendance
                    .where((a) => a.date == today)
                    .firstOrNull;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  children: [
                    // Unregistered banner
                    if (isUnregistered) ...[
                      _UnregisteredBanner(seatInfo: seatInfo),
                      const SizedBox(height: 12),
                    ],
                    // Profile section (only for registered students)
                    if (state.student != null)
                      StudentProfileSection(student: state.student!),
                    if (state.student != null) const SizedBox(height: 12),
                    // Attendance (only for registered students)
                    if (!isUnregistered) ...[
                      StudentAttendanceSection(
                        todayAttendance: todayAttendance,
                        attendanceHistory: state.attendance,
                      ),
                      const SizedBox(height: 12),
                    ],
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

/// Premium gradient header with student info
class _PremiumHeader extends StatelessWidget {
  const _PremiumHeader({required this.seatInfo});

  final OccupiedSeatInfo seatInfo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: seatInfo.studentAvatarUrl != null
                ? NetworkImage(seatInfo.studentAvatarUrl!)
                : null,
            child: seatInfo.studentAvatarUrl == null
                ? Text(
                    seatInfo.displayName.isNotEmpty
                        ? seatInfo.displayName
                            .split(' ')
                            .map((n) => n.isNotEmpty ? n[0] : '')
                            .where((c) => c.isNotEmpty)
                            .take(2)
                            .join()
                            .toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: Colors.blueGrey.shade700,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  seatInfo.displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                if (seatInfo.studentPhone != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        UniconsLine.phone,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        seatInfo.studentPhone!,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              UniconsLine.times,
              color: Colors.grey.shade700,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey.shade100,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
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
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                UniconsLine.exclamation_triangle,
                size: 40,
                color: Colors.red.shade400,
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
                backgroundColor: const Color(0xFF6366F1),
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
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(
            UniconsLine.user_exclamation,
            size: 22,
            color: Colors.orange.shade600,
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
                    color: Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Student hasn\'t signed up yet. Showing available data only.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade700,
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
