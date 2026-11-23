import 'package:material_ui/material_ui.dart';

import '../../../core/app_ui_constants.dart';

/// Summary stat tile widget (used in a Row).
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppUIConstants.surface,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          border: Border.all(color: AppUIConstants.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppUIConstants.surfaceMuted,
                borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
              ),
              child: Icon(icon, color: AppUIConstants.textSecondary, size: 18),
            ),
            const SizedBox(height: 10),
            Text(value, style: AppUIConstants.statValue),
            const SizedBox(height: 2),
            Text(label, style: AppUIConstants.bodySm),
          ],
        ),
      ),
    );
  }
}
