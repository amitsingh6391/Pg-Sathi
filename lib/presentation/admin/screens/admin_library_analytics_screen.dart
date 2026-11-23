import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/library_summary.dart';
import '../../../domain/usecases/send_admin_broadcast_notification.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';
import '../cubit/admin_analytics_cubit.dart';
import '../cubit/admin_library_management_cubit.dart';

/// Admin screen for viewing detailed PG analytics.
class AdminLibraryAnalyticsScreen extends StatefulWidget {
  const AdminLibraryAnalyticsScreen({super.key});

  @override
  State<AdminLibraryAnalyticsScreen> createState() =>
      _AdminLibraryAnalyticsScreenState();
}

class _AdminLibraryAnalyticsScreenState
    extends State<AdminLibraryAnalyticsScreen> {
  final _searchController = TextEditingController();
  String _sortBy = 'newest';

  static const _sortLabels = {
    'newest': 'Newest first',
    'oldest': 'Oldest first',
    'occupancy_high': 'Highest occupancy',
    'occupancy_low': 'Lowest occupancy',
    'seats_high': 'Most beds',
    'name': 'Name (A-Z)',
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        title: const Text('PG Analytics', style: AppUIConstants.headingSm),
        backgroundColor: AppUIConstants.background,
        foregroundColor: AppUIConstants.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort',
            color: AppUIConstants.surfaceMuted,
            initialValue: _sortBy,
            onSelected: (value) {
              setState(() => _sortBy = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'newest', child: Text('Newest First')),
              const PopupMenuItem(value: 'oldest', child: Text('Oldest First')),
              const PopupMenuItem(
                value: 'occupancy_high',
                child: Text('Highest Occupancy'),
              ),
              const PopupMenuItem(
                value: 'occupancy_low',
                child: Text('Lowest Occupancy'),
              ),
              const PopupMenuItem(
                value: 'seats_high',
                child: Text('Most Beds'),
              ),
              const PopupMenuItem(value: 'name', child: Text('Name (A-Z)')),
            ],
          ),
        ],
      ),
      body: BlocBuilder<AdminAnalyticsCubit, AdminAnalyticsState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const _ListSkeleton();
          }

          final all = state.librarySummaries;
          final expiringSoon = all
              .where(
                (l) =>
                    !l.isSubscriptionExpired &&
                    l.daysRemaining != null &&
                    l.daysRemaining! <= 7,
              )
              .length;
          final expired = all.where((l) => l.isSubscriptionExpired).length;
          final filtered = _sortLibraries(state.filteredLibraries);

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppUIConstants.spacingLg,
              4,
              AppUIConstants.spacingLg,
              32,
            ),
            children: [
              _buildHero(all.length, _avgOccupancy(all)),
              const SizedBox(height: AppUIConstants.spacingMd),
              Row(
                children: [
                  Expanded(
                    child: PremiumStatTile(
                      icon: Icons.bed_rounded,
                      value: '${_totalSeats(all)}',
                      label: 'Total beds',
                      color: AppUIConstants.primaryLight,
                    ),
                  ),
                  const SizedBox(width: AppUIConstants.spacingMd),
                  Expanded(
                    child: PremiumStatTile(
                      icon: Icons.hourglass_bottom_rounded,
                      value: '$expiringSoon',
                      label: 'Expiring in 7d',
                      color: AppUIConstants.warning,
                    ),
                  ),
                  const SizedBox(width: AppUIConstants.spacingMd),
                  Expanded(
                    child: PremiumStatTile(
                      icon: Icons.event_busy_rounded,
                      value: '$expired',
                      label: 'Expired',
                      color: AppUIConstants.error,
                    ),
                  ),
                ],
              ),
              const PremiumSectionHeader('Find a PG'),
              _buildSearchField(context),
              const SizedBox(height: AppUIConstants.spacingMd),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final f in const [
                      (null, 'All'),
                      (7, '≤ 7 days'),
                      (15, '≤ 15 days'),
                      (30, '≤ 30 days'),
                      (-1, 'Expired'),
                    ]) ...[
                      _FilterChip(
                        label: f.$2,
                        isSelected: state.expirationDaysFilter == f.$1,
                        onTap: () => context
                            .read<AdminAnalyticsCubit>()
                            .filterByExpirationDays(f.$1),
                      ),
                      const SizedBox(width: AppUIConstants.spacingSm),
                    ],
                  ],
                ),
              ),
              PremiumSectionHeader(
                '${filtered.length} ${filtered.length == 1 ? 'PG' : 'PGs'} · ${_sortLabels[_sortBy]}',
              ),
              if (filtered.isEmpty)
                _buildEmptyState()
              else
                for (final library in filtered)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: AppUIConstants.spacingMd,
                    ),
                    child: _LibraryDetailCard(library: library),
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHero(int total, int avgOccupancy) {
    return Container(
      padding: const EdgeInsets.all(AppUIConstants.spacingXl),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        border: Border.all(color: AppUIConstants.border),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusXl),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PGS ON PLATFORM',
                  style: TextStyle(
                    color: AppUIConstants.textSecondary,
                    fontSize: 11.5,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$total',
                  style: const TextStyle(
                    color: AppUIConstants.textPrimary,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Average occupancy $avgOccupancy%',
                  style: const TextStyle(
                    color: AppUIConstants.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              fit: StackFit.expand,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: avgOccupancy / 100),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => CircularProgressIndicator(
                    value: v.clamp(0.0, 1.0),
                    strokeWidth: 7,
                    strokeCap: StrokeCap.round,
                    backgroundColor: AppUIConstants.surfaceMuted,
                    valueColor: const AlwaysStoppedAnimation(
                      AppUIConstants.primary,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    '$avgOccupancy%',
                    style: const TextStyle(
                      color: AppUIConstants.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
      borderSide: BorderSide(color: c),
    );
    return TextField(
      controller: _searchController,
      style: AppUIConstants.bodyMd,
      cursorColor: AppUIConstants.primaryLight,
      decoration: InputDecoration(
        hintText: 'Search by name, owner, or area...',
        hintStyle: AppUIConstants.bodyMd.copyWith(
          color: AppUIConstants.textTertiary,
        ),
        filled: true,
        fillColor: AppUIConstants.surface,
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppUIConstants.textTertiary,
        ),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppUIConstants.textSecondary,
                ),
                onPressed: () {
                  _searchController.clear();
                  context.read<AdminAnalyticsCubit>().clearLibraryFilter();
                  setState(() {});
                },
              )
            : null,
        border: border(AppUIConstants.border),
        enabledBorder: border(AppUIConstants.border),
        focusedBorder: border(AppUIConstants.primaryLight),
      ),
      onChanged: (value) {
        context.read<AdminAnalyticsCubit>().filterLibraries(value);
        setState(() {});
      },
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppUIConstants.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 34,
                color: AppUIConstants.textTertiary,
              ),
            ),
            const SizedBox(height: AppUIConstants.spacingMd),
            Text('No PGs found', style: AppUIConstants.bodyLg),
            const SizedBox(height: 4),
            Text(
              'Try a different search or filter',
              style: AppUIConstants.bodySm,
            ),
          ],
        ),
      ),
    );
  }

  List<LibrarySummary> _sortLibraries(List<LibrarySummary> libraries) {
    final sorted = List<LibrarySummary>.from(libraries);
    switch (_sortBy) {
      case 'newest':
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case 'oldest':
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case 'occupancy_high':
        sorted.sort((a, b) => b.occupancyPercent.compareTo(a.occupancyPercent));
      case 'occupancy_low':
        sorted.sort((a, b) => a.occupancyPercent.compareTo(b.occupancyPercent));
      case 'seats_high':
        sorted.sort((a, b) => b.totalSeats.compareTo(a.totalSeats));
      case 'name':
        sorted.sort(
          (a, b) => a.libraryName.toLowerCase().compareTo(
            b.libraryName.toLowerCase(),
          ),
        );
    }
    return sorted;
  }

  int _totalSeats(List<LibrarySummary> libraries) {
    return libraries.fold(0, (sum, lib) => sum + lib.totalSeats);
  }

  int _avgOccupancy(List<LibrarySummary> libraries) {
    if (libraries.isEmpty) return 0;
    final totalOccupancy = libraries.fold(
      0.0,
      (sum, lib) => sum + lib.occupancyPercent,
    );
    return (totalOccupancy / libraries.length).round();
  }
}

