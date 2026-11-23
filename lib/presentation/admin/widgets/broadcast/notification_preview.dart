import 'package:material_ui/material_ui.dart';

import '../../../core/app_ui_constants.dart';

/// Live, phone-style preview of the push notification being composed.
class NotificationPreview extends StatelessWidget {
  const NotificationPreview({
    super.key,
    required this.titleController,
    required this.bodyController,
    required this.audienceLabel,
  });

  final TextEditingController titleController;
  final TextEditingController bodyController;
  final String audienceLabel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([titleController, bodyController]),
      builder: (context, _) {
        final title = titleController.text.trim();
        final body = bodyController.text.trim();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppUIConstants.background,
            borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
            border: Border.all(color: AppUIConstants.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppUIConstants.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('PG SATHI', style: AppUIConstants.caption),
                        const Spacer(),
                        const Text('now', style: AppUIConstants.caption),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title.isEmpty ? 'Notification title' : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppUIConstants.bodyLg.copyWith(
                        color: title.isEmpty
                            ? AppUIConstants.textTertiary
                            : AppUIConstants.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body.isEmpty ? 'Your message will appear here...' : body,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: AppUIConstants.bodyMd.copyWith(
                        color: body.isEmpty
                            ? AppUIConstants.textTertiary
                            : AppUIConstants.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.send_rounded,
                          size: 11,
                          color: AppUIConstants.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'To $audienceLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppUIConstants.caption,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
