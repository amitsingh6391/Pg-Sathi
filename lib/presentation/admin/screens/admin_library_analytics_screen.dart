import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/library_summary.dart';
import '../../../domain/usecases/send_admin_broadcast_notification.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/admin_analytics_cubit.dart';
import '../cubit/admin_library_management_cubit.dart';

/// Admin screen for viewing detailed library analytics.
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
        title: const Text('Library Analytics'),
        backgroundColor: AppUIConstants.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
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
                child: Text('Most Seats'),
              ),
              const PopupMenuItem(value: 'name', child: Text('Name (A-Z)')),
            ],
          ),
        ],
      ),
      body: BlocBuilder<AdminAnalyticsCubit, AdminAnalyticsState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              // Search Bar
              Container(
                padding: const EdgeInsets.all(AppUIConstants.spacingLg),
                color: AppUIConstants.surface,
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name, owner, or area...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  context
                                      .read<AdminAnalyticsCubit>()
                                      .clearLibraryFilter();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppUIConstants.radiusMd,
                          ),
                          borderSide: BorderSide(color: AppUIConstants.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppUIConstants.radiusMd,
                          ),
                          borderSide: BorderSide(color: AppUIConstants.border),
                        ),
                      ),
                      onChanged: (value) {
                        context.read<AdminAnalyticsCubit>().filterLibraries(
                          value,
                        );
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: AppUIConstants.spacingMd),
                    // Summary Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _StatChip(
                            label: 'Total',
                            value: '${state.librarySummaries.length}',
                          ),
                          const SizedBox(width: AppUIConstants.spacingMd),
                          _StatChip(
                            label: 'Total Seats',
                            value: '${_totalSeats(state.librarySummaries)}',
                          ),
                          const SizedBox(width: AppUIConstants.spacingMd),
                          _StatChip(
                            label: 'Avg Occupancy',
                            value: '${_avgOccupancy(state.librarySummaries)}%',
                            color: AppUIConstants.accent,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppUIConstants.spacingMd),
                    // Expiration Days Filter
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Text(
                            'Filter by Expiration:',
                            style: AppUIConstants.bodySm.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: AppUIConstants.spacingSm),
                          _FilterChip(
                            label: 'All',
                            isSelected: state.expirationDaysFilter == null,
                            onTap: () => context
                                .read<AdminAnalyticsCubit>()
                                .filterByExpirationDays(null),
                          ),
                          const SizedBox(width: AppUIConstants.spacingXs),
                          _FilterChip(
                            label: '≤ 7 days',
                            isSelected: state.expirationDaysFilter == 7,
                            onTap: () => context
                                .read<AdminAnalyticsCubit>()
                                .filterByExpirationDays(7),
                          ),
                          const SizedBox(width: AppUIConstants.spacingXs),
                          _FilterChip(
                            label: '≤ 15 days',
                            isSelected: state.expirationDaysFilter == 15,
                            onTap: () => context
                                .read<AdminAnalyticsCubit>()
                                .filterByExpirationDays(15),
                          ),
                          const SizedBox(width: AppUIConstants.spacingXs),
                          _FilterChip(
                            label: '≤ 30 days',
                            isSelected: state.expirationDaysFilter == 30,
                            onTap: () => context
                                .read<AdminAnalyticsCubit>()
                                .filterByExpirationDays(30),
                          ),
                          const SizedBox(width: AppUIConstants.spacingXs),
                          _FilterChip(
                            label: 'Expired',
                            isSelected: state.expirationDaysFilter == -1,
                            onTap: () => context
                                .read<AdminAnalyticsCubit>()
                                .filterByExpirationDays(-1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Library List
              Expanded(
                child: state.filteredLibraries.isEmpty
                    ? _buildEmptyState()
                    : _buildLibraryList(
                        _sortLibraries(state.filteredLibraries),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.business_outlined,
            size: 64,
            color: AppUIConstants.textTertiary,
          ),
          const SizedBox(height: AppUIConstants.spacingMd),
          Text('No libraries found', style: AppUIConstants.bodyMd),
        ],
      ),
    );
  }

  Widget _buildLibraryList(List<LibrarySummary> libraries) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppUIConstants.spacingMd),
      itemCount: libraries.length,
      itemBuilder: (context, index) {
        final library = libraries[index];
        return _LibraryDetailCard(library: library);
      },
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

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppUIConstants.spacingMd,
        vertical: AppUIConstants.spacingSm,
      ),
      decoration: BoxDecoration(
        color: (color ?? AppUIConstants.primary).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppUIConstants.bodyLg.copyWith(
              color: color ?? AppUIConstants.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: AppUIConstants.spacingXs),
          Text(
            label,
            style: AppUIConstants.caption.copyWith(
              color: color ?? AppUIConstants.primary,
            ),
          ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: AppUIConstants.spacingMd),
      decoration: AppUIConstants.cardDecoration,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppUIConstants.spacingMd),
            decoration: BoxDecoration(
              color: AppUIConstants.primary.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppUIConstants.radiusMd),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppUIConstants.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusSm,
                    ),
                  ),
                  child: Icon(
                    Icons.business,
                    color: AppUIConstants.primary,
                    size: 24,
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
                          style: AppUIConstants.bodySm.copyWith(
                            color: AppUIConstants.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                _buildOccupancyBadge(),
              ],
            ),
          ),

          // Owner Details
          Padding(
            padding: const EdgeInsets.all(AppUIConstants.spacingMd),
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.person_outline,
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
                  icon: Icons.event_seat,
                  label: 'Seats',
                  value:
                      '${library.activeMemberships}/${library.totalSeats} active',
                ),
                const SizedBox(height: AppUIConstants.spacingSm),
                _DetailRow(
                  icon: Icons.calendar_today,
                  label: 'Joined',
                  value: DateFormat('MMM d, yyyy').format(library.createdAt),
                ),
                if (library.subscriptionStatus != null) ...[
                  const SizedBox(height: AppUIConstants.spacingSm),
                  _DetailRow(
                    icon: Icons.subscriptions,
                    label: 'Subscription',
                    value: _formatStatus(library.subscriptionStatus!),
                    valueColor: _getStatusColor(library.subscriptionStatus!),
                  ),
                ],
                if (library.subscriptionEndDate != null) ...[
                  const SizedBox(height: AppUIConstants.spacingSm),
                  _DetailRow(
                    icon: Icons.calendar_today,
                    label: 'Expires',
                    value: _formatExpiration(library),
                    valueColor: _getExpirationColor(library),
                  ),
                ],
              ],
            ),
          ),

          // Actions
          Container(
            padding: const EdgeInsets.all(AppUIConstants.spacingMd),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppUIConstants.divider)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openWhatsApp(context),
                        icon: Icon(
                          Icons.message,
                          size: 18,
                          color: AppUIConstants.success,
                        ),
                        label: const Text('WhatsApp'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppUIConstants.success,
                          side: BorderSide(color: AppUIConstants.success),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppUIConstants.spacingMd),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _sendNotification(context),
                        icon: Icon(
                          Icons.notifications_active,
                          size: 18,
                          color: AppUIConstants.primary,
                        ),
                        label: const Text('Notify'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppUIConstants.primary,
                          side: BorderSide(color: AppUIConstants.primary),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppUIConstants.spacingSm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteLibraryData(context),
                    icon: Icon(
                      Icons.delete_sweep,
                      size: 18,
                      color: AppUIConstants.error,
                    ),
                    label: const Text('Delete All Library Data'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppUIConstants.error,
                      side: BorderSide(color: AppUIConstants.error),
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

  Widget _buildOccupancyBadge() {
    final color = _getOccupancyColor(library.occupancyPercent);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppUIConstants.spacingMd,
        vertical: AppUIConstants.spacingSm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
      ),
      child: Column(
        children: [
          Text(
            library.formattedOccupancy,
            style: AppUIConstants.headingSm.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Occupancy',
            style: AppUIConstants.caption.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Color _getOccupancyColor(double percent) {
    if (percent >= 80) return AppUIConstants.success;
    if (percent >= 50) return AppUIConstants.accent;
    if (percent >= 25) return AppUIConstants.warning;
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
    if (daysRemaining <= 30) {
      return AppUIConstants.accent;
    }
    return AppUIConstants.success;
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
        title: const Text('Delete All Library Data'),
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
                  const Text('• All memberships'),
                  const Text('• All payments'),
                  const Text('• All invoices'),
                  const Text(
                    '• Student accounts (only if they have no other library memberships)',
                  ),
                  const SizedBox(height: AppUIConstants.spacingSm),
                  const Divider(),
                  const SizedBox(height: AppUIConstants.spacingSm),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                        size: 18,
                      ),
                      const SizedBox(width: AppUIConstants.spacingSm),
                      const Text(
                        'Will be preserved:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppUIConstants.spacingSm),
                  const Text(
                    '• Students with memberships in other libraries',
                    style: TextStyle(color: Colors.blue),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppUIConstants.spacingMd),
            Container(
              padding: const EdgeInsets.all(AppUIConstants.spacingSm),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red.shade700),
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
            Text('Deleting library data...'),
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
          content: Text(state.successMessage ?? 'Library data deleted'),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppUIConstants.spacingMd,
          vertical: AppUIConstants.spacingSm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppUIConstants.primary : AppUIConstants.surface,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
          border: Border.all(
            color: isSelected ? AppUIConstants.primary : AppUIConstants.border,
          ),
        ),
        child: Text(
          label,
          style: AppUIConstants.bodySm.copyWith(
            color: isSelected ? Colors.white : AppUIConstants.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
        SizedBox(width: 80, child: Text(label, style: AppUIConstants.caption)),
        Expanded(
          child: Text(
            value,
            style: AppUIConstants.bodyMd.copyWith(
              color: valueColor,
              fontWeight: valueColor != null ? FontWeight.w500 : null,
            ),
          ),
        ),
      ],
    );
  }
}
