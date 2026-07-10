import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/attendance.dart';
import '../../../domain/entities/slot.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/attendance_cubit.dart';

/// Check-in/Check-out card - Clean, professional design.
/// Supports multi-session attendance (V2).
class CheckInOutCard extends StatefulWidget {
  const CheckInOutCard({
    super.key,
    required this.userId,
    required this.libraryId,
    required this.slot,
    required this.seatNumber,
  });

  final String userId;
  final String libraryId;
  final Slot slot;
  final String seatNumber;

  @override
  State<CheckInOutCard> createState() => _CheckInOutCardState();
}

class _CheckInOutCardState extends State<CheckInOutCard> {
  Timer? _timer;
  Duration _sessionDuration = Duration.zero;
  bool _timerStarted = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer(DateTime checkInTime) {
    if (_timerStarted) return;

    _timerStarted = true;
    _timer?.cancel();
    _sessionDuration = DateTime.now().difference(checkInTime);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _sessionDuration = DateTime.now().difference(checkInTime);
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _timerStarted = false;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  String _formatTotalTime(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AttendanceCubit, AttendanceState>(
      listenWhen: (previous, current) {
        return previous.status != current.status ||
            previous.errorMessage != current.errorMessage ||
            previous.isInActiveSession != current.isInActiveSession;
      },
      listener: (context, state) {
        // Handle errors
        if (state.hasError && state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppUIConstants.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
              ),
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () {
                  context.read<AttendanceCubit>().forceReload(
                    userId: widget.userId,
                    libraryId: widget.libraryId,
                    slot: widget.slot,
                  );
                },
              ),
            ),
          );
          context.read<AttendanceCubit>().clearError();
        }

        // Timer management
        if (state.isInActiveSession && state.activeSessionCheckInTime != null) {
          _startTimer(state.activeSessionCheckInTime!);
        } else {
          _stopTimer();
        }
      },
      buildWhen: (previous, current) {
        return previous.status != current.status ||
            previous.isLoading != current.isLoading ||
            previous.attendance != current.attendance ||
            previous.isInActiveSession != current.isInActiveSession;
      },
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: state.isLoading
                ? _buildLoadingState()
                : _buildContent(context, state),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppUIConstants.primary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Loading...',
            style: TextStyle(color: AppUIConstants.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, AttendanceState state) {
    final isInActiveSession = state.isInActiveSession;
    final completedCount = state.completedSessionCount;
    final totalDuration = state.totalMinutesToday;
    final attendance = state.attendance;

    // Check if all sessions are complete for the day
    final isDayComplete =
        attendance != null &&
        !isInActiveSession &&
        completedCount > 0 &&
        attendance.status == AttendanceStatus.checkedOut;

    if (isInActiveSession) {
      return _buildActiveSessionState(context, state);
    } else if (isDayComplete) {
      return _buildDayCompleteState(context, completedCount, totalDuration);
    } else {
      return _buildReadyToCheckInState(context, state);
    }
  }

  Widget _buildReadyToCheckInState(
    BuildContext context,
    AttendanceState state,
  ) {
    final today = DateFormat('EEE, MMM d').format(DateTime.now());
    final completedCount = state.completedSessionCount;
    final totalDuration = state.totalMinutesToday;
    final hasCompletedSessions = completedCount > 0;

    return Row(
      children: [
        // Left side - Status info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: AppUIConstants.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    today,
                    style: TextStyle(
                      color: AppUIConstants.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                hasCompletedSessions
                    ? '$completedCount session${completedCount > 1 ? 's' : ''} • ${_formatTotalTime(totalDuration)}'
                    : 'Ready to check in',
                style: TextStyle(
                  color: AppUIConstants.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        // Right side - Check In button
        ElevatedButton(
          onPressed: () {
            context.read<AttendanceCubit>().checkIn(
              userId: widget.userId,
              libraryId: widget.libraryId,
              slot: widget.slot,
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppUIConstants.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            ),
          ),
          child: Text(
            hasCompletedSessions ? 'Check In Again' : 'Check In',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveSessionState(BuildContext context, AttendanceState state) {
    final checkInTime = state.activeSessionCheckInTime;
    final completedCount = state.completedSessionCount;
    final totalDuration = state.totalMinutesToday;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Left side - Active session info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppUIConstants.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Session Active',
                        style: TextStyle(
                          color: AppUIConstants.success,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppUIConstants.textPrimary,
                          borderRadius: BorderRadius.circular(
                            AppUIConstants.radiusFull,
                          ),
                        ),
                        child: Text(
                          _formatDuration(_sessionDuration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      if (checkInTime != null) ...[
                        const SizedBox(width: 10),
                        Text(
                          'Since ${DateFormat('h:mm a').format(checkInTime)}',
                          style: TextStyle(
                            color: AppUIConstants.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Right side - Check Out button
            OutlinedButton(
              onPressed: () => _showCheckOutConfirmation(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppUIConstants.error,
                side: BorderSide(
                  color: AppUIConstants.error.withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
                ),
              ),
              child: const Text(
                'Check Out',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        // Previous sessions summary
        if (completedCount > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppUIConstants.background,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 14,
                  color: AppUIConstants.textTertiary,
                ),
                const SizedBox(width: 6),
                Text(
                  '$completedCount earlier session${completedCount > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: AppUIConstants.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTotalTime(totalDuration),
                  style: TextStyle(
                    color: AppUIConstants.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDayCompleteState(
    BuildContext context,
    int sessionCount,
    int totalMinutes,
  ) {
    return Row(
      children: [
        // Left side - Complete status
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  Text(
                    'Session Complete',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppUIConstants.success,
                      fontSize: 13,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppUIConstants.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppUIConstants.radiusFull,
                      ),
                    ),
                    child: Text(
                      '$sessionCount today',
                      style: TextStyle(
                        color: AppUIConstants.success,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Total: ${_formatTotalTime(totalMinutes)}',
                style: TextStyle(
                  color: AppUIConstants.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        // Right side - Check In Again button
        ElevatedButton(
          onPressed: () {
            context.read<AttendanceCubit>().checkIn(
              userId: widget.userId,
              libraryId: widget.libraryId,
              slot: widget.slot,
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppUIConstants.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            ),
          ),
          child: const Text(
            'Check In Again',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    );
  }

  void _showCheckOutConfirmation(BuildContext context) {
    final activeSession = context
        .read<AttendanceCubit>()
        .state
        .attendance
        ?.activeSession;
    if (activeSession == null) return;

    final currentSessionDuration = DateTime.now().difference(
      activeSession.checkInAt,
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppUIConstants.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        ),
        title: Text('Check Out', style: AppUIConstants.headingMd),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('End your current session?', style: AppUIConstants.bodyMd),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppUIConstants.background,
                borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 18,
                    color: AppUIConstants.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Duration: ${_formatDuration(currentSessionDuration)}',
                    style: TextStyle(
                      color: AppUIConstants.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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
            child: Text(
              'Cancel',
              style: TextStyle(color: AppUIConstants.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<AttendanceCubit>().checkOut(
                userId: widget.userId,
                libraryId: widget.libraryId,
                slot: widget.slot,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppUIConstants.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
              ),
            ),
            child: const Text('Check Out'),
          ),
        ],
      ),
    );
  }
}
