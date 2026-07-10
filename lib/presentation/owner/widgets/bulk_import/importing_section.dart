import 'package:flutter/material.dart';

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
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: state.importProgress,
                      strokeWidth: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(
                        AppUIConstants.primary,
                      ),
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Importing students...',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Processing row ${state.currentRowIndex + 1} of ${state.validRows.length}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            LinearProgressIndicator(
              value: state.importProgress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(AppUIConstants.primary),
            ),
          ],
        ),
      ),
    );
  }
}
