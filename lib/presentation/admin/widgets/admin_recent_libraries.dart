import 'package:material_ui/material_ui.dart';

import '../../../domain/entities/library_summary.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';

/// Recently onboarded PGs for the admin console.
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
        PremiumSectionHeader(
          'Recent PGs',
          action: 'View all',
          onAction: onViewAll,
        ),
        if (recent.isEmpty)
          PremiumCard(
            child: Column(
              children: [
                Icon(
                  Icons.apartment_rounded,
                  size: 32,
                  color: AppUIConstants.textTertiary,
                ),
                const SizedBox(height: 8),
                Text('No PGs onboarded yet', style: AppUIConstants.bodyMd),
              ],
            ),
          )
        else
          PremiumCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < recent.length; i++) ...[
                  _RecentLibraryTile(library: recent[i], onTap: onViewAll),
                  if (i != recent.length - 1)
                    Divider(
                      height: 1,
                      color: AppUIConstants.divider,
                      indent: 68,
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _RecentLibraryTile extends StatelessWidget {
  const _RecentLibraryTile({required this.library, required this.onTap});

  final LibrarySummary library;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final occ = library.occupancyPercent;
    final occColor = _getOccupancyColor(occ);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppUIConstants.surfaceMuted,
                borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
              ),
              alignment: Alignment.center,
              child: Text(
                library.libraryName.isNotEmpty
                    ? library.libraryName[0].toUpperCase()
                    : 'P',
                style: const TextStyle(
                  color: AppUIConstants.primaryLight,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    library.libraryName,
                    style: AppUIConstants.bodyLg,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      library.ownerName,
                      if ((library.area ?? '').isNotEmpty) library.area!,
                    ].join(' \u2022 '),
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
                PremiumStatusPill(library.formattedOccupancy, color: occColor),
                const SizedBox(height: 4),
                Text(
                  '${library.totalSeats} beds',
                  style: AppUIConstants.caption,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getOccupancyColor(double percent) {
    if (percent >= 80) return AppUIConstants.success;
    if (percent >= 50) return AppUIConstants.primaryLight;
    if (percent >= 25) return AppUIConstants.warning;
    return AppUIConstants.textTertiary;
  }
}
