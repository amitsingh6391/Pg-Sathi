import 'package:flutter/material.dart';

import '../../core/app_ui_constants.dart';

// =============================================================================
// QUICK ACTIONS GRID - ALL VISIBLE, NO SCROLL
// =============================================================================

/// Quick actions grid - ALL actions visible at once, no scrolling.
class QuickActionsGridView extends StatelessWidget {
  const QuickActionsGridView({super.key, required this.actions});

  final List<QuickActionItem> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header - Dark and visible
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppUIConstants.textPrimary,
          ),
        ),
        const SizedBox(height: AppUIConstants.spacingMd),

        // 3-Column Grid - Compact cards
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.15,
          children: actions.map((a) => _QuickActionTile(action: a)).toList(),
        ),
      ],
    );
  }
}

/// Model for quick action item.
class QuickActionItem {
  const QuickActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge,
    this.isLocked = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final dynamic badge;
  final bool isLocked;
}

/// Individual action tile - Clear, tappable.
class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final QuickActionItem action;

  @override
  Widget build(BuildContext context) {
    final isLocked = action.isLocked;
    final color = isLocked ? AppUIConstants.disabled : action.color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: AppUIConstants.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isLocked
                  ? AppUIConstants.border
                  : color.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isLocked ? 0.02 : 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with badge/lock
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(action.icon, color: color, size: 22),
                  ),
                  if (action.badge != null &&
                      (action.badge is String ||
                          (action.badge is int && action.badge > 0)))
                    Positioned(
                      top: -5,
                      right: -5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: action.badge is String
                              ? const Color(0xFF8B5CF6)
                              : AppUIConstants.error,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${action.badge}',
                          style: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  if (isLocked)
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppUIConstants.warning,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: const Icon(
                          Icons.lock,
                          size: 7,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              // Label
              Text(
                action.label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isLocked
                      ? AppUIConstants.textTertiary
                      : AppUIConstants.textPrimary,
                  height: 1.15,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// LIBRARY PHOTOS SECTION - BOTTOM (Personal Touch)
// =============================================================================

/// PG photos section at bottom - personal branding touch.
class LibraryPhotosSection extends StatelessWidget {
  const LibraryPhotosSection({
    super.key,
    required this.libraryName,
    required this.photos,
    this.onPreviewTap,
  });

  final String libraryName;
  final List<String> photos;
  final VoidCallback? onPreviewTap;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return _EmptyPhotosCard(onAddPhotos: onPreviewTap);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: AppUIConstants.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Your PG',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppUIConstants.textPrimary,
              ),
            ),
            const Spacer(),
            if (onPreviewTap != null)
              TextButton.icon(
                onPressed: onPreviewTap,
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Preview'),
                style: TextButton.styleFrom(
                  foregroundColor: AppUIConstants.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Photos Grid
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppUIConstants.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPreviewTap,
            child: photos.length == 1
                ? _SinglePhoto(url: photos.first, name: libraryName)
                : _PhotoGrid(photos: photos, name: libraryName),
          ),
        ),
      ],
    );
  }
}

class _SinglePhoto extends StatelessWidget {
  const _SinglePhoto({required this.url, required this.name});

  final String url;
  final String name;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Container(
                color: AppUIConstants.background,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
            errorBuilder: (_, _, _) => Container(
              color: AppUIConstants.background,
              child: Icon(
                Icons.image_not_supported,
                color: AppUIConstants.textTertiary,
              ),
            ),
          ),
          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.6),
                ],
              ),
            ),
          ),
          // Name
          Positioned(
            left: 16,
            bottom: 12,
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.photos, required this.name});

  final List<String> photos;
  final String name;

  @override
  Widget build(BuildContext context) {
    final displayPhotos = photos.take(4).toList();
    final moreCount = photos.length - 4;

    return SizedBox(
      height: 140,
      child: Row(
        children: [
          // Main photo
          Expanded(
            flex: 2,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  displayPhotos.first,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      Container(color: AppUIConstants.background),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 10,
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Side photos
          if (displayPhotos.length > 1)
            Expanded(
              child: Column(
                children: [
                  for (int i = 1; i < displayPhotos.length && i < 4; i++)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: AppUIConstants.border,
                              width: 1,
                            ),
                            top: i > 1
                                ? BorderSide(
                                    color: AppUIConstants.border,
                                    width: 1,
                                  )
                                : BorderSide.none,
                          ),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              displayPhotos[i],
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  Container(color: AppUIConstants.background),
                            ),
                            if (i == 3 && moreCount > 0)
                              Container(
                                color: Colors.black.withValues(alpha: 0.5),
                                child: Center(
                                  child: Text(
                                    '+$moreCount',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyPhotosCard extends StatelessWidget {
  const _EmptyPhotosCard({this.onAddPhotos});

  final VoidCallback? onAddPhotos;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: AppUIConstants.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Your PG',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppUIConstants.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: onAddPhotos,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: AppUIConstants.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppUIConstants.border,
                style: BorderStyle.solid,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppUIConstants.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.add_photo_alternate_outlined,
                    color: AppUIConstants.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add PG Photos',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppUIConstants.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Make your PG stand out to tenants',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppUIConstants.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppUIConstants.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
