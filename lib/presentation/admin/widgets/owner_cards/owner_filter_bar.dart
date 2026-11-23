import 'package:material_ui/material_ui.dart';

import '../../../core/app_ui_constants.dart';

/// Filter and sort bar for owners list.
enum OwnerFilterType { all, withLibrary, withoutLibrary }

enum OwnerSortType { nameAsc, createdDateDesc, customPriceDesc }

String _sortLabel(OwnerSortType s) {
  switch (s) {
    case OwnerSortType.nameAsc:
      return 'Name (A-Z)';
    case OwnerSortType.createdDateDesc:
      return 'Newest First';
    case OwnerSortType.customPriceDesc:
      return 'Custom Pricing';
  }
}

IconData _sortIcon(OwnerSortType s) {
  switch (s) {
    case OwnerSortType.nameAsc:
      return Icons.sort_by_alpha_rounded;
    case OwnerSortType.createdDateDesc:
      return Icons.schedule_rounded;
    case OwnerSortType.customPriceDesc:
      return Icons.star_rounded;
  }
}

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

  void _openSortSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppUIConstants.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppUIConstants.radiusXl),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppUIConstants.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Sort owners by', style: AppUIConstants.headingSm),
              const SizedBox(height: 8),
              for (final s in OwnerSortType.values)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Icon(
                    _sortIcon(s),
                    color: s == selectedSort
                        ? AppUIConstants.primaryLight
                        : AppUIConstants.textSecondary,
                  ),
                  title: Text(
                    _sortLabel(s),
                    style: AppUIConstants.bodyMd.copyWith(
                      color: s == selectedSort
                          ? AppUIConstants.primaryLight
                          : AppUIConstants.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: s == selectedSort
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppUIConstants.primaryLight,
                        )
                      : null,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onSortChanged(s);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppUIConstants.background,
        border: Border(bottom: BorderSide(color: AppUIConstants.divider)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppUIConstants.surface,
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusMd,
                    ),
                    border: Border.all(color: AppUIConstants.border),
                  ),
                  child: TextField(
                    onChanged: onSearchChanged,
                    style: AppUIConstants.bodyMd,
                    cursorColor: AppUIConstants.primaryLight,
                    decoration: InputDecoration(
                      hintText: 'Search name, phone or email',
                      hintStyle: AppUIConstants.bodySm.copyWith(
                        color: AppUIConstants.textTertiary,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: AppUIConstants.textTertiary,
                      ),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: AppUIConstants.textSecondary,
                              ),
                              onPressed: () => onSearchChanged(''),
                            )
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SquareIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh',
                onTap: onRefresh,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All Owners',
                        icon: Icons.groups_rounded,
                        color: AppUIConstants.primaryLight,
                        selected: selectedFilter == OwnerFilterType.all,
                        onTap: () => onFilterChanged(OwnerFilterType.all),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Active PGs',
                        icon: Icons.check_circle_rounded,
                        color: AppUIConstants.primaryLight,
                        selected: selectedFilter == OwnerFilterType.withLibrary,
                        onTap: () =>
                            onFilterChanged(OwnerFilterType.withLibrary),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Pending Setup',
                        icon: Icons.hourglass_bottom_rounded,
                        color: AppUIConstants.primaryLight,
                        selected:
                            selectedFilter == OwnerFilterType.withoutLibrary,
                        onTap: () =>
                            onFilterChanged(OwnerFilterType.withoutLibrary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _openSortSheet(context),
                borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _sortIcon(selectedSort),
                        size: 16,
                        color: AppUIConstants.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.unfold_more_rounded,
                        size: 16,
                        color: AppUIConstants.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppUIConstants.primarySoft,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, color: AppUIConstants.primaryLight),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected
            ? color.withValues(alpha: 0.16)
            : AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
        border: Border.all(
          color: selected
              ? color.withValues(alpha: 0.6)
              : AppUIConstants.border,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: selected ? color : AppUIConstants.textTertiary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? color : AppUIConstants.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Summary strip of owner counts.
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
    final items = [
      _StatItem(
        'Total',
        totalOwners,
        Icons.groups_rounded,
        AppUIConstants.textSecondary,
      ),
      _StatItem(
        'Active',
        withLibrary,
        Icons.check_circle_rounded,
        AppUIConstants.textSecondary,
      ),
      _StatItem(
        'Pending',
        withoutLibrary,
        Icons.hourglass_bottom_rounded,
        AppUIConstants.textSecondary,
      ),
      _StatItem(
        'Custom',
        withCustomPricing,
        Icons.star_rounded,
        AppUIConstants.textSecondary,
      ),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        border: Border.all(color: AppUIConstants.border),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(width: 1, height: 32, color: AppUIConstants.border),
            Expanded(child: items[i]),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem(this.label, this.value, this.icon, this.color);

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: AppUIConstants.statValue.copyWith(
            color: AppUIConstants.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppUIConstants.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
