import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/device_session.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';
import '../cubit/device_sessions_cubit.dart';
import '../cubit/device_sessions_state.dart';
import '../../core/widgets/pulse_box.dart';

/// Screen to display and manage active device sessions.
class ActiveDevicesScreen extends StatefulWidget {
  const ActiveDevicesScreen({
    super.key,
    required this.userId,
    this.currentDeviceId,
  });

  final String userId;
  final String? currentDeviceId;

  @override
  State<ActiveDevicesScreen> createState() => _ActiveDevicesScreenState();
}

class _ActiveDevicesScreenState extends State<ActiveDevicesScreen> {
  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  void _loadSessions() {
    context.read<DeviceSessionsCubit>().loadDeviceSessions(
      userId: widget.userId,
      currentDeviceId: widget.currentDeviceId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        backgroundColor: AppUIConstants.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Your devices', style: AppUIConstants.headingMd),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 24),
          color: AppUIConstants.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            color: AppUIConstants.textSecondary,
            onPressed: () {
              HapticFeedback.selectionClick();
              _loadSessions();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: BlocConsumer<DeviceSessionsCubit, DeviceSessionsState>(
        listener: _handleStateChanges,
        builder: (context, state) {
          final Widget child;
          if (state.isLoading && state.sessions.isEmpty) {
            child = const _DevicesSkeleton(key: ValueKey('loading'));
          } else if (state.isError) {
            child = _buildErrorState(state.errorMessage);
          } else if (state.sessions.isEmpty) {
            child = _buildEmptyState();
          } else {
            child = _buildSessionsList(state);
          }
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: child,
          );
        },
      ),
    );
  }

