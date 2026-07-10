import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/library.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/expiry_reminder_cubit.dart';
import '../cubit/expiry_reminder_state.dart';
import '../cubit/whatsapp_reminder_cubit.dart';
import '../cubit/whatsapp_reminder_state.dart';
import '../widgets/unified_notifications/unified_notifications.dart';

/// Unified notification screen for Push (FCM) and WhatsApp reminders.
class UnifiedNotificationsScreen extends StatelessWidget {
  const UnifiedNotificationsScreen({super.key, required this.library});

  final Library library;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              sl<ExpiryReminderCubit>()
                ..loadExpiringMemberships(libraryId: library.id),
        ),
        BlocProvider(
          create: (_) =>
              sl<WhatsAppReminderCubit>()..loadReminders(libraryId: library.id),
        ),
      ],
      child: _UnifiedNotificationsView(library: library),
    );
  }
}

class _UnifiedNotificationsView extends StatefulWidget {
  const _UnifiedNotificationsView({required this.library});
  final Library library;

  @override
  State<_UnifiedNotificationsView> createState() =>
      _UnifiedNotificationsViewState();
}

class _UnifiedNotificationsViewState extends State<_UnifiedNotificationsView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;

  final _titleController = TextEditingController(
    text: 'Subscription expiring soon!',
  );
  final _messageController = TextEditingController(
    text:
        'Hi! 👋\n\nYour PG membership is expiring soon.\n\nPlease renew to continue your stay without interruption.\n\nThank you! 🏠',
  );

  bool _hasSentReminders = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _messageController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<WhatsAppReminderCubit>().continueQueue(
        customMessage: _messageController.text,
      );
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? AppUIConstants.error
            : AppUIConstants.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PushNotificationTab(
            library: widget.library,
            titleController: _titleController,
            messageController: _messageController,
            onSuccess: () => _showSnackBar('Push notifications sent!'),
            onError: (msg) => _showSnackBar(msg, isError: true),
            hasSentReminders: _hasSentReminders,
            onSendReminders: () => _hasSentReminders = true,
          ),
          _WhatsAppTab(
            messageController: _messageController,
            onSuccess: (msg) => _showSnackBar(msg),
            onError: (msg) => _showSnackBar(msg, isError: true),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppUIConstants.primary,
      elevation: 0,
      title: const Text(
        'Send Notifications',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        tabs: const [
          Tab(text: 'Push Notification'),
          Tab(text: 'WhatsApp'),
        ],
      ),
    );
  }
}

// =============================================================================
// Push Notification Tab
// =============================================================================

class _PushNotificationTab extends StatelessWidget {
  const _PushNotificationTab({
    required this.library,
    required this.titleController,
    required this.messageController,
    required this.onSuccess,
    required this.onError,
    required this.hasSentReminders,
    required this.onSendReminders,
  });

  final Library library;
  final TextEditingController titleController;
  final TextEditingController messageController;
  final VoidCallback onSuccess;
  final void Function(String) onError;
  final bool hasSentReminders;
  final VoidCallback onSendReminders;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExpiryReminderCubit, ExpiryReminderState>(
      listener: (context, state) {
        if (state.isSuccess && hasSentReminders) {
          onSuccess();
        } else if (state.isError) {
          onError(state.errorMessage ?? 'Failed');
        }
      },
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.isEmpty) {
          return const NotificationEmptyState();
        }