// ============================================================================
// Supporting Widgets
// ============================================================================

class _ListSkeleton extends StatefulWidget {
  const _ListSkeleton();

  @override
  State<_ListSkeleton> createState() => _ListSkeletonState();
}

class _ListSkeletonState extends State<_ListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _bone(double h) => Container(
    height: h,
    decoration: BoxDecoration(
      color: AppUIConstants.surfaceMuted,
      borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_c),
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppUIConstants.spacingLg),
        children: [
          _bone(130),
          const SizedBox(height: AppUIConstants.spacingMd),
          Row(
            children: [
              Expanded(child: _bone(96)),
              const SizedBox(width: AppUIConstants.spacingMd),
              Expanded(child: _bone(96)),
              const SizedBox(width: AppUIConstants.spacingMd),
              Expanded(child: _bone(96)),
            ],
          ),
          const SizedBox(height: AppUIConstants.spacingXl),
          _bone(52),
          const SizedBox(height: AppUIConstants.spacingMd),
          _bone(200),
          const SizedBox(height: AppUIConstants.spacingMd),
          _bone(200),
        ],
      ),
    );
  }
}

class _LibraryDetailCard extends StatelessWidget {
  const _LibraryDetailCard({required this.library});

  final LibrarySummary library;

  @override
  Widget build(BuildContext context) {
    final occColor = _getOccupancyColor(library.occupancyPercent);
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppUIConstants.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppUIConstants.primarySoft,
                        borderRadius: BorderRadius.circular(
                          AppUIConstants.radiusSm,
                        ),
                      ),
                      child: const Icon(
                        Icons.apartment_rounded,
                        color: AppUIConstants.primaryLight,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppUIConstants.spacingMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            library.libraryName,
                            style: AppUIConstants.headingSm,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (library.area != null)
                            Text(
                              library.area!,
                              style: AppUIConstants.bodySm,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    if (library.subscriptionStatus != null)
                      PremiumStatusPill(
                        _formatStatus(library.subscriptionStatus!),
                        color: _getStatusColor(library.subscriptionStatus!),
                      ),
                  ],
                ),
                const SizedBox(height: AppUIConstants.spacingLg),
                Row(
                  children: [
                    Text(
                      library.formattedOccupancy,
                      style: AppUIConstants.statValue.copyWith(color: occColor),
                    ),
                    const SizedBox(width: AppUIConstants.spacingSm),
                    Text('occupancy', style: AppUIConstants.caption),
                    const Spacer(),
                    Text(
                      '${library.activeMemberships}/${library.totalSeats} beds active',
                      style: AppUIConstants.bodySm,
                    ),
                  ],
                ),
                const SizedBox(height: AppUIConstants.spacingSm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(
                    AppUIConstants.radiusFull,
                  ),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(
                      begin: 0,
                      end: (library.occupancyPercent / 100).clamp(0.0, 1.0),
                    ),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 6,
                      backgroundColor: AppUIConstants.surfaceMuted,
                      valueColor: AlwaysStoppedAnimation(occColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppUIConstants.divider),
          Padding(
            padding: const EdgeInsets.all(AppUIConstants.spacingLg),
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Owner',
                  value: library.ownerName,
                ),
                const SizedBox(height: AppUIConstants.spacingSm),
                _DetailRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: library.ownerPhone,
                ),
                const SizedBox(height: AppUIConstants.spacingSm),
                _DetailRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Joined',
                  value: DateFormat('MMM d, yyyy').format(library.createdAt),
                ),
                if (library.subscriptionEndDate != null) ...[
                  const SizedBox(height: AppUIConstants.spacingSm),
                  _DetailRow(
                    icon: Icons.timelapse_rounded,
                    label: 'Expires',
                    value: _formatExpiration(library),
                    valueColor: _getExpirationColor(library),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppUIConstants.spacingMd,
              AppUIConstants.spacingSm,
              AppUIConstants.spacingMd,
              AppUIConstants.spacingMd,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.chat_rounded,
                    label: 'WhatsApp',
                    color: AppUIConstants.primaryLight,
                    onTap: () => _openWhatsApp(context),
                  ),
                ),
                const SizedBox(width: AppUIConstants.spacingSm),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.notifications_active_rounded,
                    label: 'Notify',
                    color: AppUIConstants.primaryLight,
                    onTap: () => _sendNotification(context),
                  ),
                ),
                const SizedBox(width: AppUIConstants.spacingSm),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.delete_sweep_rounded,
                    label: 'Delete data',
                    color: AppUIConstants.error,
                    onTap: () => _deleteLibraryData(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getOccupancyColor(double percent) {
    if (percent >= 25) return AppUIConstants.primaryLight;
    return AppUIConstants.textTertiary;
  }

  String _formatStatus(String status) {
    return status
        .split(RegExp(r'(?=[A-Z])'))
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppUIConstants.success;
      case 'pending':
      case 'pendingverification':
        return AppUIConstants.warning;
      case 'expired':
        return AppUIConstants.error;
      default:
        return AppUIConstants.textSecondary;
    }
  }

  String _formatExpiration(LibrarySummary library) {
    if (library.isSubscriptionExpired) {
      return 'Expired';
    }
    final daysRemaining = library.daysRemaining;
    if (daysRemaining == null) {
      return DateFormat('MMM d, yyyy').format(library.subscriptionEndDate!);
    }
    if (daysRemaining == 0) {
      return 'Expires today';
    }
    if (daysRemaining == 1) {
      return 'Expires tomorrow';
    }
    return '$daysRemaining days remaining';
  }

  Color _getExpirationColor(LibrarySummary library) {
    if (library.isSubscriptionExpired) {
      return AppUIConstants.error;
    }
    final daysRemaining = library.daysRemaining;
    if (daysRemaining == null) {
      return AppUIConstants.textSecondary;
    }
    if (daysRemaining <= 7) {
      return AppUIConstants.error;
    }
    if (daysRemaining <= 15) {
      return AppUIConstants.warning;
    }
    return AppUIConstants.textSecondary;
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final url = Uri.parse(library.whatsappUrl);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _sendNotification(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final titleController = TextEditingController();
        final bodyController = TextEditingController();

        return AlertDialog(
          title: Text('Send Notification to ${library.ownerName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Notification title',
                ),
              ),
              const SizedBox(height: AppUIConstants.spacingMd),
              TextField(
                controller: bodyController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  hintText: 'Notification message',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Send notification
                context.read<AdminAnalyticsCubit>().sendBroadcast(
                  title: titleController.text,
                  body: bodyController.text,
                  audience: BroadcastAudience.selectedLibraries,
                  libraryIds: [library.libraryId],
                );
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notification sent')),
                );
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  void _deleteLibraryData(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete All PG Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently delete ALL data for:',
              style: AppUIConstants.bodyMd.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppUIConstants.spacingMd),
            Text(
              library.libraryName,
              style: AppUIConstants.headingSm.copyWith(
                color: AppUIConstants.primary,
              ),
            ),
            const SizedBox(height: AppUIConstants.spacingLg),
            Container(
              padding: const EdgeInsets.all(AppUIConstants.spacingMd),
              decoration: BoxDecoration(
                color: AppUIConstants.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: AppUIConstants.error,
                        size: 20,
                      ),
                      const SizedBox(width: AppUIConstants.spacingSm),
                      const Text(
                        'What will be deleted:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppUIConstants.spacingSm),
                  const Text('• All stays'),
                  const Text('• All payments'),
                  const Text('• All invoices'),
                  const Text(
                    '• Tenant accounts (only if they have no other PG stays)',
                  ),
                  const SizedBox(height: AppUIConstants.spacingSm),
                  const Divider(),
                  const SizedBox(height: AppUIConstants.spacingSm),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppUIConstants.primaryLight,
                        size: 18,
                      ),
                      const SizedBox(width: AppUIConstants.spacingSm),
                      const Text(
                        'Will be preserved:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppUIConstants.primaryLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppUIConstants.spacingSm),
                  const Text(
                    '• Tenants with stays in other PGs',
                    style: TextStyle(color: AppUIConstants.primaryLight),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppUIConstants.spacingMd),
            Container(
              padding: const EdgeInsets.all(AppUIConstants.spacingSm),
              decoration: BoxDecoration(
                color: AppUIConstants.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: AppUIConstants.error),
                  const SizedBox(width: AppUIConstants.spacingSm),
                  const Expanded(
                    child: Text(
                      'This action CANNOT be undone!',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              // Show loading and delete
              _performDelete(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppUIConstants.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete All Data'),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete(BuildContext context) async {
    // Import and use the cubit
    final cubit = sl<AdminLibraryManagementCubit>();

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: AppUIConstants.spacingLg),
            Text('Deleting PG data...'),
          ],
        ),
      ),
    );

    await cubit.deleteLibraryData(library.libraryId);

    if (!context.mounted) return;

    // Close loading dialog first
    Navigator.of(context, rootNavigator: true).pop();

    final state = cubit.state;

    if (state.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.successMessage ?? 'PG data deleted'),
          backgroundColor: AppUIConstants.success,
          duration: const Duration(seconds: 2),
        ),
      );

      // Refresh the analytics without blocking UI
      context.read<AdminAnalyticsCubit>().loadAnalytics();
    } else if (state.isError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.errorMessage ?? 'Failed to delete data'),
          backgroundColor: AppUIConstants.error,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
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
    return Material(
      color: AppUIConstants.surfaceMuted,
      borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppUIConstants.spacingMd + 2,
          vertical: AppUIConstants.spacingSm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppUIConstants.primarySoft
              : AppUIConstants.surface,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
          border: Border.all(
            color: isSelected
                ? AppUIConstants.primaryLight
                : AppUIConstants.border,
          ),
        ),
        child: Text(
          label,
          style: AppUIConstants.bodySm.copyWith(
            color: isSelected
                ? AppUIConstants.primaryLight
                : AppUIConstants.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppUIConstants.textTertiary),
        const SizedBox(width: AppUIConstants.spacingSm),
        SizedBox(width: 64, child: Text(label, style: AppUIConstants.caption)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppUIConstants.bodyMd.copyWith(
              color: valueColor,
              fontWeight: valueColor != null ? FontWeight.w600 : null,
            ),
          ),
        ),
      ],
    );
  }
}
