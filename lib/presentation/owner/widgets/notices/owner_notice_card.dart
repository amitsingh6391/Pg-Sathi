import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../../../../domain/entities/notice.dart';
import '../../../core/app_ui_constants.dart';
import 'notice_attachments_view.dart';
import 'notice_card_parts.dart';

enum _CardAction { view, delete }

/// Owner-facing notice card with status, reach stats and an overflow menu.
class OwnerNoticeCard extends StatefulWidget {
  const OwnerNoticeCard({
    super.key,
    required this.notice,
    required this.onTap,
    required this.onDelete,
  });

  final Notice notice;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<OwnerNoticeCard> createState() => _OwnerNoticeCardState();
}

class _OwnerNoticeCardState extends State<OwnerNoticeCard> {
  static const _previewLength = 180;
  bool _expanded = false;

  Notice get _notice => widget.notice;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppUIConstants.spacingLg,
        0,
        AppUIConstants.spacingLg,
        AppUIConstants.spacingMd,
      ),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
        border: Border.all(color: AppUIConstants.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppUIConstants.spacingLg,
                  AppUIConstants.spacingMd,
                  AppUIConstants.spacingXs,
                  AppUIConstants.spacingLg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    Padding(
                      padding: const EdgeInsets.only(
                        right: AppUIConstants.spacingMd,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppUIConstants.spacingSm),
                          _buildDescription(),
                          NoticeAttachmentsView(notice: _notice),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final (label, color) = _statusStyle();
    return Row(
      children: [
        Pill(label: label, color: color, dot: true),
        const Spacer(),
        Text(_relativeTime(), style: AppUIConstants.bodySm),
        PopupMenuButton<_CardAction>(
          icon: const Icon(
            Icons.more_vert_rounded,
            size: 20,
            color: AppUIConstants.textTertiary,
          ),
          tooltip: 'More',
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          ),
          onSelected: (action) =>
              action == _CardAction.view ? widget.onTap() : widget.onDelete(),
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: _CardAction.view,
              child: MenuRow(
                icon: Icons.open_in_new_rounded,
                label: 'View details',
              ),
            ),
            PopupMenuItem(
              value: _CardAction.delete,
              child: MenuRow(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                color: AppUIConstants.error,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDescription() {
    final text = _notice.description;
    final truncate = !_expanded && text.length > _previewLength;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          truncate ? '${text.substring(0, _previewLength).trimRight()}…' : text,
          style: AppUIConstants.bodyMd.copyWith(
            color: AppUIConstants.textPrimary,
            height: 1.5,
          ),
        ),
        if (truncate)
          GestureDetector(
            onTap: () => setState(() => _expanded = true),
            child: Padding(
              padding: const EdgeInsets.only(top: AppUIConstants.spacingXs),
              child: Text(
                'Read more',
                style: AppUIConstants.bodySm.copyWith(
                  color: AppUIConstants.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFooter() {
    final timing = _timingNote();
    final isScheduled = _notice.status == NoticeStatus.scheduled;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppUIConstants.spacingLg,
        AppUIConstants.spacingMd,
        AppUIConstants.spacingMd,
        AppUIConstants.spacingMd,
      ),
      decoration: const BoxDecoration(
        color: AppUIConstants.background,
        border: Border(top: BorderSide(color: AppUIConstants.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: AppUIConstants.spacingSm,
              runSpacing: AppUIConstants.spacingSm,
              children: [
                MetaChip(
                  icon: Icons.groups_outlined,
                  label: _notice.targetAudienceDescription,
                ),
                if (timing != null)
                  MetaChip(
                    icon: isScheduled
                        ? Icons.schedule_rounded
                        : Icons.event_outlined,
                    label: timing,
                    color: isScheduled ? AppUIConstants.warning : null,
                  ),
                if (_notice.sendWhatsApp)
                  const MetaChip(
                    icon: Icons.chat_outlined,
                    label: 'WhatsApp',
                    color: AppUIConstants.success,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppUIConstants.spacingSm),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Details',
                style: AppUIConstants.bodySm.copyWith(
                  color: AppUIConstants.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppUIConstants.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  (String, Color) _statusStyle() {
    switch (_notice.status) {
      case NoticeStatus.published:
        return _notice.isExpired
            ? ('Expired', AppUIConstants.textTertiary)
            : ('Live', AppUIConstants.success);
      case NoticeStatus.scheduled:
        return ('Scheduled', AppUIConstants.warning);
      case NoticeStatus.draft:
        return ('Draft', AppUIConstants.secondary);
      case NoticeStatus.expired:
        return ('Expired', AppUIConstants.textTertiary);
    }
  }

  String? _timingNote() {
    final fmt = DateFormat('d MMM, h:mm a');
    if (_notice.status == NoticeStatus.scheduled &&
        _notice.scheduledFor != null) {
      return 'Goes live ${fmt.format(_notice.scheduledFor!)}';
    }
    final expires = _notice.expiresAt;
    if (expires == null) return null;
    return _notice.isExpired
        ? 'Ended ${DateFormat('d MMM').format(expires)}'
        : 'Ends ${DateFormat('d MMM').format(expires)}';
  }

  String _relativeTime() {
    final date = _notice.publishedAt ?? _notice.createdAt;
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM').format(date);
  }
}
