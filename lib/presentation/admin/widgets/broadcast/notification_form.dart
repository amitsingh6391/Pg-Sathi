import 'package:material_ui/material_ui.dart';

import '../../../core/app_ui_constants.dart';
import '../../../core/widgets/premium_kit.dart';

/// Notification composer card with title and message inputs and counters.
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

  static const int _titleMax = 60;
  static const int _bodyMax = 240;

  InputDecoration _decoration(String label, String hint, IconData icon) {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppUIConstants.radiusSm + 2),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      counterText: '',
      filled: true,
      fillColor: AppUIConstants.surfaceMuted,
      labelStyle: const TextStyle(color: AppUIConstants.textSecondary),
      hintStyle: const TextStyle(color: AppUIConstants.textTertiary),
      prefixIcon: Icon(icon, size: 20, color: AppUIConstants.primaryLight),
      enabledBorder: b(AppUIConstants.border),
      focusedBorder: b(AppUIConstants.primaryLight, 1.5),
      errorBorder: b(AppUIConstants.error),
      focusedErrorBorder: b(AppUIConstants.error, 1.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _counter(TextEditingController c, int max) {
    return ListenableBuilder(
      listenable: c,
      builder: (_, _) => Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 4, right: 4),
          child: Text(
            '${c.text.length} chars · aim for under $max',
            style: AppUIConstants.caption.copyWith(
              color: c.text.length > max
                  ? AppUIConstants.warning
                  : AppUIConstants.textTertiary,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PremiumSectionHeader('Message'),
            TextFormField(
              controller: titleController,
              style: AppUIConstants.bodyLg,
              textInputAction: TextInputAction.next,
              decoration: _decoration(
                'Title',
                'e.g., Important update',
                Icons.title_rounded,
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
            _counter(titleController, _titleMax),
            const SizedBox(height: 8),
            TextFormField(
              controller: bodyController,
              maxLines: 5,
              minLines: 4,
              style: AppUIConstants.bodyLg,
              decoration: _decoration(
                'Message',
                'Write your notification message...',
                Icons.message_rounded,
              ).copyWith(alignLabelWithHint: true),
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
            _counter(bodyController, _bodyMax),
          ],
        ),
      ),
    );
  }
}
