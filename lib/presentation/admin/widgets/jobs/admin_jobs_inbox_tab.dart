import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/app_ui_constants.dart';
import '../../cubit/jobs/admin_job_candidates_cubit.dart';
import '../../cubit/jobs/admin_job_candidates_state.dart';
import '../../cubit/jobs/admin_jobs_cubit.dart';
import 'admin_candidate_tile.dart';

/// Composes the candidate inbox: a fetch toolbar at top, an optional
/// multi-select bar below it, and the candidate list.
///
/// Holds no state of its own — the cubit is the source of truth for
/// selection, fetch progress, and one-shot side effects (snack bars).
class AdminJobsInboxTab extends StatelessWidget {
  const AdminJobsInboxTab({super.key, required this.adminId});

  final String adminId;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminJobCandidatesCubit, AdminJobCandidatesState>(
      listener: _handleSideEffects,
      builder: (context, state) {
        return Column(
          children: [
            _FetchBar(state: state),
            if (state.selectionMode) _SelectionBar(adminId: adminId),
            Expanded(child: _ListBody(state: state, adminId: adminId)),
          ],
        );
      },
    );
  }

  void _handleSideEffects(
    BuildContext context,
    AdminJobCandidatesState state,
  ) {
    final cubit = context.read<AdminJobCandidatesCubit>();
    final messenger = ScaffoldMessenger.of(context);

    final fetchCount = state.lastFetchNewCount;
    if (fetchCount != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            fetchCount == 0
                ? 'No new candidates found'
                : 'Added $fetchCount new candidates',
          ),
          backgroundColor: fetchCount == 0
              ? AppUIConstants.secondary
              : AppUIConstants.success,
        ),
      );
      cubit.acknowledgeFetchResult();
    }

    final bulkCount = state.lastBulkPublishedCount;
    if (bulkCount != null && bulkCount > 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Published $bulkCount jobs'),
          backgroundColor: AppUIConstants.success,
        ),
      );
      cubit.acknowledgeBulkPublishResult();
    }

    final failure = state.failure;
    if (failure != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(failure.message ?? 'Something went wrong'),
          backgroundColor: AppUIConstants.error,
        ),
      );
      cubit.acknowledgeFailure();
    }
  }
}

// =============================================================================
// Fetch toolbar
// =============================================================================

class _FetchBar extends StatelessWidget {
  const _FetchBar({required this.state});
  final AdminJobCandidatesState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AdminJobCandidatesCubit>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        border: Border(
          bottom: BorderSide(color: AppUIConstants.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Auto-pulls every 2h · scrapes sarkariresult.com',
              style: AppUIConstants.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _FetchLimitDropdown(
            value: state.limitPerSource,
            onChanged: state.isFetching ? null : cubit.setFetchLimit,
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            icon: state.isFetching
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded, size: 16),
            label: Text(state.isFetching ? 'Fetching…' : 'Fetch'),
            onPressed: state.isFetching ? null : cubit.fetchNow,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppUIConstants.primary,
              side: BorderSide(color: AppUIConstants.primary),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: const Size(0, 36),
            ),
          ),
        ],
      ),
    );
  }
}

class _FetchLimitDropdown extends StatelessWidget {
  const _FetchLimitDropdown({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int>? onChanged;

  static const _options = [10, 25, 50, 100];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppUIConstants.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 16),
          items: _options
              .map(
                (v) => DropdownMenuItem(
                  value: v,
                  child: Text('$v', style: AppUIConstants.bodySm),
                ),
              )
              .toList(),
          onChanged:
              onChanged == null ? null : (v) => onChanged!(v ?? value),
        ),
      ),
    );
  }
}

// =============================================================================
// Multi-select bar
// =============================================================================

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.adminId});
  final String adminId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminJobCandidatesCubit, AdminJobCandidatesState>(
      buildWhen: (p, c) =>
          p.selectedIds != c.selectedIds ||
          p.isBulkPublishing != c.isBulkPublishing,
      builder: (context, state) {
        final cubit = context.read<AdminJobCandidatesCubit>();
        final count = state.selectedIds.length;
        final isBusy = state.isBulkPublishing;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppUIConstants.primary.withValues(alpha: 0.06),
            border: Border(
              bottom:
                  BorderSide(color: AppUIConstants.border, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: isBusy ? null : cubit.exitSelectionMode,
                tooltip: 'Cancel',
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: 4),
              Text(
                '$count selected',
                style: AppUIConstants.bodyMd.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: isBusy ? null : cubit.selectAll,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('All'),
              ),
              const SizedBox(width: 4),
              OutlinedButton.icon(
                icon: const Icon(Icons.block, size: 14),
                label: const Text('Ignore'),
                onPressed: (count == 0 || isBusy)
                    ? null
                    : () => _confirmAndIgnoreSelected(context, count),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 34),
                  foregroundColor: AppUIConstants.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                icon: isBusy
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.check, size: 14),
                label: Text(isBusy ? 'Publishing' : 'Publish $count'),
                onPressed: (count == 0 || isBusy)
                    ? null
                    : () => _confirmAndPublishSelected(context, count),
                style: FilledButton.styleFrom(
                  backgroundColor: AppUIConstants.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 34),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmAndPublishSelected(
    BuildContext context,
    int count,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Publish $count ${count == 1 ? 'job' : 'jobs'}?'),
        content: const Text(
          'These will go live immediately and trigger push notifications '
          'to students. Each job is published with the scraper-extracted '
          'fees, dates, vacancies and apply URL. You can edit any job '
          'afterwards from the Published tab.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppUIConstants.primary,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Publish $count'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context
        .read<AdminJobCandidatesCubit>()
        .publishSelected(adminId: adminId);
    if (!context.mounted) return;
    try {
      context.read<AdminJobsCubit>().load();
    } catch (_) {
      // Sibling cubit may not be mounted in some entry points.
    }
  }

  Future<void> _confirmAndIgnoreSelected(
    BuildContext context,
    int count,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Ignore $count ${count == 1 ? 'candidate' : 'candidates'}?',
        ),
        content: const Text(
          'Ignored candidates are hidden from the inbox and never turn '
          'into student-facing jobs. This is reversible from Firestore.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppUIConstants.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Ignore $count'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context
        .read<AdminJobCandidatesCubit>()
        .ignoreSelected(adminId: adminId);
  }
}

// =============================================================================
// List body
// =============================================================================

class _ListBody extends StatelessWidget {
  const _ListBody({required this.state, required this.adminId});

  final AdminJobCandidatesState state;
  final String adminId;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.items.isEmpty) {
      return const _EmptyState();
    }
    return RefreshIndicator(
      onRefresh: () => context.read<AdminJobCandidatesCubit>().load(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.items.length,
        itemBuilder: (context, i) {
          final candidate = state.items[i];
          return AdminCandidateTile(
            candidate: candidate,
            adminId: adminId,
            isSelected: state.selectedIds.contains(candidate.id),
            selectionMode: state.selectionMode,
          );
        },
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
          Icon(Icons.inbox_rounded,
              size: 48, color: AppUIConstants.textTertiary),
          const SizedBox(height: 12),
          const Text('Inbox is empty', style: AppUIConstants.headingSm),
          const SizedBox(height: 4),
          Text(
            'Tap "Fetch" or wait for the scheduled scrape',
            style: AppUIConstants.bodySm,
          ),
        ],
      ),
    );
  }
}
