import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/current_affair.dart';
import '../../core/app_ui_constants.dart';

/// Admin read-only detail screen for a current affair article.
/// Shows full content without student features (bookmarks, ads, translate).
class AdminArticleDetailScreen extends StatelessWidget {
  const AdminArticleDetailScreen({
    super.key,
    required this.item,
    required this.onDelete,
  });

  final CurrentAffair item;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildHeader(),
                const SizedBox(height: 20),
                _buildContent(),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppUIConstants.primary,
      foregroundColor: Colors.white,
      title: Text(
        item.categoryLabel,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 22),
          tooltip: 'Delete Article',
          onPressed: () => _confirmDelete(context),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Article'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              onDelete();
            },
            child: Text(
              'Delete',
              style: TextStyle(color: AppUIConstants.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category + created-by badge
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppUIConstants.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item.categoryLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppUIConstants.accent,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (item.createdBy != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _createdByColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _createdByLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _createdByColor,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),

        // Title
        Text(
          item.title,
          style: AppUIConstants.headingLg.copyWith(height: 1.3),
        ),
        const SizedBox(height: 12),

        // Meta row: date + source
        Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 14,
              color: AppUIConstants.textTertiary,
            ),
            const SizedBox(width: 6),
            Text(
              item.publishedAt != null
                  ? DateFormat('dd MMM yyyy, hh:mm a').format(item.publishedAt!)
                  : 'Draft',
              style: AppUIConstants.caption,
            ),
            if (item.source != null && item.source!.isNotEmpty) ...[
              const SizedBox(width: 16),
              Icon(
                Icons.source_rounded,
                size: 14,
                color: AppUIConstants.textTertiary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  item.source!,
                  style: AppUIConstants.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // Engagement stats
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppUIConstants.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.visibility_outlined,
                size: 16,
                color: AppUIConstants.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                '${item.viewCount} views',
                style: AppUIConstants.caption.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.favorite_rounded,
                size: 16,
                color: AppUIConstants.error,
              ),
              const SizedBox(width: 4),
              Text(
                '${item.likeCount} likes',
                style: AppUIConstants.caption.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        Divider(color: AppUIConstants.border, height: 1),
      ],
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary (highlighted)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppUIConstants.accent.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppUIConstants.accent.withValues(alpha: 0.15),
            ),
          ),
          child: Text(
            item.summary,
            style: AppUIConstants.bodyLg.copyWith(
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Full content
        SelectableText(
          item.content,
          style: TextStyle(
            fontSize: 15,
            height: 1.7,
            color: AppUIConstants.textPrimary,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String get _createdByLabel {
    final cb = item.createdBy ?? '';
    if (cb.contains('cloud_function')) return 'Auto (Scheduled)';
    if (cb.contains('admin_ai')) return 'AI On-Demand';
    if (cb.contains('app_fallback')) return 'AI Fallback';
    return 'Manual';
  }

  Color get _createdByColor {
    final cb = item.createdBy ?? '';
    if (cb.contains('cloud_function')) return Colors.blue;
    if (cb.contains('ai')) return const Color(0xFF8B5CF6);
    if (cb.contains('fallback')) return Colors.orange;
    return AppUIConstants.accent;
  }
}
