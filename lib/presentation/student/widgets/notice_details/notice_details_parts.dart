import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../../../../domain/entities/library.dart';
import '../../../core/app_ui_constants.dart';
import '../fullscreen_image_viewer.dart';

/// Library avatar, name and posted time.
class NoticeAuthorHeader extends StatelessWidget {
  const NoticeAuthorHeader({
    super.key,
    required this.name,
    required this.postedAt,
    this.library,
  });

  final String name;
  final DateTime postedAt;
  final Library? library;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppUIConstants.primary,
          child: Text(
            _initials(name),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppUIConstants.spacingMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppUIConstants.bodyLg.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('d MMM yyyy, h:mm a').format(postedAt),
                style: AppUIConstants.bodySm,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    if (words.length >= 2) return '${words[0][0]}${words[1][0]}'.toUpperCase();
    return words.first
        .substring(0, words.first.length >= 2 ? 2 : 1)
        .toUpperCase();
  }
}

/// White rounded section with an optional title.
class NoticeSectionCard extends StatelessWidget {
  const NoticeSectionCard({super.key, required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppUIConstants.spacingLg,
        0,
        AppUIConstants.spacingLg,
        AppUIConstants.spacingMd,
      ),
      padding: const EdgeInsets.all(AppUIConstants.spacingLg),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: AppUIConstants.headingSm),
            const SizedBox(height: AppUIConstants.spacingMd),
          ],
          child,
        ],
      ),
    );
  }
}

/// Rounded image grid that opens the fullscreen viewer.
class NoticeImageGallery extends StatelessWidget {
  const NoticeImageGallery({super.key, required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    Widget tile(int i) => GestureDetector(
      onTap: () =>
          FullScreenImageViewer.open(context, images: urls, initialIndex: i),
      child: Image.network(
        urls[i],
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: AppUIConstants.divider,
          child: const Icon(
            Icons.broken_image_outlined,
            color: AppUIConstants.textTertiary,
          ),
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
      child: urls.length == 1
          ? AspectRatio(aspectRatio: 4 / 3, child: tile(0))
          : GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              children: [for (var i = 0; i < urls.length; i++) tile(i)],
            ),
    );
  }
}

/// Tappable row for a PDF or link.
class NoticeFileTile extends StatelessWidget {
  const NoticeFileTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing = Icons.chevron_right_rounded,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final IconData trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppUIConstants.spacingSm),
      child: Material(
        color: AppUIConstants.background,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(AppUIConstants.spacingMd),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusSm,
                    ),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: AppUIConstants.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppUIConstants.bodyMd.copyWith(
                          color: AppUIConstants.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null)
                        Text(subtitle!, style: AppUIConstants.bodySm),
                    ],
                  ),
                ),
                Icon(trailing, size: 20, color: AppUIConstants.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
