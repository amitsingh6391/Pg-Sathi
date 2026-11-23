import 'package:material_ui/material_ui.dart';
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
        // File summary + stat tiles
        Container(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          decoration: const BoxDecoration(color: AppUIConstants.surface),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                decoration: BoxDecoration(
                  color: AppUIConstants.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppUIConstants.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(
                          AppUIConstants.radiusSm,
                        ),
                      ),
                      child: const Icon(
                        Icons.table_chart_rounded,
                        size: 18,
                        color: AppUIConstants.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        state.fileName ?? 'Excel File',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppUIConstants.bodyLg,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => context.read<BulkImportCubit>().reset(),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text('Change'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppUIConstants.primaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  StatCard(
                    label: 'Total Rows',
                    value: state.totalRows.toString(),
                    color: AppUIConstants.primaryLight,
                  ),
                  const SizedBox(width: 10),
                  StatCard(
                    label: 'Valid',
                    value: state.validRowCount.toString(),
                    color: AppUIConstants.success,
                  ),
                  const SizedBox(width: 10),
                  StatCard(
                    label: 'Invalid',
                    value: state.invalidRowCount.toString(),
                    color: AppUIConstants.error,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Valid / invalid rows
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppUIConstants.surface,
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusFull,
                    ),
                    border: Border.all(color: AppUIConstants.border),
                  ),
                  child: TabBar(
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: AppUIConstants.primary,
                      borderRadius: BorderRadius.circular(
                        AppUIConstants.radiusFull,
                      ),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: AppUIConstants.textTertiary,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    tabs: [
                      Tab(height: 38, text: 'Valid (${state.validRowCount})'),
                      Tab(
                        height: 38,
                        text: 'Invalid (${state.invalidRowCount})',
                      ),
                    ],
                  ),
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

        // Sticky bottom action bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: AppUIConstants.surface,
            border: const Border(top: BorderSide(color: AppUIConstants.border)),
            boxShadow: [AppUIConstants.shadowLg],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${state.validRowCount} ready to import',
                        style: AppUIConstants.bodyLg,
                      ),
                      Text(
                        state.invalidRowCount > 0
                            ? '${state.invalidRowCount} invalid rows will be skipped'
                            : 'All rows look good',
                        style: AppUIConstants.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: state.canImport
                      ? () => _confirmImport(context, state)
                      : null,
                  icon: const Icon(Icons.cloud_upload_rounded, size: 20),
                  label: const Text(
                    'Import',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: AppUIConstants.primaryButtonStyle.copyWith(
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.disabled)
                          ? AppUIConstants.disabled
                          : AppUIConstants.primaryLight,
                    ),
                  ),
                ),
              ],
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
        backgroundColor: AppUIConstants.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
        ),
        title: const Text('Confirm Import', style: AppUIConstants.headingMd),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to import ${state.validRowCount} residents.',
              style: AppUIConstants.bodyLg,
            ),
            const SizedBox(height: 12),
            const Text('This will:', style: AppUIConstants.bodyMd),
            const SizedBox(height: 8),
            const Text(
              '• Create resident accounts',
              style: AppUIConstants.bodyMd,
            ),
            const Text('• Assign beds and stays', style: AppUIConstants.bodyMd),
            const Text(
              '• Record payments and generate invoices',
              style: AppUIConstants.bodyMd,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppUIConstants.warning.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: AppUIConstants.warning),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This action cannot be undone.',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppUIConstants.textPrimary,
                      ),
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
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppUIConstants.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<BulkImportCubit>().startImport();
            },
            style: AppUIConstants.primaryButtonStyle,
            child: const Text('Start Import'),
          ),
        ],
      ),
    );
  }
}

/// List of import rows.
class RowsList extends StatelessWidget {
  const RowsList({required this.rows, required this.showErrors, super.key});

  final List<ImportRowData> rows;
  final bool showErrors;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    (showErrors
                            ? AppUIConstants.success
                            : AppUIConstants.warning)
                        .withValues(alpha: 0.14),
              ),
              child: Icon(
                showErrors
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                size: 40,
                color: showErrors
                    ? AppUIConstants.success
                    : AppUIConstants.warning,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              showErrors ? 'No invalid rows!' : 'No valid rows found',
              style: AppUIConstants.headingSm,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: rows.length,
      itemBuilder: (context, index) =>
          RowCard(row: rows[index], showErrors: showErrors),
    );
  }
}
