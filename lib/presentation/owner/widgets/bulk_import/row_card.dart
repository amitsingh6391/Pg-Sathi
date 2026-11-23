import 'package:material_ui/material_ui.dart';

import '../../../core/app_ui_constants.dart';
import '../../../core/widgets/premium_kit.dart';
import '../../models/import_row_data.dart';
import 'detail_chip.dart';

/// Individual row card widget.
class RowCard extends StatelessWidget {
  const RowCard({required this.row, required this.showErrors, super.key});

  final ImportRowData row;
  final bool showErrors;

  @override
  Widget build(BuildContext context) {
    final color = row.hasErrors ? AppUIConstants.error : AppUIConstants.success;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppUIConstants.surfaceMuted,
                            borderRadius: BorderRadius.circular(
                              AppUIConstants.radiusSm,
                            ),
                          ),
                          child: Text(
                            '#${row.rowIndex}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            row.studentName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppUIConstants.headingSm,
                          ),
                        ),
                        PremiumStatusPill(
                          row.hasErrors ? 'Invalid' : 'Valid',
                          color: color,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        DetailChip(icon: Icons.phone_rounded, label: row.phone),
                        DetailChip(
                          icon: Icons.bed_rounded,
                          label: row.seatNumber,
                        ),
                        DetailChip(
                          icon: Icons.schedule_rounded,
                          label: row.timingDisplay,
                        ),
                        DetailChip(
                          icon: Icons.currency_rupee_rounded,
                          label: row.amount.toStringAsFixed(0),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.date_range_rounded,
                          size: 14,
                          color: AppUIConstants.textTertiary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_formatDate(row.startDate)} → ${_formatDate(row.endDate)}',
                          style: AppUIConstants.bodySm,
                        ),
                      ],
                    ),
                    if (showErrors && row.hasErrors) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppUIConstants.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                            AppUIConstants.radiusSm,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: row.validationErrors
                              .map(
                                (e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.error_outline_rounded,
                                        size: 15,
                                        color: AppUIConstants.error,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          e,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppUIConstants.error,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
