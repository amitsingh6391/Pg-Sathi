import 'package:flutter/material.dart';

import '../../models/import_row_data.dart';
import 'detail_chip.dart';

/// Individual row card widget.
class RowCard extends StatelessWidget {
  const RowCard({
    required this.row,
    required this.showErrors,
    super.key,
  });

  final ImportRowData row;
  final bool showErrors;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: row.hasErrors ? Colors.red.shade200 : Colors.green.shade200,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with row number and status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: row.hasErrors
                        ? Colors.red.shade100
                        : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Row ${row.rowIndex}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: row.hasErrors
                          ? Colors.red.shade800
                          : Colors.green.shade800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    row.studentName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(
                  row.hasErrors ? Icons.error : Icons.check_circle,
                  color: row.hasErrors ? Colors.red : Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Details
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                DetailChip(icon: Icons.phone, label: row.phone),
                DetailChip(icon: Icons.event_seat, label: row.seatNumber),
                DetailChip(icon: Icons.schedule, label: row.timingDisplay),
                DetailChip(
                  icon: Icons.currency_rupee,
                  label: '₹${row.amount.toStringAsFixed(0)}',
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Dates
            Text(
              '${_formatDate(row.startDate)} → ${_formatDate(row.endDate)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),

            // Errors
            if (showErrors && row.hasErrors) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: row.validationErrors
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 16,
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  e,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red.shade800,
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
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
