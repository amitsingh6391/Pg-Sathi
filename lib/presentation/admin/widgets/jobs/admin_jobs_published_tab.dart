import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../domain/entities/job_alert.dart';
import '../../../core/app_ui_constants.dart';
import '../../cubit/jobs/admin_job_analytics_cubit.dart';
import '../../cubit/jobs/admin_jobs_cubit.dart';
import '../../cubit/jobs/admin_jobs_state.dart';
import '../../screens/jobs/admin_job_analytics_sheet.dart';
import '../../screens/jobs/admin_job_form_screen.dart';

/// Manage-published-jobs tab. List of live alerts with quick view of
/// engagement (views / clicks / bookmarks) and shortcuts to analytics
/// and edit/delete.
class AdminJobsPublishedTab extends StatelessWidget {
  const AdminJobsPublishedTab({super.key, required this.adminId});

  final String adminId;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        BlocBuilder<AdminJobsCubit, AdminJobsState>(
          builder: (context, state) {
            if (state.isLoading && state.items.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.items.isEmpty) {
              return const _EmptyState();
            }
            return RefreshIndicator(
              onRefresh: () => context.read<AdminJobsCubit>().load(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.items.length + (state.hasMore ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i >= state.items.length) {
                    return const _LoadMoreButton();
                  }
                  return _PublishedJobTile(
                    job: state.items[i],
                    adminId: adminId,
                  );
                },
              ),
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () => _openCreate(context),
            icon: const Icon(Icons.add),
            label: const Text('New Job'),
            backgroundColor: AppUIConstants.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  void _openCreate(BuildContext context) {
    final jobsCubit = context.read<AdminJobsCubit>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: jobsCubit,
          child: AdminJobFormScreen(adminId: adminId),
        ),
      ),
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: OutlinedButton(
          onPressed: () => context.read<AdminJobsCubit>().loadMore(),
          child: const Text('Load more'),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.work_off_outlined,
              size: 48, color: AppUIConstants.textTertiary),
          const SizedBox(height: 12),
          const Text('No published jobs yet',
              style: AppUIConstants.headingSm),
          const SizedBox(height: 4),
          Text(
            'Publish a candidate or tap + to create a new one',
            style: AppUIConstants.bodySm,
          ),
        ],
      ),
    );
  }
}

class _PublishedJobTile extends StatelessWidget {
  const _PublishedJobTile({required this.job, required this.adminId});

  final JobAlert job;
  final String adminId;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(color: AppUIConstants.border, width: 0.5),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          onTap: () => _openEdit(context),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildContent()),
                _buildActions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _CategoryBadge(text: job.category.label),
          const SizedBox(width: 8),
          Text(
            DateFormat('dd MMM').format(job.postedAt),
            style: AppUIConstants.caption,
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          job.title,
          style: AppUIConstants.bodyLg,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          job.organization,
          style: AppUIConstants.bodySm,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Row(children: [
          _Stat(icon: Icons.visibility_outlined, value: '${job.viewCount}'),
          const SizedBox(width: 12),
          _Stat(icon: Icons.touch_app_outlined,
              value: '${job.applyClickCount}'),
          const SizedBox(width: 12),
          _Stat(icon: Icons.bookmark_border_rounded,
              value: '${job.bookmarkCount}'),
        ]),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        IconButton(
          icon: Icon(
            Icons.insights_rounded,
            size: 20,
            color: AppUIConstants.accent,
          ),
          tooltip: 'Analytics',
          onPressed: () => _openAnalytics(context),
        ),
        IconButton(
          icon: Icon(
            Icons.delete_outline,
            size: 20,
            color: AppUIConstants.error,
          ),
          tooltip: 'Delete',
          onPressed: () => _confirmDelete(context),
        ),
      ],
    );
  }

  void _openEdit(BuildContext context) {
    final cubit = context.read<AdminJobsCubit>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: AdminJobFormScreen(adminId: adminId, existing: job),
        ),
      ),
    );
  }

  void _openAnalytics(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BlocProvider(
        create: (_) => sl<AdminJobAnalyticsCubit>()..load(job.id),
        child: AdminJobAnalyticsSheet(job: job),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete job'),
        content: const Text(
          'This will remove the job from students immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: TextStyle(color: AppUIConstants.error),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    context.read<AdminJobsCubit>().delete(job.id);
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppUIConstants.textTertiary),
        const SizedBox(width: 3),
        Text(value, style: AppUIConstants.caption),
      ],
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppUIConstants.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppUIConstants.primary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
