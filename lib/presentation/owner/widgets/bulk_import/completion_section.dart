import 'package:flutter/material.dart';

import '../../../core/app_ui_constants.dart';
import '../../cubit/bulk_import_state.dart';
import '../../models/import_row_data.dart';
import 'summary_card.dart';

/// Completion section showing import results.
class CompletionSection extends StatelessWidget {
  const CompletionSection({required this.state, super.key});

  final BulkImportState state;

  @override
  Widget build(BuildContext context) {
    final summary = state.importSummary;
    if (summary == null) {
      return const Center(child: Text('No summary available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Success header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade600, Colors.green.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.check_circle, size: 64, color: Colors.white),
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
                  '${summary.successCount} students imported successfully',
                  style: TextStyle(
                    fontSize: 16,
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
                color: Colors.green,
              ),
              const SizedBox(width: 12),
              SummaryCard(
                icon: Icons.skip_next,
                label: 'Skipped',
                value: summary.skippedCount.toString(),
                color: Colors.orange,
              ),
              const SizedBox(width: 12),
              SummaryCard(
                icon: Icons.error,
                label: 'Failed',
                value: summary.failedCount.toString(),
                color: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SummaryCard(
                icon: Icons.person_add,
                label: 'New Students',
                value: summary.studentsCreated.toString(),
                color: Colors.blue,
              ),
              const SizedBox(width: 12),
              SummaryCard(
                icon: Icons.person,
                label: 'Existing',
                value: summary.studentsReused.toString(),
                color: Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Results list
          if (summary.results.any((r) => r.status != ImportStatus.success)) ...[
            const Text(
              'Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppUIConstants.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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
        ? Colors.orange
        : Colors.red;
    final icon = result.status == ImportStatus.skipped
        ? Icons.skip_next
        : Icons.error;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text('Row ${result.rowIndex}'),
        subtitle: Text(result.message ?? ''),
        trailing: Text(
          result.phone,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ),
    );
  }
}
