import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/notice.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/student_notice_cubit.dart';
import 'student_notice_details_screen.dart';

class StudentNoticesScreen extends StatelessWidget {
  const StudentNoticesScreen({
    super.key,
    required this.libraryIds,
    required this.studentId,
  });

  final List<String> libraryIds;
  final String studentId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<StudentNoticeCubit>()
        ..loadNoticesFromMultipleLibraries(
          libraryIds: libraryIds,
          studentId: studentId,
        ),
      child: _StudentNoticesView(studentId: studentId, libraryIds: libraryIds),
    );
  }
}

class _StudentNoticesView extends StatelessWidget {
  const _StudentNoticesView({
    required this.studentId,
    required this.libraryIds,
  });

  final String studentId;
  final List<String> libraryIds;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 80,
              floating: false,
              pinned: true,
              centerTitle: false,
              backgroundColor: AppUIConstants.primary,
              title: const Text(
                'Notices',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              actions: [
                BlocBuilder<StudentNoticeCubit, StudentNoticeState>(
                  builder: (context, state) {
                    final unreadCount = state.unreadNotices.length;
                    if (unreadCount == 0) return const SizedBox(width: 48);
                    return Container(
                      margin: const EdgeInsets.only(right: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$unreadCount new',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ];
        },
        body: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return BlocConsumer<StudentNoticeCubit, StudentNoticeState>(
      listener: (context, state) {
        if (state.status == StudentNoticeStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage ?? 'Error occurred')),
          );
        }
      },
      builder: (context, state) {
        if (state.status == StudentNoticeStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        final allNotices = [...state.unreadNotices, ...state.readNotices];

        if (allNotices.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_none_outlined,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'No notices yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You\'ll see important updates here',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            context.read<StudentNoticeCubit>().refreshMultipleLibraries(
              libraryIds: libraryIds,
              studentId: studentId,
            );
          },
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount:
                allNotices.length + (allNotices.length ~/ 2), // Add ad slots
            itemBuilder: (context, index) {
              // Insert native ad after every 2 notices
              // Ads at positions: 2, 5, 8, 11... (after every 2 items)
              final adIndex = index ~/ 3;
              final isAdPosition =
                  (index + 1) % 3 == 0 && adIndex < (allNotices.length ~/ 2);

              if (isAdPosition) {
              }

              // Calculate actual notice index (accounting for ads)
              final noticeIndex = index - adIndex;
              if (noticeIndex >= allNotices.length) {
                return const SizedBox.shrink();
              }

              final notice = allNotices[noticeIndex];
              final isUnread = state.unreadNotices.contains(notice);
              final libInfo = state.libraryInfoCache[notice.libraryId];
              return _NoticeCard(
                notice: notice,
                isUnread: isUnread,
                onTap: () => _openDetails(context, notice),
                onAttachmentTap: (url) => _openAttachment(context, url),
                onLinkTap: _openLink,
                libraryName: libInfo?.libraryName,
                ownerName: libInfo?.ownerName,
              );
            },
          ),
        );
      },
    );
  }

