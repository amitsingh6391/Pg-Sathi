import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/library.dart';
import '../cubit/expiry_reminder_cubit.dart';
import '../cubit/expiry_reminder_state.dart';

/// Screen for sending payment reminder notifications.
/// Allows bulk or individual notifications with custom messages.
class PaymentReminderScreen extends StatelessWidget {
  const PaymentReminderScreen({super.key, required this.library});

  final Library library;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<ExpiryReminderCubit>()
            ..loadExpiringMemberships(libraryId: library.id),
      child: _PaymentReminderView(library: library),
    );
  }
}

class _PaymentReminderView extends StatefulWidget {
  const _PaymentReminderView({required this.library});

  final Library library;

  @override
  State<_PaymentReminderView> createState() => _PaymentReminderViewState();
}

class _PaymentReminderViewState extends State<_PaymentReminderView> {
  final _titleController = TextEditingController(
    text: 'Subscription expiring soon!',
  );
  final _bodyController = TextEditingController(
    text: 'Please renew your membership to avoid seat removal.',
  );
  bool _isBulkMode = true;
  bool _hasSentReminders = false; // Track if we've sent reminders

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: BlocConsumer<ExpiryReminderCubit, ExpiryReminderState>(
        listener: (context, state) {
          // Only pop if we've actually sent reminders (not just loaded the list)
          if (state.isSuccess && _hasSentReminders) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.white),
                    SizedBox(width: 12),
                    Text('Reminders sent successfully!'),
                  ],
                ),
                backgroundColor: const Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
            // Reset flag and pop
            _hasSentReminders = false;
            Navigator.of(context).pop();
          } else if (state.isError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage ?? 'Failed to send reminders'),
                backgroundColor: Colors.red.shade600,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // App Bar
                  SliverAppBar(
                    expandedHeight: 120,
                    floating: false,
                    pinned: true,
                    backgroundColor: const Color(0xFF1E293B),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        color: const Color(0xFF1E293B),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const Text(
                                  'Payment Reminders',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Send notifications to expiring members',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Content
                  if (state.isLoading)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (state.isEmpty)
                    SliverFillRemaining(child: _EmptyState())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // Mode Toggle
                          _ModeToggle(
                            isBulkMode: _isBulkMode,
                            onChanged: (value) =>
                                setState(() => _isBulkMode = value),
                          ),
                          const SizedBox(height: 20),

                          // Custom Message Fields
                          _CustomMessageSection(
                            titleController: _titleController,
                            bodyController: _bodyController,
                          ),
                          const SizedBox(height: 20),

                          // Members List
                          if (_isBulkMode) ...[
                            _BulkSelectionSection(),
                            const SizedBox(height: 20),
                            ...state.expiringMemberships
                                .where((info) => info.membership.userId != null)
                                .map((info) {
                                  return _MembershipCard(
                                    info: info,
                                    isSelected: state.selectedStudentIds
                                        .contains(info.membership.userId!),
                                    canSend: state.canSendReminder(
                                      info.membership.userId!,
                                    ),
                                    onTap: () => context
                                        .read<ExpiryReminderCubit>()
                                        .toggleSelection(
                                          info.membership.userId!,
                                        ),
                                  );
                                }),
                            // Add bottom padding to account for floating button
                            const SizedBox(height: 100),
                          ] else ...[
                            _SingleSelectionSection(
                              memberships: state.expiringMemberships,
                              onSend: (userId) =>
                                  _sendSingleReminder(context, userId, state),
                              canSend: (userId) =>
                                  state.canSendReminder(userId),
                            ),
                            // Add bottom padding to account for floating button
                            const SizedBox(height: 100),
                          ],
                        ]),
                      ),
                    ),
                ],
              ),
              // Floating bottom button (only for bulk mode with selection)
              if (_isBulkMode && state.hasSelection && !state.isEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: state.isLoading
                              ? null
                              : () => _sendBulkReminders(context, state),
                          icon: state.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                          label: Text(
                            state.isLoading
                                ? 'Sending...'
                                : 'Send to ${state.selectedStudentIds.length} Member(s)',
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade300,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _sendBulkReminders(BuildContext context, ExpiryReminderState state) {
    if (state.selectedStudentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one member'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Send Reminders'),
        content: Text(
          'Send payment reminders to ${state.selectedStudentIds.length} selected member(s)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _hasSentReminders = true; // Mark that we're sending reminders
              context.read<ExpiryReminderCubit>().sendReminders(
                libraryId: widget.library.id,
                customTitle: _titleController.text.trim().isEmpty
                    ? null
                    : _titleController.text.trim(),
                customBody: _bodyController.text.trim().isEmpty
                    ? null
                    : _bodyController.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _sendSingleReminder(
    BuildContext context,
    String userId,
    ExpiryReminderState state,
  ) {
    if (!state.canSendReminder(userId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reminder already sent. Please wait 24 hours.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _hasSentReminders = true; // Mark that we're sending a reminder
    context.read<ExpiryReminderCubit>().sendReminderToStudent(
      libraryId: widget.library.id,
      userId: userId,
      customTitle: _titleController.text.trim().isEmpty
          ? null
          : _titleController.text.trim(),
      customBody: _bodyController.text.trim().isEmpty
          ? null
          : _bodyController.text.trim(),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.isBulkMode, required this.onChanged});

  final bool isBulkMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleOption(
              label: 'Bulk Notify',
              icon: Icons.group_rounded,
              isSelected: isBulkMode,
              onTap: () => onChanged(true),
            ),
          ),
          Expanded(
            child: _ToggleOption(
              label: 'Single Member',
              icon: Icons.person_rounded,
              isSelected: !isBulkMode,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1).withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF6366F1)
                  : Colors.grey.shade400,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? const Color(0xFF6366F1)
                    : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomMessageSection extends StatelessWidget {
  const _CustomMessageSection({
    required this.titleController,
    required this.bodyController,
  });

  final TextEditingController titleController;
  final TextEditingController bodyController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_rounded, size: 20, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              const Text(
                'Custom Notification',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: titleController,
            decoration: InputDecoration(
              labelText: 'Title',
              hintText: 'Subscription expiring soon!',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: bodyController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Message',
              hintText: 'Please renew your membership...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BulkSelectionSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExpiryReminderCubit, ExpiryReminderState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Checkbox(
                value: state.isAllSelected,
                onChanged: (_) =>
                    context.read<ExpiryReminderCubit>().toggleSelectAll(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Select All (${state.expiringMemberships.length})',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (state.hasSelection)
                Text(
                  '${state.selectedStudentIds.length} selected',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SingleSelectionSection extends StatelessWidget {
  const _SingleSelectionSection({
    required this.memberships,
    required this.onSend,
    required this.canSend,
  });

  final List<ExpiringMembershipInfo> memberships;
  final ValueChanged<String> onSend;
  final bool Function(String) canSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Member to Notify',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        ...memberships.where((info) => info.membership.userId != null).map((
          info,
        ) {
          return _SingleMemberCard(
            info: info,
            canSend: canSend(info.membership.userId!),
            onSend: () => onSend(info.membership.userId!),
          );
        }),
      ],
    );
  }
}

class _SingleMemberCard extends StatelessWidget {
  const _SingleMemberCard({
    required this.info,
    required this.canSend,
    required this.onSend,
  });

  final ExpiringMembershipInfo info;
  final bool canSend;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.user?.displayName??'User',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    info.user?.phone ?? "",
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: info.daysRemaining <= 1
                              ? Colors.red.shade50
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${info.daysRemaining} day${info.daysRemaining != 1 ? 's' : ''} left',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: info.daysRemaining <= 1
                                ? Colors.red.shade700
                                : Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: canSend ? onSend : null,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Send'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MembershipCard extends StatelessWidget {
  const _MembershipCard({
    required this.info,
    required this.isSelected,
    required this.canSend,
    required this.onTap,
  });

  final ExpiringMembershipInfo info;
  final bool isSelected;
  final bool canSend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? const Color(0xFF6366F1) : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Checkbox(value: isSelected, onChanged: (_) => onTap()),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.user?.displayName??'',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        info.user?.phone ?? "",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: info.daysRemaining <= 1
                                  ? Colors.red.shade50
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${info.daysRemaining} day${info.daysRemaining != 1 ? 's' : ''} left',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: info.daysRemaining <= 1
                                    ? Colors.red.shade700
                                    : Colors.orange.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Expires: ${DateFormat('MMM dd, yyyy').format(info.membership.endDate)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!canSend)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Sent',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 20),
            Text(
              'No Memberships Expiring Soon',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All memberships are active and not expiring within the next few days.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
