import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/notice.dart';
import '../../../domain/entities/library.dart';
import '../../../domain/repositories/library_repository.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/owner_notice_cubit.dart';
import 'create_notice_screen.dart';
import '../../student/screens/student_notice_details_screen.dart';

class OwnerNoticesScreen extends StatelessWidget {
  const OwnerNoticesScreen({
    super.key,
    required this.libraryId,
    required this.ownerId,
  });

  final String libraryId;
  final String ownerId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<OwnerNoticeCubit>()..loadNotices(libraryId),
      child: _OwnerNoticesView(libraryId: libraryId, ownerId: ownerId),
    );
  }
}

class _OwnerNoticesView extends StatefulWidget {
  const _OwnerNoticesView({required this.libraryId, required this.ownerId});

  final String libraryId;
  final String ownerId;

  @override
  State<_OwnerNoticesView> createState() => _OwnerNoticesViewState();
}

class _OwnerNoticesViewState extends State<_OwnerNoticesView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Notices',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Owner',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: const [
                    Tab(text: 'Active'),
                    Tab(text: 'Scheduled'),
                    Tab(text: 'Expired'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: _buildContent(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNotice,
        backgroundColor: AppUIConstants.primary,
        elevation: 4,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New Notice',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return BlocConsumer<OwnerNoticeCubit, OwnerNoticeState>(
      listener: (context, state) {
        if (state.status == OwnerNoticeStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage ?? 'Error occurred')),
          );
        }
      },
      builder: (context, state) {
        if (state.status == OwnerNoticeStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        return TabBarView(
          controller: _tabController,
          children: [
            _buildList(state.activeNotices),
            _buildList(state.scheduledNotices),
            _buildList(state.expiredNotices),
          ],
        );
      },
    );
  }

  Widget _buildList(List<Notice> notices) {
    if (notices.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          context.read<OwnerNoticeCubit>().loadNotices(widget.libraryId);
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 300,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notices yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pull down to refresh',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<OwnerNoticeCubit>().loadNotices(widget.libraryId);
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: notices.length + (notices.length ~/ 2), // Add ad slots
        itemBuilder: (context, index) {
          // Insert native ad after every 2 notices
          // Ads at positions: 2, 5, 8, 11... (after every 2 items)
          final adIndex = index ~/ 3;
          final isAdPosition =
              (index + 1) % 3 == 0 && adIndex < (notices.length ~/ 2);

          if (isAdPosition) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            );
          }

          // Calculate actual notice index (accounting for ads)
          final noticeIndex = index - adIndex;
          if (noticeIndex >= notices.length) return const SizedBox.shrink();

          return _OwnerNoticeCard(
            notice: notices[noticeIndex],
            onTap: () => _showDetails(notices[noticeIndex]),
            onDelete: () => _delete(notices[noticeIndex]),
            ownerId: widget.ownerId,
          );
        },
      ),
    );
  }

  void _showDetails(Notice notice) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentNoticeDetailsScreen(
          notice: notice,
          studentId: widget.ownerId,
          isOwnerView: true,
          onDelete: () {
            Navigator.pop(context);
            _delete(notice);
          },
        ),
      ),
    );
  }

  void _createNotice() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateNoticeScreen(
          libraryId: widget.libraryId,
          ownerId: widget.ownerId,
        ),
      ),
    );

    // Reload notices after creating a new one
    if (result == true && mounted) {
      context.read<OwnerNoticeCubit>().loadNotices(widget.libraryId);
    }
  }

  void _delete(Notice notice) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Notice?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<OwnerNoticeCubit>().deleteExistingNotice(
                notice.id,
                widget.libraryId,
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _OwnerNoticeCard extends StatefulWidget {
  const _OwnerNoticeCard({
    required this.notice,
    required this.onTap,
    required this.onDelete,
    required this.ownerId,
  });

  final Notice notice;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final String ownerId;

  @override
  State<_OwnerNoticeCard> createState() => _OwnerNoticeCardState();
}

class _OwnerNoticeCardState extends State<_OwnerNoticeCard> {
  bool _isExpanded = false;
  Library? _library;
  String? _ownerName;

  @override
  void initState() {
    super.initState();
    _loadLibraryInfo();
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
    return 'PG Notice';
  }

  String _getLibraryInitials() {
    final name = _getDisplayName();
    if (name == 'PG Notice') {
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
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF0A66C2), width: 2),
        ),
        child: ClipOval(
          child: Image.network(
            _library!.photos.first,
            width: 48,
            height: 48,
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
        onTap: () => _openAttachment(images[0].url),
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

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: images.length == 2 ? 2 : 2,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      childAspectRatio: 1.5,
      children: images.take(4).map((img) {
        return InkWell(
          onTap: () => _openAttachment(img.url),
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

  void _openAttachment(String url) async {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
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
                              Row(
                                children: [
                                  Text(
                                    _formatDate(widget.notice.publishedAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildStatusBadge(),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Delete button
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: Colors.red,
                          iconSize: 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: widget.onDelete,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
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
            if (_getImageAttachments().isNotEmpty)
              _buildImageSection(_getImageAttachments()),
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
                        onTap: () => _openAttachment(pdf.url),
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
                        onTap: () => _openLink(link.url),
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
                    onTap: null,
                  ),
                ),
                Container(width: 1, height: 20, color: Colors.grey.shade300),
                Expanded(
                  child: _buildInteractionButton(
                    icon: Icons.people_outline,
                    label: '${widget.notice.readCount}',
                    onTap: null,
                  ),
                ),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
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

/// Sticky tab bar delegate for collapsible header
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  const _StickyTabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: AppUIConstants.primary, child: tabBar);
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}
