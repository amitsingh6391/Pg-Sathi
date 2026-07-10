import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/usecases/send_admin_broadcast_notification.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/admin_analytics_cubit.dart';
import '../widgets/broadcast/audience_selector.dart';
import '../widgets/broadcast/library_selector.dart';
import '../widgets/broadcast/notification_form.dart';

/// Admin screen for sending broadcast notifications with modern UI.
class AdminBroadcastScreen extends StatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  State<AdminBroadcastScreen> createState() => _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends State<AdminBroadcastScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  BroadcastAudience _selectedAudience = BroadcastAudience.allOwners;
  Set<String> _selectedLibraries = {};

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  bool get _needsLibrarySelection =>
      _selectedAudience == BroadcastAudience.selectedLibraries ||
      _selectedAudience == BroadcastAudience.selectedLibraryStudents;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        title: Text(
          'Broadcast Notification',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        backgroundColor: AppUIConstants.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: BlocConsumer<AdminAnalyticsCubit, AdminAnalyticsState>(
        listener: _handleBlocEvents,
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoCard(),
                const SizedBox(height: 24),
                
                AudienceSelector(
                  selectedAudience: _selectedAudience,
                  onAudienceChanged: (audience) {
                    setState(() {
                      _selectedAudience = audience;
                      if (!_needsLibrarySelection) {
                        _selectedLibraries.clear();
                      }
                    });
                  },
                ),
                
                if (_needsLibrarySelection) ...[
                  LibrarySelector(
                    libraries: state.librarySummaries,
                    selectedLibraryIds: _selectedLibraries,
                    onSelectionChanged: (selection) {
                      setState(() => _selectedLibraries = selection);
                    },
                    targetType: _selectedAudience == BroadcastAudience.selectedLibraries
                        ? 'library owners'
                        : 'library students',
                  ),
                ],
                
                const SizedBox(height: 24),
                
                NotificationForm(
                  formKey: _formKey,
                  titleController: _titleController,
                  bodyController: _bodyController,
                ),
                
                const SizedBox(height: 24),
                _buildSendButton(state),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleBlocEvents(BuildContext context, AdminAnalyticsState state) {
    if (state.lastNotificationCount != null) {
      _showSuccessSnackBar(context, state.lastNotificationCount!);
      context.read<AdminAnalyticsCubit>().clearNotificationStatus();
      _clearForm();
    }
    if (state.notificationError != null) {
      _showErrorSnackBar(context, state.notificationError!);
      context.read<AdminAnalyticsCubit>().clearNotificationStatus();
    }
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppUIConstants.accent.withValues(alpha: 0.12),
            AppUIConstants.accent.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppUIConstants.accent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppUIConstants.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.notifications_active_rounded,
              color: AppUIConstants.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Push Notification Broadcast',
                  style: AppUIConstants.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppUIConstants.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Messages are delivered instantly to selected users',
                  style: AppUIConstants.caption.copyWith(
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

  Widget _buildSendButton(AdminAnalyticsState state) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            AppUIConstants.primary,
            AppUIConstants.primary.withValues(alpha: 0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppUIConstants.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: state.isSendingNotification
            ? null
            : () => _sendNotification(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: state.isSendingNotification
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send_rounded, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Send Notification',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _clearForm() {
    _titleController.clear();
    _bodyController.clear();
    setState(() => _selectedLibraries.clear());
  }

  void _sendNotification(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;

    if (_needsLibrarySelection && _selectedLibraries.isEmpty) {
      _showWarningSnackBar(context, 'Please select at least one library');
      return;
    }

    _showConfirmationDialog(context);
  }

  void _showConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppUIConstants.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: AppUIConstants.warning,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Confirm Broadcast'),
            ],
          ),
          content: Text(
            'Send notification to ${_getAudienceDescription()}?\n\n'
            'This action cannot be undone.',
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
                _performSend(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppUIConstants.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Send Now'),
            ),
          ],
        );
      },
    );
  }

  void _performSend(BuildContext context) {
    context.read<AdminAnalyticsCubit>().sendBroadcast(
          title: _titleController.text.trim(),
          body: _bodyController.text.trim(),
          audience: _selectedAudience,
          libraryIds: _needsLibrarySelection ? _selectedLibraries.toList() : null,
        );
  }

  String _getAudienceDescription() {
    switch (_selectedAudience) {
      case BroadcastAudience.allOwners:
        return 'all library owners';
      case BroadcastAudience.ownersWithLibrary:
        return 'owners with active libraries';
      case BroadcastAudience.ownersWithoutLibrary:
        return 'owners pending library setup';
      case BroadcastAudience.allStudents:
        return 'all registered students';
      case BroadcastAudience.studentsWithActiveMembership:
        return 'students with active memberships';
      case BroadcastAudience.activeStudents:
        return 'recently active students (30 days)';
      case BroadcastAudience.selectedLibraries:
        return '${_selectedLibraries.length} selected library owners';
      case BroadcastAudience.selectedLibraryStudents:
        return 'students of ${_selectedLibraries.length} selected libraries';
    }
  }

  void _showSuccessSnackBar(BuildContext context, int count) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Notification sent to $count users successfully!',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppUIConstants.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppUIConstants.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showWarningSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppUIConstants.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
