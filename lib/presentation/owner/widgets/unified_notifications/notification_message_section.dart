import 'package:flutter/material.dart';

import '../../../core/app_ui_constants.dart';

/// Section for customizing notification message content.
class NotificationMessageSection extends StatelessWidget {
  const NotificationMessageSection({
    super.key,
    required this.titleController,
    required this.messageController,
    required this.isPush,
  });

  final TextEditingController? titleController;
  final TextEditingController messageController;
  final bool isPush;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppUIConstants.border),
        boxShadow: [AppUIConstants.shadowSm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          if (isPush && titleController != null) ...[
            _buildTitleField(),
            const SizedBox(height: 16),
          ],
          _buildMessageField(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppUIConstants.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isPush ? Icons.notifications_rounded : Icons.chat_rounded,
            size: 20,
            color: AppUIConstants.primary,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customize Message',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppUIConstants.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Edit notification content',
              style: TextStyle(
                fontSize: 12,
                color: AppUIConstants.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTitleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Title',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppUIConstants.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: titleController,
          style: const TextStyle(fontSize: 14),
          decoration: _inputDecoration('Subscription expiring soon!'),
        ),
      ],
    );
  }

  Widget _buildMessageField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Message',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppUIConstants.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: messageController,
          maxLines: 5,
          style: const TextStyle(fontSize: 14, height: 1.5),
          decoration: _inputDecoration(
            'Hi! Your membership is expiring soon...',
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppUIConstants.textTertiary, fontSize: 13),
      filled: true,
      fillColor: AppUIConstants.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppUIConstants.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppUIConstants.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppUIConstants.primary, width: 1.5),
      ),
    );
  }
}
