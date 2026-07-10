import 'package:flutter/material.dart';

import '../../../domain/entities/library_summary.dart';
import '../../core/app_ui_constants.dart';

/// Recent libraries section for admin dashboard.
class AdminRecentLibraries extends StatelessWidget {
  const AdminRecentLibraries({
    super.key,
    required this.libraries,
    required this.onViewAll,
  });

  final List<LibrarySummary> libraries;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final recent = libraries.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Recent Libraries', style: AppUIConstants.headingSm),
            const Spacer(),
            TextButton(onPressed: onViewAll, child: const Text('View All')),
          ],
        ),
        const SizedBox(height: AppUIConstants.spacingSm),
        if (recent.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppUIConstants.spacingLg),
            decoration: AppUIConstants.cardDecoration,
            child: Center(
              child: Text(
                'No libraries yet',
                style: AppUIConstants.bodyMd.copyWith(
                  color: AppUIConstants.textTertiary,
                ),
              ),
            ),
          )
        else
          Container(
            decoration: AppUIConstants.cardDecoration,
            child: Column(
              children: recent.asMap().entries.map((entry) {
                final library = entry.value;
                final isLast = entry.key == recent.length - 1;
                return _RecentLibraryTile(
                  library: library,
                  showDivider: !isLast,
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _RecentLibraryTile extends StatelessWidget {
  const _RecentLibraryTile({required this.library, this.showDivider = true});

  final LibrarySummary library;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppUIConstants.spacingMd),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppUIConstants.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
                ),
                child: Center(
                  child: Text(
                    library.libraryName.isNotEmpty
                        ? library.libraryName[0].toUpperCase()
                        : 'L',
                    style: TextStyle(
                      color: AppUIConstants.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppUIConstants.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      library.libraryName,
                      style: AppUIConstants.bodyMd.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${library.ownerName} • ${library.area ?? ""}',
                      style: AppUIConstants.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    library.formattedOccupancy,
                    style: AppUIConstants.bodySm.copyWith(
                      color: _getOccupancyColor(library.occupancyPercent),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${library.totalSeats} seats',
                    style: AppUIConstants.caption,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: AppUIConstants.divider,
            indent: AppUIConstants.spacingMd,
            endIndent: AppUIConstants.spacingMd,
          ),
      ],
    );
  }

  Color _getOccupancyColor(double percent) {
    if (percent >= 80) return AppUIConstants.success;
    if (percent >= 50) return AppUIConstants.accent;
    if (percent >= 25) return AppUIConstants.warning;
    return AppUIConstants.textTertiary;
  }
}
