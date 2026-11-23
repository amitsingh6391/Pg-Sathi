import 'package:material_ui/material_ui.dart';

import '../../../core/app_ui_constants.dart';

/// Loading section with message and skeleton rows.
class LoadingSection extends StatelessWidget {
  const LoadingSection({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppUIConstants.primaryLight,
            ),
          ),
          const SizedBox(height: 16),
          Text(message, style: AppUIConstants.headingSm),
          const SizedBox(height: 24),
          for (var i = 0; i < 3; i++)
            Container(
              height: 84,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppUIConstants.surfaceMuted.withValues(
                  alpha: 0.9 - i * 0.2,
                ),
                borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
              ),
            ),
        ],
      ),
    );
  }
}
