import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/entities/user_activity_detail.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/activity_drill_down_cubit.dart';
import 'user_activity_drill_down_screen.dart';

/// Screen showing users active in a specific hour.
class HourlyActivityDrillDownScreen extends StatelessWidget {
  const HourlyActivityDrillDownScreen({
    super.key,
    required this.date,
    required this.hour,
  });

  final DateTime date;
  final int hour;

  static Route<void> route({
    required DateTime date,
    required int hour,
  }) {
    return MaterialPageRoute(
      builder: (_) => HourlyActivityDrillDownScreen(
        date: date,
        hour: hour,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ActivityDrillDownCubit>()
        ..loadHourlyActiveUsers(date: date, hour: hour),
      child: Scaffold(
        backgroundColor: AppUIConstants.background,
        appBar: AppBar(
          backgroundColor: AppUIConstants.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(_formattedTitle()),
        ),
        body: BlocBuilder<ActivityDrillDownCubit, ActivityDrillDownState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppUIConstants.accent,
                ),
              );
            }

            if (state.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: AppUIConstants.error,
                    ),
                    const SizedBox(height: AppUIConstants.spacingMd),
                    Text(
                      state.errorMessage ?? 'An error occurred',
                      style: AppUIConstants.bodyMd,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppUIConstants.spacingLg),
                    ElevatedButton(
                      onPressed: () => context
                          .read<ActivityDrillDownCubit>()
                          .loadHourlyActiveUsers(date: date, hour: hour),
                      style: AppUIConstants.primaryButtonStyle,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (state.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_off_outlined,
                      size: 64,
                      color: AppUIConstants.disabled,
                    ),
                    const SizedBox(height: AppUIConstants.spacingMd),
                    Text(
                      'No users active during this hour',
                      style: AppUIConstants.bodyLg.copyWith(
                        color: AppUIConstants.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppUIConstants.spacingLg),
              itemCount: state.activeUsers.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppUIConstants.spacingMd),
              itemBuilder: (context, index) {
                final user = state.activeUsers[index];
                return _UserActivityCard(user: user);
              },
            );
          },
        ),
      ),
    );
  }

  String _formattedTitle() {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final monthStr = months[date.month - 1];
    final hourStr = _formatHour(hour);
    return '$monthStr ${date.day} • $hourStr';
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour == 12) return '12 PM';
    if (hour < 12) return '$hour AM';
    return '${hour - 12} PM';
  }
}

class _UserActivityCard extends StatelessWidget {
  const _UserActivityCard({required this.user});

  final UserActivityDetail user;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _navigateToUserTimeline(context),
      child: Container(
        decoration: AppUIConstants.cardDecoration,
        child: Padding(
          padding: const EdgeInsets.all(AppUIConstants.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                _buildAvatar(),
                const SizedBox(width: AppUIConstants.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.userName,
                              style: AppUIConstants.bodyLg,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (user.hasMultipleSessions) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppUIConstants.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${user.sessionCount}x',
                                style: AppUIConstants.caption.copyWith(
                                  color: AppUIConstants.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getRoleText(),
                        style: AppUIConstants.bodySm.copyWith(
                          color: AppUIConstants.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildDurationChip(),
              ],
            ),
            if (user.libraryName != null) ...[
              const SizedBox(height: AppUIConstants.spacingMd),
              const Divider(height: 1, color: AppUIConstants.divider),
              const SizedBox(height: AppUIConstants.spacingMd),
              _buildInfoRow(
                icon: Icons.location_on_outlined,
                label: 'Library',
                value: user.libraryName!,
              ),
            ],
            const SizedBox(height: AppUIConstants.spacingSm),
            _buildInfoRow(
              icon: Icons.login,
              label: user.hasMultipleSessions ? 'First check-in' : 'Check-in',
              value: user.formattedCheckInTime,
            ),
            const SizedBox(height: AppUIConstants.spacingSm),
            _buildInfoRow(
              icon: user.isActive ? Icons.pending : Icons.logout,
              label: user.hasMultipleSessions ? 'Last check-out' : 'Check-out',
              value: user.formattedCheckOutTime,
              valueColor:
                  user.isActive ? AppUIConstants.accent : AppUIConstants.textSecondary,
            ),
            if (user.hasMultipleSessions) ...[
              const SizedBox(height: AppUIConstants.spacingSm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppUIConstants.spacingSm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppUIConstants.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 12,
                      color: AppUIConstants.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${user.sessionCount} sessions in this hour',
                      style: AppUIConstants.caption.copyWith(
                        color: AppUIConstants.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
          ),
        ),
      ),
    );
  }

  void _navigateToUserTimeline(BuildContext context) {
    Navigator.of(context).push(
      UserActivityDrillDownScreen.route(
        userId: user.userId,
        userName: user.userName,
      ),
    );
  }

  Widget _buildAvatar() {
    final initial = user.userName.isNotEmpty ? user.userName[0].toUpperCase() : 'U';
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppUIConstants.accent.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppUIConstants.accent,
          ),
        ),
      ),
    );
  }

  Widget _buildDurationChip() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppUIConstants.spacingSm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: user.isActive
            ? AppUIConstants.accent.withValues(alpha: 0.1)
            : AppUIConstants.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
      ),
      child: Text(
        user.formattedDuration,
        style: AppUIConstants.bodySm.copyWith(
          fontWeight: FontWeight.w600,
          color: user.isActive ? AppUIConstants.accent : AppUIConstants.textSecondary,
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppUIConstants.textTertiary,
        ),
        const SizedBox(width: AppUIConstants.spacingSm),
        Text(
          label,
          style: AppUIConstants.bodySm.copyWith(
            color: AppUIConstants.textTertiary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: AppUIConstants.bodySm.copyWith(
            fontWeight: FontWeight.w500,
            color: valueColor ?? AppUIConstants.textSecondary,
          ),
        ),
      ],
    );
  }

  String _getRoleText() {
    switch (user.role) {
      case UserRole.student:
        return 'Student';
      case UserRole.owner:
        return 'Owner';
      case UserRole.admin:
        return 'Admin';
    }
  }
}