        return _buildContent(context, state);
      },
    );
  }

  Widget _buildContent(BuildContext context, ExpiryReminderState state) {
    final registeredMemberships = state.expiringMemberships
        .where((info) => info.isRegistered)
        .toList();
    final unregisteredMemberships = state.expiringMemberships
        .where((info) => !info.isRegistered)
        .toList();

    final uniqueUserIds = registeredMemberships
        .map((info) => info.membership.userId!)
        .toSet();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              NotificationMessageSection(
                titleController: titleController,
                messageController: messageController,
                isPush: true,
              ),
              const SizedBox(height: 20),
              MemberSelectionHeader(
                isAllSelected: state.isAllSelected,
                selectedCount: state.selectedStudentIds.length,
                totalCount: uniqueUserIds.length,
                onToggleSelectAll: () =>
                    context.read<ExpiryReminderCubit>().toggleSelectAll(),
              ),
              const SizedBox(height: 12),
              // Show registered memberships (can receive push notifications)
              ...registeredMemberships.map(
                (info) => _buildMemberCard(context, state, info),
              ),
              // Show unregistered memberships (cannot receive push notifications)
              if (unregisteredMemberships.isNotEmpty) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Unregistered Members (Cannot receive push notifications)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...unregisteredMemberships.map(
                  (info) => _buildUnregisteredMemberCard(context, info),
                ),
              ],
            ],
          ),
        ),
        if (state.hasSelection)
          NotificationSendButton(
            label:
                'Send Push Notification (${state.selectedStudentIds.length})',
            onPressed: () => _showConfirmDialog(context, state),
          ),
      ],
    );
  }

  Widget _buildMemberCard(
    BuildContext context,
    ExpiryReminderState state,
    ExpiringMembershipInfo info,
  ) {
    final userId = info.membership.userId!;
    final isSelected = state.selectedStudentIds.contains(userId);
    final canSend = state.canSendReminder(userId);

    return MemberCard(
      name: info.displayName,
      phone: info.phone,
      daysLeft: info.daysRemaining,
      expiryDate: info.membership.endDate,
      isSelected: isSelected,
      isSent: !canSend,
      onTap: () => context.read<ExpiryReminderCubit>().toggleSelection(userId),
    );
  }

  Widget _buildUnregisteredMemberCard(
    BuildContext context,
    ExpiringMembershipInfo info,
  ) {
    return Opacity(
      opacity: 0.6,
      child: MemberCard(
        name: info.displayName,
        phone: info.phone,
        daysLeft: info.daysRemaining,
        expiryDate: info.membership.endDate,
        isSelected: false,
        isSent: true, // Disabled state
        onTap: null, // Cannot select
      ),
    );
  }

  void _showConfirmDialog(BuildContext context, ExpiryReminderState state) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Send Push Notifications'),
        content: Text('Send to ${state.selectedStudentIds.length} member(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onSendReminders();
              context.read<ExpiryReminderCubit>().sendReminders(
                libraryId: library.id,
                customTitle: titleController.text.trim().isEmpty
                    ? null
                    : titleController.text.trim(),
                customBody: messageController.text.trim().isEmpty
                    ? null
                    : messageController.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppUIConstants.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// WhatsApp Tab
// =============================================================================

class _WhatsAppTab extends StatelessWidget {
  const _WhatsAppTab({
    required this.messageController,
    required this.onSuccess,
    required this.onError,
  });

  final TextEditingController messageController;
  final void Function(String) onSuccess;
  final void Function(String) onError;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WhatsAppReminderCubit, WhatsAppReminderState>(
      listener: (context, state) {
        if (state.isSendingAll && state.pendingQueue.isEmpty) {
          onSuccess('✓ All messages sent!');
        }
      },
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.isEmpty) {
          return const NotificationEmptyState();
        }

        return _buildContent(context, state);
      },
    );
  }

  Widget _buildContent(BuildContext context, WhatsAppReminderState state) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              NotificationMessageSection(
                titleController: null,
                messageController: messageController,
                isPush: false,
              ),
              const SizedBox(height: 20),
              MembersListHeader(
                title: 'Expiring Members',
                count: state.reminders.length,
              ),
              const SizedBox(height: 12),
              ...state.reminders.map(
                (reminder) => MemberCard(
                  name: reminder.studentName,
                  phone: reminder.studentPhone,
                  daysLeft: reminder.daysUntilExpiry,
                  expiryDate: reminder.expiryDate,
                  isSent: !reminder.canSendMoreToday,
                  showSendButton: true,
                  onSend: reminder.canSendMoreToday
                      ? () =>
                            context.read<WhatsAppReminderCubit>().sendWhatsApp(
                              reminder: reminder,
                              customMessage: messageController.text,
                            )
                      : null,
                ),
              ),
            ],
          ),
        ),
        if (state.pendingCount > 0)
          NotificationSendButton(
            label: 'Send All WhatsApp (${state.pendingCount})',
            onPressed: () => context
                .read<WhatsAppReminderCubit>()
                .sendAllWhatsApp(customMessage: messageController.text),
          ),
      ],
    );
  }
}
