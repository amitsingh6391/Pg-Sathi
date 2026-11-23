import 'package:material_ui/material_ui.dart';

import '../../../core/app_ui_constants.dart';
import '../../cubit/bulk_import_state.dart';

/// Import progress section.
class ImportingSection extends StatelessWidget {
  const ImportingSection({required this.state, super.key});

  final BulkImportState state;

  @override
  Widget build(BuildContext context) {
    final percentage = (state.importProgress * 100).toStringAsFixed(0);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 156,
              height: 156,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppUIConstants.surface,
                boxShadow: [
                  BoxShadow(
                    color: AppUIConstants.primaryLight.withValues(alpha: 0.18),
                    blurRadius: 32,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 128,
                    height: 128,
                    child: CircularProgressIndicator(
                      value: state.importProgress,
                      strokeWidth: 9,
                      strokeCap: StrokeCap.round,
                      backgroundColor: AppUIConstants.border,
                      valueColor: const AlwaysStoppedAnimation(
                        AppUIConstants.primaryLight,
                      ),
                    ),
                  ),
                  Text('$percentage%', style: AppUIConstants.headingLg),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Importing residents...',
              style: AppUIConstants.headingMd,
            ),
            const SizedBox(height: 8),
            Text(
              'Processing row ${state.currentRowIndex + 1} of ${state.validRows.length}',
              style: AppUIConstants.bodyMd,
            ),
            const SizedBox(height: 4),
            const Text(
              'Keep this screen open until it finishes',
              style: AppUIConstants.caption,
            ),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: state.importProgress,
                minHeight: 6,
                backgroundColor: AppUIConstants.border,
                valueColor: const AlwaysStoppedAnimation(
                  AppUIConstants.primaryLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
