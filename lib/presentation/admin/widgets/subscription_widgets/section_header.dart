import 'package:material_ui/material_ui.dart';

import '../../../core/app_ui_constants.dart';

/// Section header widget for subscription lists.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    required this.icon,
    this.count,
    super.key,
  });

  final String title;
  final IconData icon;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppUIConstants.surfaceMuted,
            borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
          ),
          child: Icon(icon, color: AppUIConstants.primaryLight, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: AppUIConstants.headingSm)),
        if (count != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppUIConstants.surfaceMuted,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
              border: Border.all(color: AppUIConstants.border),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: AppUIConstants.primaryLight,
              ),
            ),
          ),
      ],
    );
  }
}
