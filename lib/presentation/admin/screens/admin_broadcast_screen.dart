import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/usecases/send_admin_broadcast_notification.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';
import '../cubit/admin_analytics_cubit.dart';
import '../widgets/broadcast/audience_selector.dart';
import '../widgets/broadcast/library_selector.dart';
import '../widgets/broadcast/notification_form.dart';
import '../widgets/broadcast/notification_preview.dart';

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
    return BlocConsumer<AdminAnalyticsCubit, AdminAnalyticsState>(
      listener: _handleBlocEvents,
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppUIConstants.background,
          appBar: AppBar(
            title: const Text(
              'Broadcast',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
            ),
            backgroundColor: AppUIConstants.surface,
            foregroundColor: AppUIConstants.textPrimary,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
          ),
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(),
                  const SizedBox(height: 16),
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
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: _needsLibrarySelection
                        ? LibrarySelector(
                            libraries: state.librarySummaries,
                            selectedLibraryIds: _selectedLibraries,
                            onSelectionChanged: (selection) {
                              setState(() => _selectedLibraries = selection);
                            },
                            targetType:
                                _selectedAudience ==
                                    BroadcastAudience.selectedLibraries
                                ? 'PG owners'
                                : 'PG residents',
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  const SizedBox(height: 16),
                  NotificationForm(
                    formKey: _formKey,
                    titleController: _titleController,
                    bodyController: _bodyController,
                  ),
                  const PremiumSectionHeader('Live preview'),
                  NotificationPreview(
                    titleController: _titleController,
                    bodyController: _bodyController,
                    audienceLabel: _getAudienceDescription(),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: _buildSendBar(state),
        );
      },
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        border: Border.all(color: AppUIConstants.border),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppUIConstants.primarySoft,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            ),
            child: const Icon(
              Icons.campaign_rounded,
              color: AppUIConstants.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Push notification broadcast',
                  style: TextStyle(
                    color: AppUIConstants.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Pick an audience, write your message and send. Delivery is instant.',
                  style: TextStyle(
                    color: AppUIConstants.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendBar(AdminAnalyticsState state) {
    final sending = state.isSendingNotification;
    final summary = _needsLibrarySelection
        ? (_selectedLibraries.isEmpty
              ? 'Select at least one PG'
              : _getAudienceDescription())
        : _getAudienceDescription();
    return Container(
      decoration: const BoxDecoration(
        color: AppUIConstants.surface,
        border: Border(top: BorderSide(color: AppUIConstants.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sending to', style: AppUIConstants.caption),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Text(
                        summary,
                        key: ValueKey(summary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppUIConstants.bodyLg.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: sending ? null : () => _sendNotification(context),
                style: AppUIConstants.accentButtonStyle.copyWith(
                  minimumSize: const WidgetStatePropertyAll(Size(140, 50)),
                ),
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  sending ? 'Sending...' : 'Send',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
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
      _showWarningSnackBar(context, 'Please select at least one PG');
      return;
    }

    _showConfirmationDialog(context);
  }

  void _showConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppUIConstants.surface,
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
              const Text('Confirm broadcast', style: AppUIConstants.headingSm),
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
                backgroundColor: AppUIConstants.accent,
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
        return 'all PG owners';
      case BroadcastAudience.ownersWithLibrary:
        return 'owners with active PGs';
      case BroadcastAudience.ownersWithoutLibrary:
        return 'owners pending PG setup';
      case BroadcastAudience.allStudents:
        return 'all registered residents';
      case BroadcastAudience.studentsWithActiveMembership:
        return 'residents with active stays';
      case BroadcastAudience.activeStudents:
        return 'recently active residents (30 days)';
      case BroadcastAudience.selectedLibraries:
        return 'owners of ${_selectedLibraries.length} selected PGs';
      case BroadcastAudience.selectedLibraryStudents:
        return 'residents of ${_selectedLibraries.length} selected PGs';
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
