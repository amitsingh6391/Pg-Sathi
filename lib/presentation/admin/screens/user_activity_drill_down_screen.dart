import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/user_activity_detail.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';
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

  static Route<void> route({required String userId, required String userName}) {
    return MaterialPageRoute(
      builder: (_) =>
          UserActivityDrillDownScreen(userId: userId, userName: userName),
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
          backgroundColor: AppUIConstants.background,
          foregroundColor: AppUIConstants.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(userName, style: AppUIConstants.headingSm),
        ),
        body: BlocBuilder<ActivityDrillDownCubit, ActivityDrillDownState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const _TimelineSkeleton();
            }

            if (state.hasError) {
              return _StateMessage(
                icon: Icons.error_outline_rounded,
                color: AppUIConstants.error,
                message: state.errorMessage ?? 'An error occurred',
                actionLabel: 'Retry',
                onAction: () => context
                    .read<ActivityDrillDownCubit>()
                    .loadUserActivityTimeline(
                      userId: userId,
                      startDate: thirtyDaysAgo,
                      endDate: now,
                    ),
              );
            }

            if (state.isEmpty) {
              return const _StateMessage(
                icon: Icons.history_rounded,
                color: AppUIConstants.textTertiary,
                message: 'No activity in the last 30 days',
              );
            }

            final timelines = state.userTimeline;
            final totalMinutes = timelines.fold<int>(
              0,
              (s, t) => s + t.totalDuration,
            );
            final totalSessions = timelines.fold<int>(
              0,
              (s, t) => s + t.sessions.length,
            );

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppUIConstants.spacingLg,
                4,
                AppUIConstants.spacingLg,
                32,
              ),
              itemCount: timelines.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _SummaryHero(
                    userName: userName,
                    days: timelines.length,
                    sessions: totalSessions,
                    totalMinutes: totalMinutes,
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: AppUIConstants.spacingMd,
                  ),
                  child: _TimelineCard(timeline: timelines[index - 1]),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

String _fmtMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  return '${h}h ${m}m';
}

class _SummaryHero extends StatelessWidget {
  const _SummaryHero({
    required this.userName,
    required this.days,
    required this.sessions,
    required this.totalMinutes,
  });

  final String userName;
  final int days;
  final int sessions;
  final int totalMinutes;

  @override
  Widget build(BuildContext context) {
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';
    return Container(
      margin: const EdgeInsets.only(bottom: AppUIConstants.spacingSm),
      padding: const EdgeInsets.all(AppUIConstants.spacingLg),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        border: Border.all(color: AppUIConstants.border),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppUIConstants.surfaceMuted,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppUIConstants.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppUIConstants.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppUIConstants.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'Last 30 days of activity',
                      style: TextStyle(
                        color: AppUIConstants.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppUIConstants.spacingLg),
          Text(
            _fmtMinutes(totalMinutes),
            style: const TextStyle(
              color: AppUIConstants.textPrimary,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Text(
            'Total time on app',
            style: TextStyle(color: AppUIConstants.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: AppUIConstants.spacingMd),
          Row(
            children: [
              _HeroChip(
                icon: Icons.calendar_today_rounded,
                text: '$days active days',
              ),
              const SizedBox(width: AppUIConstants.spacingSm),
              _HeroChip(icon: Icons.login_rounded, text: '$sessions sessions'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppUIConstants.surfaceMuted,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppUIConstants.textSecondary),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: AppUIConstants.textPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.color,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color color;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppUIConstants.spacing2Xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppUIConstants.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 34,
                color: color == AppUIConstants.error
                    ? AppUIConstants.textSecondary
                    : AppUIConstants.primaryLight,
              ),
            ),
            const SizedBox(height: AppUIConstants.spacingLg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppUIConstants.bodyLg.copyWith(
                color: AppUIConstants.textSecondary,
              ),
            ),
            if (onAction != null) ...[
              const SizedBox(height: AppUIConstants.spacingLg),
              ElevatedButton(
                onPressed: onAction,
                style: AppUIConstants.primaryButtonStyle,
                child: Text(actionLabel ?? 'Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pulsing placeholder block used while loading.
class _Bone extends StatelessWidget {
  const _Bone({required this.height, this.radius = 10});
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppUIConstants.surfaceMuted,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _TimelineSkeleton extends StatefulWidget {
  const _TimelineSkeleton();

  @override
  State<_TimelineSkeleton> createState() => _TimelineSkeletonState();
}

class _TimelineSkeletonState extends State<_TimelineSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_c),
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppUIConstants.spacingLg),
        children: [
          const _Bone(height: 168, radius: AppUIConstants.radiusLg),
          for (var i = 0; i < 3; i++) ...[
            const SizedBox(height: AppUIConstants.spacingMd),
            const _Bone(height: 110, radius: AppUIConstants.radiusLg),
          ],
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.timeline});

  final UserActivityTimeline timeline;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const Divider(height: 1, color: AppUIConstants.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppUIConstants.spacingLg,
              AppUIConstants.spacingMd,
              AppUIConstants.spacingLg,
              AppUIConstants.spacingMd,
            ),
            child: Column(
              children: [
                for (final entry in timeline.sessions.asMap().entries)
                  _buildSessionItem(
                    entry.value,
                    entry.key == timeline.sessions.length - 1,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(AppUIConstants.spacingLg),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today_rounded,
            size: 16,
            color: AppUIConstants.primaryLight,
          ),
          const SizedBox(width: AppUIConstants.spacingSm),
          Expanded(
            child: Text(timeline.formattedDate, style: AppUIConstants.bodyLg),
          ),
          PremiumStatusPill(
            timeline.formattedTotalDuration,
            color: AppUIConstants.primaryLight,
          ),
        ],
      ),
    );
  }

  /// One session row on a vertical timeline rail.
  Widget _buildSessionItem(UserActivityDetail session, bool isLast) {
    const color = AppUIConstants.primaryLight;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 18,
            child: Column(
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppUIConstants.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppUIConstants.spacingSm),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: isLast ? 0 : AppUIConstants.spacingMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _formatHourRange(session),
                        style: AppUIConstants.bodyMd.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
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
                        const PremiumStatusPill(
                          'Live',
                          color: AppUIConstants.success,
                        ),
                      ],
                    ],
                  ),
                  if (session.libraryName != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
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
            ),
          ),
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
