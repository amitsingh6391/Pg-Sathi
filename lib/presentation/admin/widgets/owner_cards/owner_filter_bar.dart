import 'package:flutter/material.dart';

import '../../../core/app_ui_constants.dart';

/// Filter and sort bar for owners list.
enum OwnerFilterType { all, withLibrary, withoutLibrary }

enum OwnerSortType { nameAsc, createdDateDesc, customPriceDesc }

class OwnerFilterBar extends StatelessWidget {
  const OwnerFilterBar({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.selectedSort,
    required this.onSortChanged,
    required this.onRefresh,
  });

  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final OwnerFilterType selectedFilter;
  final ValueChanged<OwnerFilterType> onFilterChanged;
  final OwnerSortType selectedSort;
  final ValueChanged<OwnerSortType> onSortChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppUIConstants.spacingMd),
      child: Column(
        children: [
          // Search bar with modern design
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppUIConstants.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppUIConstants.border.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    onChanged: onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search by name, phone, or email...',
                      hintStyle: TextStyle(
                        color: AppUIConstants.textSecondary.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: AppUIConstants.textSecondary,
                      ),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                size: 20,
                                color: AppUIConstants.textSecondary,
                              ),
                              onPressed: () => onSearchChanged(''),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppUIConstants.primary,
                      AppUIConstants.primary.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppUIConstants.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  onPressed: onRefresh,
                  tooltip: 'Refresh',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Filter and sort dropdowns
          Row(
            children: [
              Expanded(
                child: _FilterDropdown(
                  selectedFilter: selectedFilter,
                  onChanged: onFilterChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SortDropdown(
                  selectedSort: selectedSort,
                  onChanged: onSortChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Filter dropdown widget.
class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.selectedFilter,
    required this.onChanged,
  });

  final OwnerFilterType selectedFilter;
  final ValueChanged<OwnerFilterType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppUIConstants.background,
        border: Border.all(
          color: AppUIConstants.border.withValues(alpha: 0.5),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<OwnerFilterType>(
        value: selectedFilter,
        isExpanded: true,
        underline: const SizedBox(),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AppUIConstants.textSecondary,
        ),
        items: [
          DropdownMenuItem(
            value: OwnerFilterType.all,
            child: Row(
              children: [
                Icon(
                  Icons.list_rounded,
                  size: 16,
                  color: AppUIConstants.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'All Owners',
                  style: AppUIConstants.bodySm.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          DropdownMenuItem(
            value: OwnerFilterType.withLibrary,
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: AppUIConstants.success,
                ),
                const SizedBox(width: 8),
                Text(
                  'Active Libraries',
                  style: AppUIConstants.bodySm.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          DropdownMenuItem(
            value: OwnerFilterType.withoutLibrary,
            child: Row(
              children: [
                Icon(
                  Icons.pending_rounded,
                  size: 16,
                  color: AppUIConstants.warning,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pending Setup',
                  style: AppUIConstants.bodySm.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

/// Sort dropdown widget.
class _SortDropdown extends StatelessWidget {
  const _SortDropdown({
    required this.selectedSort,
    required this.onChanged,
  });

  final OwnerSortType selectedSort;
  final ValueChanged<OwnerSortType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppUIConstants.background,
        border: Border.all(
          color: AppUIConstants.border.withValues(alpha: 0.5),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<OwnerSortType>(
        value: selectedSort,
        isExpanded: true,
        underline: const SizedBox(),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AppUIConstants.textSecondary,
        ),
        items: [
          DropdownMenuItem(
            value: OwnerSortType.nameAsc,
            child: Row(
              children: [
                Icon(
                  Icons.sort_by_alpha_rounded,
                  size: 16,
                  color: AppUIConstants.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Name (A-Z)',
                  style: AppUIConstants.bodySm.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          DropdownMenuItem(
            value: OwnerSortType.createdDateDesc,
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: AppUIConstants.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Newest First',
                  style: AppUIConstants.bodySm.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          DropdownMenuItem(
            value: OwnerSortType.customPriceDesc,
            child: Row(
              children: [
                Icon(
                  Icons.star_rounded,
                  size: 16,
                  color: Colors.amber.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  'Custom Pricing',
                  style: AppUIConstants.bodySm.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

/// Stats display widget.
class OwnerStatsRow extends StatelessWidget {
  const OwnerStatsRow({
    super.key,
    required this.totalOwners,
    required this.withLibrary,
    required this.withoutLibrary,
    required this.withCustomPricing,
  });

  final int totalOwners;
  final int withLibrary;
  final int withoutLibrary;
  final int withCustomPricing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppUIConstants.spacingMd,
        vertical: AppUIConstants.spacingSm,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppUIConstants.primary.withValues(alpha: 0.08),
            AppUIConstants.primary.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppUIConstants.primary.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
              label: 'Total',
              value: totalOwners.toString(),
              icon: Icons.people_rounded,
              color: AppUIConstants.primary,
            ),
            Container(
              width: 1,
              height: 40,
              color: AppUIConstants.border.withValues(alpha: 0.3),
            ),
            _StatItem(
              label: 'Active',
              value: withLibrary.toString(),
              icon: Icons.check_circle_rounded,
              color: AppUIConstants.success,
            ),
            Container(
              width: 1,
              height: 40,
              color: AppUIConstants.border.withValues(alpha: 0.3),
            ),
            _StatItem(
              label: 'Pending',
              value: withoutLibrary.toString(),
              icon: Icons.pending_rounded,
              color: AppUIConstants.warning,
            ),
            Container(
              width: 1,
              height: 40,
              color: AppUIConstants.border.withValues(alpha: 0.3),
            ),
            _StatItem(
              label: 'Custom',
              value: withCustomPricing.toString(),
              icon: Icons.star_rounded,
              color: Colors.amber.shade700,
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual stat item.
class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: AppUIConstants.bodyMd.copyWith(
            fontWeight: FontWeight.w700,
            color: AppUIConstants.textPrimary,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppUIConstants.caption.copyWith(
            color: AppUIConstants.textSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
