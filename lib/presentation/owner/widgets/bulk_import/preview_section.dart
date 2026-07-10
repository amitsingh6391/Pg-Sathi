import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/app_ui_constants.dart';
import '../../cubit/bulk_import_cubit.dart';
import '../../cubit/bulk_import_state.dart';
import '../../models/import_row_data.dart';
import 'row_card.dart';
import 'stat_card.dart';

/// Preview section showing parsed data.
class PreviewSection extends StatelessWidget {
  const PreviewSection({required this.state, super.key});

  final BulkImportState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Summary header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.description, color: AppUIConstants.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.fileName ?? 'Excel File',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => context.read<BulkImportCubit>().reset(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Change'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  StatCard(
                    label: 'Total Rows',
                    value: state.totalRows.toString(),
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  StatCard(
                    label: 'Valid',
                    value: state.validRowCount.toString(),
                    color: Colors.green,
                  ),
                  const SizedBox(width: 12),
                  StatCard(
                    label: 'Invalid',
                    value: state.invalidRowCount.toString(),
                    color: Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Tabs for valid/invalid rows
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(
                  labelColor: AppUIConstants.primary,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    Tab(text: 'Valid (${state.validRowCount})'),
                    Tab(text: 'Invalid (${state.invalidRowCount})'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      RowsList(rows: state.validRows, showErrors: false),
                      RowsList(rows: state.invalidRows, showErrors: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Import button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.canImport
                    ? () => _confirmImport(context, state)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Import ${state.validRowCount} Students',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmImport(BuildContext context, BulkImportState state) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Import'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to import ${state.validRowCount} students.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('This will:'),
            const SizedBox(height: 8),
            const Text('• Create student accounts'),
            const Text('• Assign seats and memberships'),
            const Text('• Record payments and generate invoices'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.amber.shade700),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This action cannot be undone.',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<BulkImportCubit>().startImport();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Start Import'),
          ),
        ],
      ),
    );
  }
}

/// List of import rows.
class RowsList extends StatelessWidget {
  const RowsList({
    required this.rows,
    required this.showErrors,
    super.key,
  });

  final List<ImportRowData> rows;
  final bool showErrors;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              showErrors ? Icons.check_circle : Icons.warning,
              size: 64,
              color: showErrors ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              showErrors ? 'No invalid rows!' : 'No valid rows found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      itemBuilder: (context, index) => RowCard(
        row: rows[index],
        showErrors: showErrors,
      ),
    );
  }
}