  void _handleStateChanges(BuildContext context, DeviceSessionsState state) {
    if (state.status == DeviceSessionsStatus.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Device logged out successfully'),
          backgroundColor: AppUIConstants.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
          ),
        ),
      );
    } else if (state.isError && state.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.errorMessage!),
          backgroundColor: AppUIConstants.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
          ),
        ),
      );
    }
  }

  Widget _buildSessionsList(DeviceSessionsState state) {
    final currentDeviceId = widget.currentDeviceId;
    final sessions = state.sessions.cast<DeviceSession>();

    final currentSessions = currentDeviceId != null
        ? sessions.where((s) => s.deviceId == currentDeviceId).toList()
        : <DeviceSession>[];

    final otherSessions = currentDeviceId != null
        ? sessions.where((s) => s.deviceId != currentDeviceId).toList()
        : sessions.toList();

    return RefreshIndicator(
      key: const ValueKey('list'),
      onRefresh: () async => _loadSessions(),
      color: AppUIConstants.primaryLight,
      backgroundColor: AppUIConstants.surface,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummary(state),
          if (currentSessions.isNotEmpty) ...[
            const PremiumSectionHeader('This device'),
            ...currentSessions.map(
              (session) => _buildDeviceCard(session, isCurrent: true),
            ),
          ],
          if (otherSessions.isNotEmpty) ...[
            PremiumSectionHeader(
              'Other devices',
              action: widget.currentDeviceId != null ? 'Log out all' : null,
              onAction: _showLogoutAllSheet,
            ),
            ...otherSessions.map(
              (session) => _buildDeviceCard(session, isCurrent: false),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSummary(DeviceSessionsState state) {
    return PremiumCard(
      glow: AppUIConstants.primary,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppUIConstants.primarySoft,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm + 2),
            ),
            child: const Icon(
              Icons.shield_moon_rounded,
              color: AppUIConstants.primaryLight,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${state.activeSessions} signed-in device${state.activeSessions == 1 ? '' : 's'}',
                  style: AppUIConstants.headingSm,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Log out anything you do not recognise.',
                  style: AppUIConstants.bodySm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(DeviceSession session, {required bool isCurrent}) {
    final platformColor = _getPlatformColor(session.platform);
    return TweenAnimationBuilder<double>(
      key: ValueKey(session.id),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - t)),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isCurrent
              ? AppUIConstants.primarySoft
              : AppUIConstants.surface,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
          border: Border.all(
            color: isCurrent
                ? AppUIConstants.primaryLight.withValues(alpha: 0.5)
                : AppUIConstants.border,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: platformColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(
                  AppUIConstants.radiusSm + 2,
                ),
              ),
              child: Icon(
                _getPlatformIcon(session.platform),
                color: platformColor,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          session.deviceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppUIConstants.bodyLg.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 8),
                        const PremiumStatusPill(
                          'This device',
                          color: AppUIConstants.primaryLight,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(session.platform, style: AppUIConstants.bodySm),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: AppUIConstants.textTertiary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isCurrent
                            ? 'Active now'
                            : 'Last active ${session.timeSinceActive}',
                        style: AppUIConstants.caption.copyWith(
                          color: isCurrent
                              ? AppUIConstants.success
                              : AppUIConstants.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!isCurrent)
              IconButton(
                onPressed: () => _showLogoutSheet(session),
                tooltip: 'Log out this device',
                icon: const Icon(Icons.logout_rounded, size: 20),
                style: IconButton.styleFrom(
                  foregroundColor: AppUIConstants.error,
                  backgroundColor: AppUIConstants.error.withValues(alpha: 0.12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      key: const ValueKey('empty'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppUIConstants.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.devices_rounded,
                size: 44,
                color: AppUIConstants.primaryLight,
              ),
            ),
            const SizedBox(height: 20),
            const Text('No active devices', style: AppUIConstants.headingMd),
            const SizedBox(height: 8),
            const Text(
              'Signed-in devices will show up here.',
              style: AppUIConstants.bodyMd,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _loadSessions,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppUIConstants.primaryLight,
                side: const BorderSide(color: AppUIConstants.primaryLight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String? message) {
    return Center(
      key: const ValueKey('error'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppUIConstants.error.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 44,
                color: AppUIConstants.error,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Could not load devices',
              style: AppUIConstants.headingMd,
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'Something went wrong',
              style: AppUIConstants.bodyMd,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loadSessions,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: AppUIConstants.primary,
                foregroundColor: Colors.white,
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

  Future<void> _confirmSheet({
    required IconData icon,
    required String title,
    required String message,
    required String confirmLabel,
    required VoidCallback onConfirm,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppUIConstants.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppUIConstants.radiusXl),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppUIConstants.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppUIConstants.error.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppUIConstants.error, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: AppUIConstants.headingMd,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: AppUIConstants.bodyMd,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppUIConstants.textSecondary,
                        side: const BorderSide(color: AppUIConstants.border),
                        minimumSize: const Size(0, 50),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Navigator.of(sheetContext).pop();
                        onConfirm();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppUIConstants.error,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 50),
                      ),
                      child: Text(confirmLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutSheet(DeviceSession session) {
    _confirmSheet(
      icon: Icons.logout_rounded,
      title: 'Log out ${session.deviceName}?',
      message: 'You will need to sign in again on that device.',
      confirmLabel: 'Log out',
      onConfirm: () {
        context.read<DeviceSessionsCubit>().logout(
          userId: widget.userId,
          sessionId: session.id,
        );
      },
    );
  }

  void _showLogoutAllSheet() {
    _confirmSheet(
      icon: Icons.devices_other_rounded,
      title: 'Log out all other devices?',
      message:
          'Everything except this device will be signed out. You will need to sign in again on those devices.',
      confirmLabel: 'Log out all',
      onConfirm: () {
        if (widget.currentDeviceId != null) {
          context.read<DeviceSessionsCubit>().logoutAllOthers(
            userId: widget.userId,
            currentDeviceId: widget.currentDeviceId!,
          );
        }
      },
    );
  }

  IconData _getPlatformIcon(String platform) {
    final lowerPlatform = platform.toLowerCase();
    if (lowerPlatform.contains('android')) return Icons.android_rounded;
    if (lowerPlatform.contains('ios') || lowerPlatform.contains('iphone')) {
      return Icons.phone_iphone_rounded;
    }
    if (lowerPlatform.contains('web')) return Icons.language_rounded;
    if (lowerPlatform.contains('windows')) return Icons.desktop_windows_rounded;
    if (lowerPlatform.contains('mac')) return Icons.laptop_mac_rounded;
    if (lowerPlatform.contains('linux')) return Icons.computer_rounded;
    return Icons.devices_rounded;
  }

  Color _getPlatformColor(String platform) {
    final lowerPlatform = platform.toLowerCase();
    if (lowerPlatform.contains('android')) return AppUIConstants.success;
    if (lowerPlatform.contains('ios') || lowerPlatform.contains('iphone')) {
      return AppUIConstants.textPrimary;
    }
    if (lowerPlatform.contains('web')) return AppUIConstants.primaryLight;
    return AppUIConstants.primaryLight;
  }
}

class _DevicesSkeleton extends StatelessWidget {
  const _DevicesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        const PulseBox(height: 76, radius: AppUIConstants.radiusLg),
        const SizedBox(height: 28),
        for (var i = 0; i < 3; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: AppUIConstants.cardDecorationFlat,
            child: const Row(
              children: [
                PulseBox(width: 48, height: 48, radius: 12),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PulseBox(width: 140, height: 14),
                      SizedBox(height: 8),
                      PulseBox(width: 90, height: 11),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
