import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/services/analytics_service.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/feature_analytics_cubit.dart';

/// Admin screen to view app-wide feature usage analytics.
/// Shows real-time metrics from Firebase Analytics for all tracked events.
class AdminFeatureAnalyticsScreen extends StatelessWidget {
  const AdminFeatureAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<FeatureAnalyticsCubit>()..loadAnalytics(),
      child: const _AdminFeatureAnalyticsView(),
    );
  }
}

class _AdminFeatureAnalyticsView extends StatefulWidget {
  const _AdminFeatureAnalyticsView();

  @override
  State<_AdminFeatureAnalyticsView> createState() =>
      _AdminFeatureAnalyticsViewState();
}

class _AdminFeatureAnalyticsViewState
    extends State<_AdminFeatureAnalyticsView> {
  String _selectedTimeRange = '7d';
  String? _selectedRole;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        title: const Text('Feature Analytics'),
        backgroundColor: AppUIConstants.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<FeatureAnalyticsCubit>().loadAnalytics(
                  role: _selectedRole,
                  timeRange: _selectedTimeRange,
                ),
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
            tooltip: 'Help',
          ),
        ],
      ),
      body: BlocBuilder<FeatureAnalyticsCubit, FeatureAnalyticsState>(
        builder: (context, state) {
          if (state.isLoading && state.eventCounts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.errorMessage != null && state.eventCounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppUIConstants.textSecondary,
                  ),
                  const SizedBox(height: AppUIConstants.spacingLg),
                  Text(
                    state.errorMessage!,
                    textAlign: TextAlign.center,
                    style: AppUIConstants.bodyMd,
                  ),
                  const SizedBox(height: AppUIConstants.spacingLg),
                  ElevatedButton.icon(
                    onPressed: () =>
                        context.read<FeatureAnalyticsCubit>().loadAnalytics(
                              role: _selectedRole,
                              timeRange: _selectedTimeRange,
                            ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => context.read<FeatureAnalyticsCubit>().loadAnalytics(
                  role: _selectedRole,
                  timeRange: _selectedTimeRange,
                ),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppUIConstants.spacingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filters
                  _buildFilters(),
                  const SizedBox(height: AppUIConstants.spacingXl),

                  // Event Categories
                  _buildSectionHeader('📊 Event Categories'),
                  const SizedBox(height: AppUIConstants.spacingMd),
                  _buildEventCategories(state.eventCounts),
                  const SizedBox(height: AppUIConstants.spacing2Xl),

                  // Top Features
                  _buildSectionHeader('🔥 Most Used Features'),
                  const SizedBox(height: AppUIConstants.spacingMd),
                  _buildTopFeatures(state.eventCounts),
                  const SizedBox(height: AppUIConstants.spacing2Xl),

                  // User Role Breakdown
                  _buildSectionHeader('👥 Usage by Role'),
                  const SizedBox(height: AppUIConstants.spacingMd),
                  _buildRoleBreakdown(state.roleCounts),
                  const SizedBox(height: AppUIConstants.spacing2Xl),

                  // Platform Breakdown
                  _buildSectionHeader('📱 Platform Distribution'),
                  const SizedBox(height: AppUIConstants.spacingMd),
                  _buildPlatformBreakdown(state.platformCounts),
                  const SizedBox(height: AppUIConstants.spacing2Xl),

                  // Recent Events Timeline
                  _buildSectionHeader('⏱️ Recent Events'),
                  const SizedBox(height: AppUIConstants.spacingMd),
                  _buildRecentEvents(state.recentEvents),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppUIConstants.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filters', style: AppUIConstants.headingSm),
            const SizedBox(height: AppUIConstants.spacingMd),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Time Range',
                        style: AppUIConstants.bodySm.copyWith(
                          color: AppUIConstants.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedTimeRange,
                        isDense: true,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1E293B),
                        ),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 6,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: '1d', child: Text('1d', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: '7d', child: Text('7d', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: '30d', child: Text('30d', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: '90d', child: Text('90d', style: TextStyle(fontSize: 12))),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedTimeRange = value);
                            context.read<FeatureAnalyticsCubit>().loadAnalytics(
                              role: _selectedRole,
                              timeRange: value,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppUIConstants.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User Role',
                        style: AppUIConstants.bodySm.copyWith(
                          color: AppUIConstants.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String?>(
                        initialValue: _selectedRole,
                        isDense: true,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1E293B),
                        ),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 6,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('All', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'admin', child: Text('Admin', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'owner', child: Text('Owner', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'student', child: Text('Student', style: TextStyle(fontSize: 12))),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedRole = value);
                          context.read<FeatureAnalyticsCubit>().loadAnalytics(
                            role: value,
                            timeRange: _selectedTimeRange,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCategories(Map<String, int> eventCounts) {
    // Group events by category
    final membershipCount = (eventCounts[AnalyticsEventNames.membershipCreated] ?? 0) +
        (eventCounts[AnalyticsEventNames.membershipRenewed] ?? 0) +
        (eventCounts[AnalyticsEventNames.membershipExpired] ?? 0);
    
    final attendanceCount = (eventCounts[AnalyticsEventNames.attendanceMarked] ?? 0) +
        (eventCounts[AnalyticsEventNames.bulkAttendanceMarked] ?? 0);
    
    final invoiceCount = (eventCounts[AnalyticsEventNames.invoiceGenerated] ?? 0) +
        (eventCounts[AnalyticsEventNames.invoiceDownloaded] ?? 0) +
        (eventCounts[AnalyticsEventNames.invoiceShared] ?? 0);
    
    final paymentCount = (eventCounts[AnalyticsEventNames.paymentInitiated] ?? 0) +
        (eventCounts[AnalyticsEventNames.paymentSuccess] ?? 0) +
        (eventCounts[AnalyticsEventNames.paymentFailed] ?? 0);
    
    final seatCount = (eventCounts[AnalyticsEventNames.seatAssigned] ?? 0) +
        (eventCounts[AnalyticsEventNames.seatUnassigned] ?? 0);
    
    final utilityCount = (eventCounts[AnalyticsEventNames.studentUtilityUsed] ?? 0) +
        (eventCounts[AnalyticsEventNames.bulkImportUsed] ?? 0);

    final categories = [
      _EventCategory(
        name: 'Memberships',
        icon: Icons.card_membership,
        color: Colors.purple,
        events: [
          AnalyticsEventNames.membershipCreated,
          AnalyticsEventNames.membershipRenewed,
          AnalyticsEventNames.membershipExpired,
        ],
        totalCount: membershipCount,
      ),
      _EventCategory(
        name: 'Attendance',
        icon: Icons.check_circle,
        color: Colors.green,
        events: [
          AnalyticsEventNames.attendanceMarked,
          AnalyticsEventNames.bulkAttendanceMarked,
        ],
        totalCount: attendanceCount,
      ),
      _EventCategory(
        name: 'Invoices',
        icon: Icons.receipt_long,
        color: Colors.orange,
        events: [
          AnalyticsEventNames.invoiceGenerated,
          AnalyticsEventNames.invoiceDownloaded,
          AnalyticsEventNames.invoiceShared,
        ],
        totalCount: invoiceCount,
      ),
      _EventCategory(
        name: 'Payments',
        icon: Icons.payment,
        color: Colors.blue,
        events: [
          AnalyticsEventNames.paymentInitiated,
          AnalyticsEventNames.paymentSuccess,
          AnalyticsEventNames.paymentFailed,
        ],
        totalCount: paymentCount,
      ),
      _EventCategory(
        name: 'Seats',
        icon: Icons.event_seat,
        color: Colors.teal,
        events: [
          AnalyticsEventNames.seatAssigned,
          AnalyticsEventNames.seatUnassigned,
        ],
        totalCount: seatCount,
      ),
      _EventCategory(
        name: 'Utilities',
        icon: Icons.build_circle,
        color: Colors.indigo,
        events: [
          AnalyticsEventNames.studentUtilityUsed,
          AnalyticsEventNames.bulkImportUsed,
        ],
        totalCount: utilityCount,
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.85,
      children: categories.map((category) => _buildCategoryCard(category)).toList(),
    );
  }

  Widget _buildCategoryCard(_EventCategory category) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: category.color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final state = context.read<FeatureAnalyticsCubit>().state;
          _showCategoryDetails(category, state.eventCounts);
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  category.icon,
                  color: category.color,
                  size: 22,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                NumberFormat.compact().format(category.totalCount),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: category.color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                category.name,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopFeatures(Map<String, int> eventCounts) {
    // Get top 5 events by count
    final sortedEntries = eventCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final topEntries = sortedEntries.take(5).toList();
    if (topEntries.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          side: BorderSide(color: Colors.grey[200]!),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppUIConstants.spacingXl),
          child: Center(
            child: Text(
              'No data available',
              style: AppUIConstants.bodyMd.copyWith(
                color: AppUIConstants.textSecondary,
              ),
            ),
          ),
        ),
      );
    }
    
    final features = topEntries.map((entry) {
      final eventName = entry.key;
      final count = entry.value;
      final color = _getEventColor(eventName);
      final displayName = eventName.replaceAll('_', ' ').split(' ').map((word) => 
        word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1)
      ).join(' ');
      
      return _FeatureUsage(displayName, count, eventName, color);
    }).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppUIConstants.spacingLg),
        itemCount: features.length,
        separatorBuilder: (_, _) => const Divider(height: 24),
        itemBuilder: (context, index) {
          final feature = features[index];
          final maxCount = features.first.count;
          final percentage = (feature.count / maxCount * 100).round();

          return Row(
            children: [
              Container(
                width: 8,
                height: 40,
                decoration: BoxDecoration(
                  color: feature.color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: AppUIConstants.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature.name,
                      style: AppUIConstants.bodyMd.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      feature.eventName,
                      style: AppUIConstants.bodySm.copyWith(
                        color: AppUIConstants.textSecondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    NumberFormat('#,###').format(feature.count),
                    style: AppUIConstants.bodyLg.copyWith(
                      fontWeight: FontWeight.bold,
                      color: feature.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$percentage%',
                    style: AppUIConstants.bodySm.copyWith(
                      color: AppUIConstants.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRoleBreakdown(Map<String, int> roleCounts) {
    final total = roleCounts.values.fold<int>(0, (sum, count) => sum + count);
    
    if (total == 0) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          side: BorderSide(color: Colors.grey[200]!),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppUIConstants.spacingXl),
          child: Center(
            child: Text(
              'No data available',
              style: AppUIConstants.bodyMd.copyWith(
                color: AppUIConstants.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    final roles = [
      _RoleUsage(
        'Owner',
        roleCounts['owner'] ?? 0,
        Colors.blue,
        ((roleCounts['owner'] ?? 0) / total * 100).round(),
      ),
      _RoleUsage(
        'Student',
        roleCounts['student'] ?? 0,
        Colors.green,
        ((roleCounts['student'] ?? 0) / total * 100).round(),
      ),
      _RoleUsage(
        'Admin',
        roleCounts['admin'] ?? 0,
        Colors.purple,
        ((roleCounts['admin'] ?? 0) / total * 100).round(),
      ),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppUIConstants.spacingLg),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Events',
                  style: AppUIConstants.bodyMd.copyWith(
                    color: AppUIConstants.textSecondary,
                  ),
                ),
                Text(
                  NumberFormat('#,###').format(total),
                  style: AppUIConstants.headingSm.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppUIConstants.spacingLg),
            ...roles.map((role) => Padding(
              padding: const EdgeInsets.only(bottom: AppUIConstants.spacingMd),
              child: _buildRoleItem(role),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleItem(_RoleUsage role) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: role.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  role.name,
                  style: AppUIConstants.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Text(
              '${NumberFormat('#,###').format(role.eventCount)} (${role.percentage}%)',
              style: AppUIConstants.bodyMd.copyWith(
                fontWeight: FontWeight.w600,
                color: role.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: role.percentage / 100,
            minHeight: 8,
            backgroundColor: role.color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(role.color),
          ),
        ),
      ],
    );
  }

  Widget _buildPlatformBreakdown(Map<String, int> platformCounts) {
    final total = platformCounts.values.fold<int>(0, (sum, count) => sum + count);
    
    final platforms = [
      _PlatformUsage(
        'Android',
        Icons.android,
        platformCounts['android'] ?? 0,
        Colors.green,
        total > 0 ? ((platformCounts['android'] ?? 0) / total * 100).round() : 0,
      ),
      _PlatformUsage(
        'iOS',
        Icons.apple,
        platformCounts['ios'] ?? 0,
        Colors.grey[800]!,
        total > 0 ? ((platformCounts['ios'] ?? 0) / total * 100).round() : 0,
      ),
      _PlatformUsage(
        'Web',
        Icons.web,
        platformCounts['web'] ?? 0,
        Colors.blue,
        total > 0 ? ((platformCounts['web'] ?? 0) / total * 100).round() : 0,
      ),
    ];

    if (total == 0) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          side: BorderSide(color: Colors.grey[200]!),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppUIConstants.spacingXl),
          child: Center(
            child: Text(
              'No data available',
              style: AppUIConstants.bodyMd.copyWith(
                color: AppUIConstants.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: platforms.map((platform) {
        return Expanded(
          child: Card(
            elevation: 0,
            margin: EdgeInsets.only(
              right: platform == platforms.last ? 0 : AppUIConstants.spacingMd,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppUIConstants.spacingLg),
              child: Column(
                children: [
                  Icon(platform.icon, size: 32, color: platform.color),
                  const SizedBox(height: AppUIConstants.spacingSm),
                  Text(
                    platform.name,
                    style: AppUIConstants.bodySm.copyWith(
                      color: AppUIConstants.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppUIConstants.spacingXs),
                  Text(
                    '${platform.eventCount}',
                    style: AppUIConstants.headingMd.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${platform.percentage}%',
                    style: AppUIConstants.bodySm.copyWith(
                      color: AppUIConstants.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentEvents(List<dynamic> recentEvents) {
    if (recentEvents.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          side: BorderSide(color: Colors.grey[200]!),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppUIConstants.spacingXl),
          child: Center(
            child: Text(
              'No recent events',
              style: AppUIConstants.bodyMd.copyWith(
                color: AppUIConstants.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    final events = recentEvents.take(10).map((event) {
      final eventName = event.eventName ?? 'Unknown';
      final displayName = eventName.replaceAll('_', ' ').split(' ').map((word) => 
        word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1)
      ).join(' ');
      
      return _RecentEvent(
        displayName,
        event.role ?? 'unknown',
        event.libraryId ?? 'N/A',
        event.timestamp ?? DateTime.now(),
        _getEventColor(eventName),
      );
    }).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppUIConstants.spacingLg),
        itemCount: events.length,
        separatorBuilder: (_, _) => const Divider(height: 24),
        itemBuilder: (context, index) {
          final event = events[index];
          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: event.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.circle,
                  color: event.color,
                  size: 12,
                ),
              ),
              const SizedBox(width: AppUIConstants.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.eventName,
                      style: AppUIConstants.bodyMd.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${event.role} • ${event.libraryId}',
                      style: AppUIConstants.bodySm.copyWith(
                        color: AppUIConstants.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatTimeAgo(event.timestamp),
                style: AppUIConstants.bodySm.copyWith(
                  color: AppUIConstants.textSecondary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppUIConstants.headingSm.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  String _formatTimeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Color _getEventColor(String eventName) {
    if (eventName.contains('membership')) return Colors.purple;
    if (eventName.contains('attendance')) return Colors.green;
    if (eventName.contains('invoice')) return Colors.orange;
    if (eventName.contains('payment')) return Colors.blue;
    if (eventName.contains('seat')) return Colors.teal;
    if (eventName.contains('utility')) return Colors.indigo;
    return Colors.grey;
  }

  void _showCategoryDetails(_EventCategory category, Map<String, int> eventCounts) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(AppUIConstants.spacingXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(category.icon, color: category.color, size: 28),
                ),
                const SizedBox(width: AppUIConstants.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category.name, style: AppUIConstants.headingSm),
                      Text(
                        '${NumberFormat('#,###').format(category.totalCount)} total events',
                        style: AppUIConstants.bodySm.copyWith(
                          color: AppUIConstants.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppUIConstants.spacingXl),
            Text(
              'Event Breakdown',
              style: AppUIConstants.bodyLg.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppUIConstants.spacingMd),
            Expanded(
              child: ListView.builder(
                itemCount: category.events.length,
                itemBuilder: (context, index) {
                  final event = category.events[index];
                  final count = eventCounts[event] ?? 0;
                  return Card(
                    margin: const EdgeInsets.only(
                      bottom: AppUIConstants.spacingSm,
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: category.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.analytics, color: category.color, size: 20),
                      ),
                      title: Text(
                        event.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text('Event: $event'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: category.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          NumberFormat('#,###').format(count),
                          style: TextStyle(
                            color: category.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Feature Analytics'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This dashboard shows real-time feature usage across your platform.',
              ),
              const SizedBox(height: 16),
              _buildHelpItem(
                'Event Categories',
                'Grouped events by feature type (Memberships, Attendance, etc.)',
              ),
              _buildHelpItem(
                'Top Features',
                'Most frequently used features ranked by event count',
              ),
              _buildHelpItem(
                'Role Breakdown',
                'Event distribution across Admin, Owner, and Student roles',
              ),
              _buildHelpItem(
                'Platform Distribution',
                'Usage across Android, iOS, and Web platforms',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '💡 Tip: Use Firebase Console for detailed queries and custom reports.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 20, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Data models
class _EventCategory {
  final String name;
  final IconData icon;
  final Color color;
  final List<String> events;
  final int totalCount;

  _EventCategory({
    required this.name,
    required this.icon,
    required this.color,
    required this.events,
    required this.totalCount,
  });
}

class _FeatureUsage {
  final String name;
  final int count;
  final String eventName;
  final Color color;

  _FeatureUsage(this.name, this.count, this.eventName, this.color);
}

class _RoleUsage {
  final String name;
  final int eventCount;
  final Color color;
  final int percentage;

  _RoleUsage(this.name, this.eventCount, this.color, this.percentage);
}

class _PlatformUsage {
  final String name;
  final IconData icon;
  final int eventCount;
  final Color color;
  final int percentage;

  _PlatformUsage(
    this.name,
    this.icon,
    this.eventCount,
    this.color,
    this.percentage,
  );
}

class _RecentEvent {
  final String eventName;
  final String role;
  final String libraryId;
  final DateTime timestamp;
  final Color color;

  _RecentEvent(
    this.eventName,
    this.role,
    this.libraryId,
    this.timestamp,
    this.color,
  );
}