  void _openDetails(BuildContext context, Notice notice) {
    context.read<StudentNoticeCubit>().markAsRead(
      noticeId: notice.id,
      studentId: studentId,
      libraryId: notice.libraryId,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            StudentNoticeDetailsScreen(notice: notice, studentId: studentId),
      ),
    );
  }

  void _openAttachment(BuildContext context, String url) async {
    // Check if it's an image - extract path before query params
    final uri = Uri.parse(url);
    final path = uri.path.toLowerCase();
    final isImage =
        path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.gif');

    if (isImage) {
      // Show image in dialog
      showDialog(
        context: context,
        builder: (_) => Dialog(
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      );
    } else {
      // Open PDF or other files in external app
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _NoticeCard extends StatefulWidget {
  const _NoticeCard({
    required this.notice,
    required this.isUnread,
    required this.onTap,
    required this.onAttachmentTap,
    required this.onLinkTap,
    this.libraryName,
    this.ownerName,
  });

  final Notice notice;
  final bool isUnread;
  final VoidCallback onTap;
  final void Function(String url) onAttachmentTap;
  final void Function(String url) onLinkTap;

  /// Pre-fetched from cubit cache — avoids per-card Firestore reads.
  final String? libraryName;
  final String? ownerName;

  @override
  State<_NoticeCard> createState() => _NoticeCardState();
}

class _NoticeCardState extends State<_NoticeCard> {
  bool _isExpanded = false;

  String _getDisplayName() {
    if (widget.libraryName != null && widget.libraryName!.isNotEmpty) {
      return widget.libraryName!;
    }
    if (widget.ownerName != null && widget.ownerName!.isNotEmpty) {
      return widget.ownerName!;
    }
    return 'Library Notice';
  }

  String _getLibraryInitials() {
    final name = _getDisplayName();
    if (name == 'Library Notice') {
      // Extract last 2 characters from library ID for initials
      final id = widget.notice.libraryId;
      if (id.length >= 2) {
        return id.substring(id.length - 2).toUpperCase();
      }
      return id.toUpperCase();
    }
    // Get first 2 characters of each word or first 2 chars
    final words = name.split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  Widget _buildLibraryAvatar() {
    // Initials-only avatar — library photos are not prefetched
    // to keep the batch read lightweight.
    return _buildInitialsAvatar();
  }

  Widget _buildInitialsAvatar() {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFF0A66C2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _getLibraryInitials(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  List<NoticeAttachment> _getImageAttachments() {
    return widget.notice.attachments
        .where((a) => a.fileType == AttachmentType.image)
        .toList();
  }

  List<NoticeAttachment> _getPdfAttachments() {
    return widget.notice.attachments
        .where((a) => a.fileType == AttachmentType.pdf)
        .toList();
  }

  Widget _buildImageSection(List<NoticeAttachment> images) {
    if (images.length == 1) {
      return InkWell(
        onTap: () => widget.onAttachmentTap(images[0].url),
        child: Image.network(
          images[0].url,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            height: 200,
            color: Colors.grey.shade200,
            child: const Icon(Icons.broken_image, size: 48),
          ),
        ),
      );
    }

    // Multiple images - show grid
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: images.length == 2 ? 2 : 2,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      childAspectRatio: 1.5,
      children: images.take(4).map((img) {
        return InkWell(
          onTap: () => widget.onAttachmentTap(img.url),
          child: Image.network(
            img.url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              color: Colors.grey.shade200,
              child: const Icon(Icons.broken_image),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isUnread
              ? const Color(0xFF0A66C2).withValues(alpha: 0.2)
              : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: widget.onTap,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header with Library Initials
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLibraryAvatar(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _getDisplayName(),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF000000),
                                        letterSpacing: -0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.verified,
                                    size: 16,
                                    color: Color(0xFF0A66C2),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatDate(widget.notice.publishedAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.isUnread)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFF0A66C2),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Post Content with expandable text
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF000000),
                          height: 1.5,
                        ),
                        children: [
                          TextSpan(text: '${widget.notice.title}\n'),
                          if (widget.notice.description.isNotEmpty)
                            TextSpan(
                              text:
                                  _isExpanded ||
                                      widget.notice.description.length <= 200
                                  ? widget.notice.description
                                  : '${widget.notice.description.substring(0, 200)}...',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                        ],
                      ),
                    ),
                    if (widget.notice.description.length > 200 && !_isExpanded)
                      GestureDetector(
                        onTap: () => setState(() => _isExpanded = true),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '...more',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Show images inline (like LinkedIn)
            if (_getImageAttachments().isNotEmpty)
              _buildImageSection(_getImageAttachments()),
            // PDF attachments and links (shown as chips)
            if (_getPdfAttachments().isNotEmpty ||
                widget.notice.externalLinks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ..._getPdfAttachments().map(
                      (pdf) => InkWell(
                        onTap: () => widget.onAttachmentTap(pdf.url),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.picture_as_pdf,
                                size: 16,
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                pdf.fileName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    ...widget.notice.externalLinks.map(
                      (link) => InkWell(
                        onTap: () => widget.onLinkTap(link.url),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.link,
                                size: 16,
                                color: Colors.grey.shade700,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                link.title,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.grey.shade200),
            // LinkedIn-style interaction bar with comment count and view count
            Row(
              children: [
                Expanded(
                  child: _buildInteractionButton(
                    icon: Icons.mode_comment_outlined,
                    label: widget.notice.commentCount > 0
                        ? '${widget.notice.commentCount}'
                        : 'Comment',
                    onTap: widget.onTap,
                  ),
                ),
                Container(width: 1, height: 20, color: Colors.grey.shade300),
                Expanded(
                  child: _buildInteractionButton(
                    icon: Icons.visibility_outlined,
                    label: '${widget.notice.viewCount}',
                    onTap: null, // View count is non-interactive
                  ),
                ),
                if (widget.notice.attachments.isNotEmpty ||
                    widget.notice.externalLinks.isNotEmpty) ...[
                  Container(width: 1, height: 20, color: Colors.grey.shade300),
                  Expanded(
                    child: _buildInteractionButton(
                      icon: Icons.attach_file_rounded,
                      label:
                          '${widget.notice.attachments.length + widget.notice.externalLinks.length}',
                      onTap: widget.onTap,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return child;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: child,
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }
}
