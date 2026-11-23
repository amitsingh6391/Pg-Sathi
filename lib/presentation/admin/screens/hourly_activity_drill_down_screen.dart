import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/entities/user_activity_detail.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/activity_drill_down_cubit.dart';
import '../../core/widgets/premium_kit.dart';
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

  static Route<void> route({required DateTime date, required int hour}) {
    return MaterialPageRoute(
      builder: (_) => HourlyActivityDrillDownScreen(date: date, hour: hour),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<ActivityDrillDownCubit>()
            ..loadHourlyActiveUsers(date: date, hour: hour),
      child: Scaffold(
        backgroundColor: AppUIConstants.background,
        appBar: AppBar(
          backgroundColor: AppUIConstants.background,
          foregroundColor: AppUIConstants.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(_formattedTitle(), style: AppUIConstants.headingSm),
        ),
        body: BlocBuilder<ActivityDrillDownCubit, ActivityDrillDownState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const _ListSkeleton();
            }

            if (state.hasError) {
              return _StateMessage(
                icon: Icons.error_outline_rounded,
                color: AppUIConstants.error,
                message: state.errorMessage ?? 'An error occurred',
                actionLabel: 'Retry',
                onAction: () => context
                    .read<ActivityDrillDownCubit>()
                    .loadHourlyActiveUsers(date: date, hour: hour),
              );
            }

            if (state.isEmpty) {
              return const _StateMessage(
                icon: Icons.person_off_outlined,
                color: AppUIConstants.textTertiary,
                message: 'No users active during this hour',
              );
            }

            return _ActiveUsersList(
              users: state.activeUsers,
              hourLabel: _formatHour(hour),
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
      'Dec',
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

enum _UserFilter { all, live, repeat }

class _ActiveUsersList extends StatefulWidget {
  const _ActiveUsersList({required this.users, required this.hourLabel});

  final List<UserActivityDetail> users;
  final String hourLabel;

  @override
  State<_ActiveUsersList> createState() => _ActiveUsersListState();
}

class _ActiveUsersListState extends State<_ActiveUsersList> {
  _UserFilter _filter = _UserFilter.all;

  @override
  Widget build(BuildContext context) {
    final users = widget.users;
    final liveCount = users.where((u) => u.isActive).length;
    final repeatCount = users.where((u) => u.hasMultipleSessions).length;
    final filtered = switch (_filter) {
      _UserFilter.all => users,
      _UserFilter.live => users.where((u) => u.isActive).toList(),
      _UserFilter.repeat => users.where((u) => u.hasMultipleSessions).toList(),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppUIConstants.spacingLg,
        4,
        AppUIConstants.spacingLg,
        32,
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(AppUIConstants.spacingLg),
          decoration: BoxDecoration(
            color: AppUIConstants.surface,
            border: Border.all(color: AppUIConstants.border),
            borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${users.length}',
                      style: const TextStyle(
                        color: AppUIConstants.textPrimary,
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'users active at ${widget.hourLabel}',
                      style: const TextStyle(
                        color: AppUIConstants.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _HeroStat(value: '$liveCount', label: 'still online'),
                  const SizedBox(height: 8),
                  _HeroStat(value: '$repeatCount', label: 'repeat visits'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppUIConstants.spacingMd),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'All (${users.length})',
                selected: _filter == _UserFilter.all,
                onTap: () => setState(() => _filter = _UserFilter.all),
              ),
              const SizedBox(width: AppUIConstants.spacingSm),
              _FilterChip(
                label: 'Online ($liveCount)',
                selected: _filter == _UserFilter.live,
                onTap: () => setState(() => _filter = _UserFilter.live),
              ),
              const SizedBox(width: AppUIConstants.spacingSm),
              _FilterChip(
                label: 'Repeat ($repeatCount)',
                selected: _filter == _UserFilter.repeat,
                onTap: () => setState(() => _filter = _UserFilter.repeat),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppUIConstants.spacingMd),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: _StateMessage(
              icon: Icons.filter_list_off_rounded,
              color: AppUIConstants.textTertiary,
              message: 'No users match this filter',
            ),
          )
        else
          for (final user in filtered)
            Padding(
              padding: const EdgeInsets.only(bottom: AppUIConstants.spacingMd),
              child: _UserActivityCard(user: user),
            ),
      ],
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppUIConstants.surfaceMuted,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: value,
              style: const TextStyle(
                color: AppUIConstants.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            TextSpan(
              text: '  $label',
              style: const TextStyle(
                color: AppUIConstants.textSecondary,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppUIConstants.primarySoft : AppUIConstants.surface,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
          border: Border.all(
            color: selected
                ? AppUIConstants.primaryLight
                : AppUIConstants.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected
                ? AppUIConstants.primaryLight
                : AppUIConstants.textSecondary,
          ),
        ),
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

class _ListSkeleton extends StatefulWidget {
  const _ListSkeleton();

  @override
  State<_ListSkeleton> createState() => _ListSkeletonState();
}

class _ListSkeletonState extends State<_ListSkeleton>
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

  Widget _bone(double h) => Container(
    height: h,
    decoration: BoxDecoration(
      color: AppUIConstants.surfaceMuted,
      borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_c),
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppUIConstants.spacingLg),
        children: [
          _bone(100),
          const SizedBox(height: AppUIConstants.spacingMd),
          for (var i = 0; i < 4; i++) ...[
            _bone(120),
            const SizedBox(height: AppUIConstants.spacingMd),
          ],
        ],
      ),
    );
  }
}

class _UserActivityCard extends StatelessWidget {
  const _UserActivityCard({required this.user});

  final UserActivityDetail user;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: () => _navigateToUserTimeline(context),
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
                    Text(
                      user.userName,
                      style: AppUIConstants.bodyLg,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        PremiumStatusPill(
                          _getRoleText(),
                          color: AppUIConstants.secondary,
                        ),
                        if (user.hasMultipleSessions) ...[
                          const SizedBox(width: 6),
                          PremiumStatusPill(
                            '${user.sessionCount}x',
                            color: AppUIConstants.primaryLight,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              _buildDurationChip(),
            ],
          ),
          const SizedBox(height: AppUIConstants.spacingMd),
          const Divider(height: 1, color: AppUIConstants.divider),
          const SizedBox(height: AppUIConstants.spacingMd),
          if (user.libraryName != null) ...[
            _buildInfoRow(
              icon: Icons.location_on_outlined,
              label: 'PG',
              value: user.libraryName!,
            ),
            const SizedBox(height: AppUIConstants.spacingSm),
          ],
          _buildInfoRow(
            icon: Icons.login_rounded,
            label: user.hasMultipleSessions ? 'First check-in' : 'Check-in',
            value: user.formattedCheckInTime,
          ),
          const SizedBox(height: AppUIConstants.spacingSm),
          _buildInfoRow(
            icon: user.isActive ? Icons.pending_rounded : Icons.logout_rounded,
            label: user.hasMultipleSessions ? 'Last check-out' : 'Check-out',
            value: user.formattedCheckOutTime,
            valueColor: user.isActive
                ? AppUIConstants.primaryLight
                : AppUIConstants.textSecondary,
          ),
          if (user.hasMultipleSessions) ...[
            const SizedBox(height: AppUIConstants.spacingSm),
            Text(
              '${user.sessionCount} sessions in this hour',
              style: AppUIConstants.caption,
            ),
          ],
        ],
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
    final initial = user.userName.isNotEmpty
        ? user.userName[0].toUpperCase()
        : 'U';
    const color = AppUIConstants.primaryLight;
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: AppUIConstants.surfaceMuted,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildDurationChip() {
    return PremiumStatusPill(
      user.formattedDuration,
      color: user.isActive
          ? AppUIConstants.primaryLight
          : AppUIConstants.textSecondary,
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
        Icon(icon, size: 16, color: AppUIConstants.textTertiary),
        const SizedBox(width: AppUIConstants.spacingSm),
        Text(
          label,
          style: AppUIConstants.bodySm.copyWith(
            color: AppUIConstants.textTertiary,
          ),
        ),
        const SizedBox(width: AppUIConstants.spacingMd),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppUIConstants.bodySm.copyWith(
              fontWeight: FontWeight.w500,
              color: valueColor ?? AppUIConstants.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  String _getRoleText() {
    switch (user.role) {
      case UserRole.student:
        return 'Resident';
      case UserRole.owner:
        return 'Owner';
      case UserRole.admin:
        return 'Admin';
    }
  }
}
