import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pg_manager/presentation/core/app_ui_constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/notice.dart';
import '../../../domain/entities/library.dart';
import '../../../domain/repositories/library_repository.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../../domain/repositories/notice_repository.dart';
import '../widgets/notice_discussion_widget.dart';
import '../widgets/pdf_viewer_screen.dart';

/// Student Notice Details Screen - LinkedIn Style (No Tabs)
class StudentNoticeDetailsScreen extends StatefulWidget {
  const StudentNoticeDetailsScreen({
    super.key,
    required this.notice,
    required this.studentId,
    this.studentName,
    this.isOwnerView = false,
    this.onDelete,
  });

  final Notice notice;
  final String studentId;
  final String? studentName;
  final bool isOwnerView;
  final VoidCallback? onDelete;

  @override
  State<StudentNoticeDetailsScreen> createState() =>
      _StudentNoticeDetailsScreenState();
}

class _StudentNoticeDetailsScreenState
    extends State<StudentNoticeDetailsScreen> {
  Library? _library;
  String? _ownerName;
  late Stream<QuerySnapshot> _commentsStream;

  @override
  void initState() {
    super.initState();
    _loadLibraryInfo();
    _incrementViewCount();
    _commentsStream = FirebaseFirestore.instance
        .collection('notice_comments')
        .where('noticeId', isEqualTo: widget.notice.id)
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  Future<void> _incrementViewCount() async {
    try {
      final noticeRepo = sl<NoticeRepository>();
      await noticeRepo.incrementViewCount(
        noticeId: widget.notice.id,
        userId: widget.studentId,
      );
    } catch (e) {
      // Silent fail - view count is not critical
    }
  }

  Future<void> _loadLibraryInfo() async {
    try {
      final libraryRepo = sl<LibraryRepository>();
      final userRepo = sl<UserRepository>();

      // Fetch library information
      final libraryResult = await libraryRepo.getLibraryById(
        widget.notice.libraryId,
      );
      libraryResult.fold((_) {}, (lib) {
        if (lib != null && mounted) {
          setState(() {
            _library = lib;
          });
        }
      });

      // Fetch owner name as fallback
      final userResult = await userRepo.getUserById(widget.notice.ownerId);
      userResult.fold((_) {}, (user) {
        if (mounted) {
          setState(() {
            _ownerName = user.name;
          });
        }
      });
    } catch (e) {
      // Silent fail - library info is not critical
    }
  }

  String _getDisplayName() {
    if (_library != null && _library!.name.isNotEmpty) {
      return _library!.name;
    }
    if (_ownerName != null && _ownerName!.isNotEmpty) {
      return _ownerName!;
    }
    return 'Library Notice';
  }

  String _getLibraryInitials() {
    final name = _getDisplayName();
    if (name == 'Library Notice') {
      final id = widget.notice.libraryId;
      if (id.length >= 2) {
        return id.substring(id.length - 2).toUpperCase();
      }
      return id.toUpperCase();
    }
    final words = name.split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  Widget _buildLibraryAvatar() {
    if (_library != null && _library!.photos.isNotEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF0A66C2), width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.network(
            _library!.photos.first,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildInitialsAvatar(),
          ),
        ),
      );
    }
    return _buildInitialsAvatar();
  }

  Widget _buildInitialsAvatar() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF0A66C2),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          _getLibraryInitials(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
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

  void _handlePdfTap(BuildContext context, String url, String fileName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(pdfUrl: url, fileName: fileName),
      ),
    );
  }

  void _handleImageTap(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    String label;
    switch (widget.notice.status) {
      case NoticeStatus.published:
        color = const Color(0xFF057642);
        label = 'Published';
        break;
      case NoticeStatus.draft:
        color = Colors.grey.shade600;
        label = 'Draft';
        break;
      case NoticeStatus.scheduled:
        color = Colors.orange;
        label = 'Scheduled';
        break;
      case NoticeStatus.expired:
        color = Colors.red;
        label = 'Expired';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String count, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          count,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageAttachments = _getImageAttachments();
    final pdfAttachments = _getPdfAttachments();

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppUIConstants.primary,
            foregroundColor: Colors.white,
            expandedHeight: 70,
            pinned: true,
            centerTitle: false,
            title: const Text('Notice Details', style: TextStyle(fontSize: 18)),
            actions: widget.isOwnerView && widget.onDelete != null
                ? [
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Notice?'),
                            content: const Text(
                              'This action cannot be undone.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  widget.onDelete!();
                                },
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ]
                : null,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(color: AppUIConstants.primary),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section - Enhanced with Library Branding
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLibraryAvatar(),
                      const SizedBox(width: 16),
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
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                      height: 1.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.verified,
                                  size: 20,
                                  color: Color(0xFF0A66C2),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDate(widget.notice.publishedAt),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (widget.isOwnerView) ...[
                                  const SizedBox(width: 12),
                                  _buildStatusBadge(),
                                ],
                              ],
                            ),
                            if (widget.isOwnerView) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _buildStatChip(
                                    Icons.visibility_outlined,
                                    '${widget.notice.viewCount} views',
                                  ),
                                  const SizedBox(width: 8),
                                  _buildStatChip(
                                    Icons.people_outline,
                                    '${widget.notice.readCount} reads',
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Content Section - Enhanced
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.notice.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (widget.notice.description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          widget.notice.description,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade800,
                            height: 1.6,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Images Section
                if (imageAttachments.isNotEmpty) ...[
                  _buildImageSection(context, imageAttachments),
                  const SizedBox(height: 8),
                ],
                // PDFs and Links Section
                if (pdfAttachments.isNotEmpty ||
                    widget.notice.externalLinks.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attachments & Links',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...pdfAttachments.map(
                          (pdf) => _buildPdfChip(context, pdf),
                        ),
                        ...widget.notice.externalLinks.map(
                          (link) => _buildLinkChip(context, link),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Stats Bar (visible to both owner and student)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200),
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _commentsStream,
                    builder: (context, snapshot) {
                      final commentCount = snapshot.data?.docs.length ?? 0;
                      return Row(
                        children: [
                          _buildStatItem(
                            Icons.visibility_outlined,
                            '${widget.notice.viewCount}',
                            'Views',
                          ),
                          const SizedBox(width: 16),
                          _buildStatItem(
                            Icons.mode_comment_outlined,
                            '$commentCount',
                            'Comments',
                          ),
                          if (widget.isOwnerView) ...[
                            const SizedBox(width: 16),
                            _buildStatItem(
                              Icons.people_outline,
                              '${widget.notice.readCount}',
                              'Reads',
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade300),
                // Discussion Section
                SizedBox(
                  height: 600,
                  child: NoticeDiscussionWidget(
                    noticeId: widget.notice.id,
                    studentId: widget.studentId,
                    studentName: widget.studentName ?? 'Student',
                    commentsStream: _commentsStream,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection(
    BuildContext context,
    List<NoticeAttachment> images,
  ) {
    if (images.length == 1) {
      return InkWell(
        onTap: () => _handleImageTap(context, images[0].url),
        child: Image.network(
          images[0].url,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            height: 250,
            color: Colors.grey.shade200,
            child: const Icon(Icons.broken_image, size: 48),
          ),
        ),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      childAspectRatio: 1.0,
      children: images.map((img) {
        return InkWell(
          onTap: () => _handleImageTap(context, img.url),
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

  Widget _buildPdfChip(BuildContext context, NoticeAttachment pdf) {
    return InkWell(
      onTap: () => _handlePdfTap(context, pdf.url, pdf.fileName),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.picture_as_pdf, color: Colors.red.shade700, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pdf.fileName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    pdf.fileSizeFormatted,
                    style: TextStyle(fontSize: 12, color: Colors.red.shade600),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red.shade700),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkChip(BuildContext context, NoticeLink link) {
    return InkWell(
      onTap: () => _launchUrl(link.url),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.link, color: Colors.blue.shade700, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                link.title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(Icons.open_in_new, size: 16, color: Colors.blue.shade700),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Recently';
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m';
      }
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w';
    }
    return DateFormat('MMM d').format(date);
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
