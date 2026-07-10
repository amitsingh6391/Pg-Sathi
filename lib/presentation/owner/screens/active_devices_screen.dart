import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/device_session.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/device_sessions_cubit.dart';
import '../cubit/device_sessions_state.dart';

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
        backgroundColor: AppUIConstants.surface,
        elevation: 0,
        title: Text(
          'Active Devices',
          style: AppUIConstants.headingMd.copyWith(
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 24),
          color: AppUIConstants.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            color: AppUIConstants.textSecondary,
            onPressed: _loadSessions,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: BlocConsumer<DeviceSessionsCubit, DeviceSessionsState>(
        listener: _handleStateChanges,
        builder: (context, state) {
          if (state.isLoading && state.sessions.isEmpty) {
            return Center(
              child: CircularProgressIndicator(
                color: AppUIConstants.primary,
                strokeWidth: 2,
              ),
            );
          }

          if (state.isError) {
            return _buildErrorState(state.errorMessage);
          }

          if (state.sessions.isEmpty) {
            return _buildEmptyState();
          }

          return _buildSessionsList(state);
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
      onRefresh: () async => _loadSessions(),
      color: AppUIConstants.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(state),
            const SizedBox(height: 24),
            if (otherSessions.isNotEmpty) ...[
              _buildLogoutAllButton(otherSessions.length),
              const SizedBox(height: 20),
            ],
            if (currentSessions.isNotEmpty) ...[
              _buildSectionHeader('Current Device'),
              const SizedBox(height: 12),
              ...currentSessions.map(
                (session) => _buildDeviceCard(session, isCurrent: true),
              ),
              const SizedBox(height: 20),
            ],
            if (otherSessions.isNotEmpty) ...[
              _buildSectionHeader('Other Devices'),
              const SizedBox(height: 12),
              ...otherSessions.map(
                (session) => _buildDeviceCard(session, isCurrent: false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(DeviceSessionsState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppUIConstants.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(color: AppUIConstants.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppUIConstants.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            ),
            child: const Icon(
              Icons.security_rounded,
              color: AppUIConstants.accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${state.activeSessions} Active Sessions',
                  style: AppUIConstants.headingSm.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage devices with access to your account',
                  style: AppUIConstants.bodySm.copyWith(
                    color: AppUIConstants.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutAllButton(int deviceCount) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showLogoutAllDialog(),
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: Text('Logout All Other Devices ($deviceCount)'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppUIConstants.error,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppUIConstants.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(title, style: AppUIConstants.headingSm.copyWith(fontSize: 14)),
      ],
    );
  }

  Widget _buildDeviceCard(DeviceSession session, {required bool isCurrent}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(
          color: isCurrent
              ? AppUIConstants.accent.withValues(alpha: 0.3)
              : AppUIConstants.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getPlatformColor(
                    session.platform,
                  ).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
                ),
                child: Icon(
                  _getPlatformIcon(session.platform),
                  color: _getPlatformColor(session.platform),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            session.deviceName,
                            style: AppUIConstants.headingSm.copyWith(
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (isCurrent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppUIConstants.accent.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Current',
                              style: AppUIConstants.bodySm.copyWith(
                                color: AppUIConstants.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session.platform,
                      style: AppUIConstants.bodySm.copyWith(
                        color: AppUIConstants.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppUIConstants.divider),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoItem(
                icon: Icons.schedule_rounded,
                label: 'Last active',
                value: session.timeSinceActive,
              ),
              if (!isCurrent)
                TextButton.icon(
                  onPressed: () => _showLogoutDialog(session),
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  label: const Text('Logout'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppUIConstants.error,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppUIConstants.textTertiary),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: AppUIConstants.bodySm.copyWith(
            color: AppUIConstants.textSecondary,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: AppUIConstants.bodySm.copyWith(
            color: AppUIConstants.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppUIConstants.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.devices_rounded,
                size: 48,
                color: AppUIConstants.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text('No Active Devices', style: AppUIConstants.headingMd),
            const SizedBox(height: 8),
            Text(
              'You have no active device sessions',
              style: AppUIConstants.bodyMd.copyWith(
                color: AppUIConstants.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String? message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppUIConstants.error,
            ),
            const SizedBox(height: 20),
            Text('Error Loading Devices', style: AppUIConstants.headingMd),
            const SizedBox(height: 8),
            Text(
              message ?? 'Something went wrong',
              style: AppUIConstants.bodyMd.copyWith(
                color: AppUIConstants.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadSessions,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppUIConstants.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(DeviceSession session) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppUIConstants.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        ),
        title: Text('Logout Device?', style: AppUIConstants.headingMd),
        content: Text(
          'This will log out ${session.deviceName}. You\'ll need to sign in again on that device.',
          style: AppUIConstants.bodyMd,
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
              context.read<DeviceSessionsCubit>().logout(
                userId: widget.userId,
                sessionId: session.id,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppUIConstants.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showLogoutAllDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppUIConstants.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        ),
        title: Text(
          'Logout All Other Devices?',
          style: AppUIConstants.headingMd,
        ),
        content: Text(
          'This will log out all devices except your current one. You\'ll need to sign in again on those devices.',
          style: AppUIConstants.bodyMd,
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
              if (widget.currentDeviceId != null) {
                context.read<DeviceSessionsCubit>().logoutAllOthers(
                  userId: widget.userId,
                  currentDeviceId: widget.currentDeviceId!,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppUIConstants.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
              ),
            ),
            child: const Text('Logout All'),
          ),
        ],
      ),
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
    if (lowerPlatform.contains('android')) return const Color(0xFF3DDC84);
    if (lowerPlatform.contains('ios') || lowerPlatform.contains('iphone')) {
      return const Color(0xFF000000);
    }
    if (lowerPlatform.contains('web')) return AppUIConstants.accent;
    return AppUIConstants.primary;
  }
}
