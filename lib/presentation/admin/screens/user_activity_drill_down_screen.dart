import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/user_activity_detail.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/activity_drill_down_cubit.dart';

/// Screen showing detailed activity timeline for a specific user.
class UserActivityDrillDownScreen extends StatelessWidget {
  const UserActivityDrillDownScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  final String userId;
  final String userName;

  static Route<void> route({
    required String userId,
    required String userName,
  }) {
    return MaterialPageRoute(
      builder: (_) => UserActivityDrillDownScreen(
        userId: userId,
        userName: userName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    return BlocProvider(
      create: (_) => sl<ActivityDrillDownCubit>()
        ..loadUserActivityTimeline(
          userId: userId,
          startDate: thirtyDaysAgo,
          endDate: now,
        ),
      child: Scaffold(
        backgroundColor: AppUIConstants.background,
        appBar: AppBar(
          backgroundColor: AppUIConstants.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(userName),
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
                          .loadUserActivityTimeline(
                            userId: userId,
                            startDate: thirtyDaysAgo,
                            endDate: now,
                          ),
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
                      Icons.history,
                      size: 64,
                      color: AppUIConstants.disabled,
                    ),
                    const SizedBox(height: AppUIConstants.spacingMd),
                    Text(
                      'No activity in the last 30 days',
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
              itemCount: state.userTimeline.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppUIConstants.spacingLg),
              itemBuilder: (context, index) {
                final timeline = state.userTimeline[index];
                return _TimelineCard(timeline: timeline);
              },
            );
          },
        ),
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.timeline});

  final UserActivityTimeline timeline;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppUIConstants.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const Divider(height: 1, color: AppUIConstants.divider),
          ...timeline.sessions.asMap().entries.map((entry) {
            final isLast = entry.key == timeline.sessions.length - 1;
            return _buildSessionItem(entry.value, isLast);
          }),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(AppUIConstants.spacingLg),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today,
            size: 16,
            color: AppUIConstants.accent,
          ),
          const SizedBox(width: AppUIConstants.spacingSm),
          Text(
            timeline.formattedDate,
            style: AppUIConstants.bodyLg,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppUIConstants.spacingSm,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppUIConstants.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.access_time,
                  size: 12,
                  color: AppUIConstants.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  timeline.formattedTotalDuration,
                  style: AppUIConstants.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppUIConstants.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionItem(UserActivityDetail session, bool isLast) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppUIConstants.spacingLg,
        vertical: AppUIConstants.spacingMd,
      ),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(
                  color: AppUIConstants.divider,
                  width: 1,
                ),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppUIConstants.spacingSm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: session.isActive
                      ? AppUIConstants.accent.withValues(alpha: 0.1)
                      : AppUIConstants.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
                ),
                child: Text(
                  _formatHourRange(session),
                  style: AppUIConstants.caption.copyWith(
                    color: session.isActive
                        ? AppUIConstants.accent
                        : AppUIConstants.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppUIConstants.spacingSm),
              Text(
                session.formattedDuration,
                style: AppUIConstants.bodySm.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (session.isActive) ...[
                const SizedBox(width: AppUIConstants.spacingSm),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppUIConstants.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
          if (session.libraryName != null) ...[
            const SizedBox(height: AppUIConstants.spacingSm),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppUIConstants.textTertiary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    session.libraryName!,
                    style: AppUIConstants.bodySm.copyWith(
                      color: AppUIConstants.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatHourRange(UserActivityDetail session) {
    final start = _formatHour(session.checkInTime.hour);
    if (session.checkOutTime == null) {
      return start;
    }
    final end = _formatHour(session.checkOutTime!.hour);
    if (start == end) {
      return start;
    }
    return '$start-$end';
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12a';
    if (hour == 12) return '12p';
    if (hour < 12) return '${hour}a';
    return '${hour - 12}p';
  }
}
