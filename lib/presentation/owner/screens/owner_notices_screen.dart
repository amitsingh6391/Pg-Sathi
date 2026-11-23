import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/notice.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/owner_notice_cubit.dart';
import '../widgets/notices/notice_empty_state.dart';
import '../widgets/notices/owner_notice_card.dart';
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
              backgroundColor: AppUIConstants.surface,
              surfaceTintColor: Colors.transparent,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Notices',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppUIConstants.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppUIConstants.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Owner',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppUIConstants.primary,
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
                  labelColor: AppUIConstants.primary,
                  unselectedLabelColor: AppUIConstants.textSecondary,
                  indicatorColor: AppUIConstants.primary,
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
            _buildList(state.activeNotices, NoticeEmptyKind.active),
            _buildList(state.scheduledNotices, NoticeEmptyKind.scheduled),
            _buildList(state.expiredNotices, NoticeEmptyKind.expired),
          ],
        );
      },
    );
  }

  Future<void> _refresh() async {
    context.read<OwnerNoticeCubit>().loadNotices(widget.libraryId);
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Widget _buildList(List<Notice> notices, NoticeEmptyKind kind) {
    if (notices.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: NoticeEmptyState(kind: kind, onCreate: _createNotice),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.only(
          top: AppUIConstants.spacingLg,
          bottom: 96,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: notices.length,
        itemBuilder: (context, index) {
          final notice = notices[index];

          return OwnerNoticeCard(
            notice: notice,
            onTap: () => _showDetails(notice),
            onDelete: () => _delete(notice),
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

    if (result == true && mounted) {
      context.read<OwnerNoticeCubit>().loadNotices(widget.libraryId);
    }
  }

  Future<void> _delete(Notice notice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusXl),
        ),
        title: const Text(
          'Delete this notice?',
          style: AppUIConstants.headingSm,
        ),
        content: const Text(
          'Tenants will no longer see it. This can\'t be undone.',
          style: AppUIConstants.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppUIConstants.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppUIConstants.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<OwnerNoticeCubit>().deleteExistingNotice(
        notice.id,
        widget.libraryId,
      );
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
    return Container(
      decoration: const BoxDecoration(
        color: AppUIConstants.surface,
        border: Border(bottom: BorderSide(color: AppUIConstants.border)),
      ),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}
