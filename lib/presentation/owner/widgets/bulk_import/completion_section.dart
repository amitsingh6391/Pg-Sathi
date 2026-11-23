import 'package:material_ui/material_ui.dart';

import '../../../core/app_ui_constants.dart';
import '../../cubit/bulk_import_state.dart';
import '../../models/import_row_data.dart';
import '../../../core/widgets/premium_kit.dart';
import 'summary_card.dart';

/// Completion section showing import results.
class CompletionSection extends StatelessWidget {
  const CompletionSection({required this.state, super.key});

  final BulkImportState state;

  @override
  Widget build(BuildContext context) {
    final summary = state.importSummary;
    if (summary == null) {
      return const Center(
        child: Text('No summary available', style: AppUIConstants.bodyMd),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Success header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppUIConstants.surface,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusXl),
              boxShadow: [
                BoxShadow(
                  color: AppUIConstants.primary.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Import Complete!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${summary.successCount} residents imported successfully',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Stats
          Row(
            children: [
              SummaryCard(
                icon: Icons.check_circle,
                label: 'Imported',
                value: summary.successCount.toString(),
                color: AppUIConstants.success,
              ),
              const SizedBox(width: 12),
              SummaryCard(
                icon: Icons.skip_next,
                label: 'Skipped',
                value: summary.skippedCount.toString(),
                color: AppUIConstants.primaryLight,
              ),
              const SizedBox(width: 12),
              SummaryCard(
                icon: Icons.error,
                label: 'Failed',
                value: summary.failedCount.toString(),
                color: AppUIConstants.error,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SummaryCard(
                icon: Icons.person_add_alt_1_rounded,
                label: 'New Residents',
                value: summary.studentsCreated.toString(),
                color: AppUIConstants.primaryLight,
              ),
              const SizedBox(width: 12),
              SummaryCard(
                icon: Icons.person_rounded,
                label: 'Existing',
                value: summary.studentsReused.toString(),
                color: AppUIConstants.primaryLight,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Results list
          if (summary.results.any((r) => r.status != ImportStatus.success)) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: PremiumSectionHeader('Needs attention'),
            ),
            ...summary.results
                .where((r) => r.status != ImportStatus.success)
                .map((r) => _ResultCard(result: r)),
          ],

          const SizedBox(height: 24),

          // Banner ad - shown after successful import
          const SizedBox(height: 20),

          // Done button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: AppUIConstants.primaryButtonStyle,
              child: const Text(
                'Done',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual result card.
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final ImportRowResult result;

  @override
  Widget build(BuildContext context) {
    final color = result.status == ImportStatus.skipped
        ? AppUIConstants.primaryLight
        : AppUIConstants.error;
    final icon = result.status == ImportStatus.skipped
        ? Icons.skip_next
        : Icons.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Row ${result.rowIndex}', style: AppUIConstants.bodyLg),
                if ((result.message ?? '').isNotEmpty)
                  Text(result.message!, style: AppUIConstants.bodySm),
              ],
            ),
          ),
          Text(result.phone, style: AppUIConstants.bodySm),
        ],
      ),
    );
  }
}
