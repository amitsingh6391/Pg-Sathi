import 'package:flutter/material.dart';

import '../../../core/app_ui_constants.dart';

/// Header widget for selecting members with select all functionality.
class MemberSelectionHeader extends StatelessWidget {
  const MemberSelectionHeader({
    super.key,
    required this.isAllSelected,
    required this.selectedCount,
    required this.totalCount,
    required this.onToggleSelectAll,
  });

  final bool isAllSelected;
  final int selectedCount;
  final int totalCount;
  final VoidCallback onToggleSelectAll;

  bool get hasSelection => selectedCount > 0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppUIConstants.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onToggleSelectAll,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppUIConstants.border),
          ),
          child: Row(
            children: [
              SizedBox(
                height: 22,
                width: 22,
                child: Checkbox(
                  value: isAllSelected,
                  activeColor: AppUIConstants.primary,
                  onChanged: (_) => onToggleSelectAll(),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Select All Members',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: hasSelection
                      ? AppUIConstants.primary.withValues(alpha: 0.1)
                      : AppUIConstants.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$selectedCount / $totalCount',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: hasSelection
                        ? AppUIConstants.primary
                        : AppUIConstants.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
