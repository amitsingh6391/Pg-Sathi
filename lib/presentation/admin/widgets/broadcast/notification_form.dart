import 'package:flutter/material.dart';

import '../../../core/app_ui_constants.dart';

/// Modern notification form with title and message inputs.
class NotificationForm extends StatelessWidget {
  const NotificationForm({
    super.key,
    required this.formKey,
    required this.titleController,
    required this.bodyController,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController titleController;
  final TextEditingController bodyController;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notification Content',
            style: AppUIConstants.headingSm.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Craft your message carefully - it will be sent instantly',
            style: AppUIConstants.caption.copyWith(
              color: AppUIConstants.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          
          // Title Field
          Container(
            decoration: BoxDecoration(
              color: AppUIConstants.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppUIConstants.border.withValues(alpha: 0.3),
              ),
            ),
            child: TextFormField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                hintText: 'e.g., Important Update',
                labelStyle: TextStyle(
                  color: AppUIConstants.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: Icon(
                  Icons.title_rounded,
                  color: AppUIConstants.primary,
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Title is required';
                }
                if (value.trim().length < 3) {
                  return 'Title must be at least 3 characters';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 12),
          
          // Message Field
          Container(
            decoration: BoxDecoration(
              color: AppUIConstants.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppUIConstants.border.withValues(alpha: 0.3),
              ),
            ),
            child: TextFormField(
              controller: bodyController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Message',
                hintText: 'Enter your notification message here...',
                labelStyle: TextStyle(
                  color: AppUIConstants.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(bottom: 60),
                  child: Icon(
                    Icons.message_rounded,
                    color: AppUIConstants.primary,
                    size: 20,
                  ),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Message is required';
                }
                if (value.trim().length < 10) {
                  return 'Message must be at least 10 characters';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }
}
