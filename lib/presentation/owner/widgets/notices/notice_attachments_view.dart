import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../domain/entities/notice.dart';
import '../../../core/app_ui_constants.dart';

/// Images, PDFs and links attached to a notice.
class NoticeAttachmentsView extends StatelessWidget {
  const NoticeAttachmentsView({super.key, required this.notice});

  final Notice notice;

  @override
  Widget build(BuildContext context) {
    final images = notice.attachments
        .where((a) => a.fileType == AttachmentType.image)
        .toList();
    final pdfs = notice.attachments
        .where((a) => a.fileType == AttachmentType.pdf)
        .toList();
    final links = notice.externalLinks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty) ...[
          const SizedBox(height: AppUIConstants.spacingMd),
          _ImageGrid(images: images),
        ],
        if (pdfs.isNotEmpty || links.isNotEmpty) ...[
          const SizedBox(height: AppUIConstants.spacingMd),
          Wrap(
            spacing: AppUIConstants.spacingSm,
            runSpacing: AppUIConstants.spacingSm,
            children: [
              ...pdfs.map(
                (pdf) => _FileChip(
                  icon: Icons.picture_as_pdf_outlined,
                  label: pdf.fileName,
                  color: AppUIConstants.error,
                  onTap: () => _launch(pdf.url),
                ),
              ),
              ...links.map(
                (link) => _FileChip(
                  icon: Icons.link_rounded,
                  label: link.title,
                  color: AppUIConstants.accent,
                  onTap: () => _launch(link.url),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

Future<void> _launch(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _ImageGrid extends StatelessWidget {
  const _ImageGrid({required this.images});

  final List<NoticeAttachment> images;

  @override
  Widget build(BuildContext context) {
    final shown = images.take(4).toList();
    final extra = images.length - shown.length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
      child: shown.length == 1
          ? AspectRatio(
              aspectRatio: 16 / 9,
              child: _tile(context, shown.first.url),
            )
          : GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.4,
              children: [
                for (var i = 0; i < shown.length; i++)
                  Stack(
                    fit: StackFit.expand,
                    children: [
                      _tile(context, shown[i].url),
                      if (extra > 0 && i == shown.length - 1)
                        IgnorePointer(
                          child: Container(
                            color: Colors.black54,
                            alignment: Alignment.center,
                            child: Text(
                              '+$extra',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
    );
  }

  Widget _tile(BuildContext context, String url) {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => Dialog(
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
      child: Image.network(
        url,
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
  }
}

class _FileChip extends StatelessWidget {
  const _FileChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
