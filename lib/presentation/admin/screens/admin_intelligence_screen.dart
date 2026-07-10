import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../auth/screens/phone_auth_screen.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/admin_analytics_cubit.dart';
import '../cubit/admin_cubit.dart';
import '../cubit/admin_intelligence_cubit.dart';
import '../cubit/current_affairs_management_cubit.dart';
import '../cubit/withdrawal_approval_cubit.dart';
import '../widgets/admin_widgets.dart';
import 'admin_affiliate_analytics_screen.dart';
import 'admin_broadcast_screen.dart';
import 'admin_feature_analytics_screen.dart';
import 'admin_invoices_screen.dart';
import 'admin_library_analytics_screen.dart';
import 'admin_owners_details_screen.dart';
import 'admin_promo_management_screen.dart';
import 'jobs/admin_jobs_screen.dart';
import 'admin_students_analytics_screen.dart';
import 'admin_subscriptions_screen.dart';
import 'admin_withdrawal_approvals_screen.dart';
import 'coupon_management_screen.dart';
import 'current_affairs_management_screen.dart';
import 'revenue_intelligence_screen.dart';

/// Clean minimal Admin Dashboard - Revamped.
class AdminIntelligenceScreen extends StatelessWidget {
  const AdminIntelligenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<AdminCubit>()..loadDashboard()),
        BlocProvider(create: (_) => sl<AdminAnalyticsCubit>()..loadAnalytics()),
      ],
      child: const _AdminDashboardView(),
    );
  }
}

class _AdminDashboardView extends StatelessWidget {
  const _AdminDashboardView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: AppUIConstants.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => _refresh(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(context),
        child: _buildBody(context),
      ),
    );
  }

  Future<void> _refresh(BuildContext context) async {
    await Future.wait([
      context.read<AdminCubit>().loadDashboard(),
      context.read<AdminAnalyticsCubit>().loadAnalytics(),
    ]);
  }

  Widget _buildBody(BuildContext context) {
    return BlocBuilder<AdminAnalyticsCubit, AdminAnalyticsState>(
      builder: (context, analyticsState) {
        return BlocBuilder<AdminCubit, AdminState>(
          builder: (context, adminState) {
            if (analyticsState.isLoading || adminState.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (analyticsState.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: AppUIConstants.error),
                    const SizedBox(height: 16),
                    Text(analyticsState.errorMessage ?? 'Failed to load'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _refresh(context),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Pending Approvals Alert
                if (adminState.pendingSubscriptions.isNotEmpty)
                  _buildPendingAlert(context, adminState),

                // Revenue Card
                AdminRevenueCard(
                  allSubscriptions: adminState.allSubscriptions,
                  pendingSubscriptions: adminState.pendingSubscriptions,
                ),
                const SizedBox(height: 16),

                // Library Growth
                AdminLibraryGrowth(stats: analyticsState.dashboardStats),
                const SizedBox(height: 16),

                // Hourly Activity
                AdminHourlyActivity(activity: analyticsState.userActivityStats),
                const SizedBox(height: 16),

                // More Tools
                _buildSectionHeader('More Tools'),
                const SizedBox(height: 12),
                _buildMoreToolsGrid(context),

                // Recent Libraries
                AdminRecentLibraries(
                  libraries: analyticsState.librarySummaries,
                  onViewAll: () => _navigateToLibraries(context),
                ),
                const SizedBox(height: 16),

                // User Activity
                AdminUserActivitySection(activity: analyticsState.userActivityStats),
                const SizedBox(height: 16),

                // Platform Stats Row (Libraries, Students, Owners)
                _buildPlatformStats(analyticsState),
                const SizedBox(height: 16),

                // Quick Actions
                _buildSectionHeader('Quick Actions'),
                const SizedBox(height: 12),
                _buildQuickActionsGrid(context),
                const SizedBox(height: 32),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPendingAlert(BuildContext context, AdminState adminState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppUIConstants.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppUIConstants.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppUIConstants.warning.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.pending_actions_rounded, color: AppUIConstants.warning, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${adminState.pendingSubscriptions.length} Pending Approval${adminState.pendingSubscriptions.length > 1 ? 's' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  'Tap to review',
                  style: TextStyle(color: AppUIConstants.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _navigateTo(
              context,
              BlocProvider.value(
                value: context.read<AdminCubit>(),
                child: const AdminSubscriptionsScreen(),
              ),
            ),
            child: Text('View', style: TextStyle(color: AppUIConstants.warning)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformStats(AdminAnalyticsState analyticsState) {
    final stats = analyticsState.dashboardStats;
    return Row(
      children: [
        _buildStatCard(
          icon: Icons.business_rounded,
          label: 'Libraries',
          value: '${stats.totalLibraries}',
          color: AppUIConstants.success,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          icon: Icons.school_rounded,
          label: 'Students',
          value: '${stats.totalActiveStudents}',
          color: AppUIConstants.accent,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          icon: Icons.person_rounded,
          label: 'Owners',
          value: '${stats.totalActiveOwners}',
          color: AppUIConstants.secondary,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppUIConstants.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppUIConstants.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: AppUIConstants.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
  }

  /// Quick Actions: 6 tiles in a 2×3 grid. The most-used scopes
  /// (libraries / students / owners) plus the affiliate-program
  /// operations (withdraw / affiliates) and content (articles).
  /// Anything money- or marketing-related lives in More Tools.
  Widget _buildQuickActionsGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.95,
      children: [
        _ActionTile(
          icon: Icons.business_rounded,
          label: 'Libraries',
          color: AppUIConstants.success,
          onTap: () => _navigateToLibraries(context),
        ),
        _ActionTile(
          icon: Icons.people_rounded,
          label: 'Students',
          color: AppUIConstants.accent,
          onTap: () => _navigateTo(
            context,
            BlocProvider.value(
              value: context.read<AdminAnalyticsCubit>(),
              child: const AdminStudentsAnalyticsScreen(),
            ),
          ),
        ),
        _ActionTile(
          icon: Icons.person_outline_rounded,
          label: 'Owners',
          color: AppUIConstants.secondary,
          onTap: () => _navigateTo(context, const AdminOwnersDetailsScreen()),
        ),
        _ActionTile(
          icon: Icons.account_balance_wallet_rounded,
          label: 'Withdraw',
          color: AppUIConstants.error,
          onTap: () => _navigateTo(
            context,
            BlocProvider(
              create: (_) => sl<WithdrawalApprovalCubit>()..load(),
              child: const AdminWithdrawalApprovalsScreen(),
            ),
          ),
        ),
        _ActionTile(
          icon: Icons.handshake_rounded,
          label: 'Affiliates',
          color: AppUIConstants.success,
          onTap: () =>
              _navigateTo(context, const AdminAffiliateAnalyticsScreen()),
        ),
        _ActionTile(
          icon: Icons.newspaper_rounded,
          label: 'Articles',
          color: AppUIConstants.secondary,
          onTap: () => _navigateToCurrentAffairs(context),
        ),
      ],
    );
  }

  /// More Tools: exactly 8 tiles in a 2×4 grid. Money / billing on the
  /// top row, marketing + ops on the bottom. Hard cap at 8 — anything
  /// new must displace an existing tile (or move to Quick Actions if
  /// it's a frequent task).
  Widget _buildMoreToolsGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.85,
      children: [
        // Row 1 — money / billing
        _ActionTile(
          icon: Icons.subscriptions_rounded,
          label: 'Subs',
          color: AppUIConstants.primary,
          onTap: () => _navigateTo(
            context,
            BlocProvider.value(
              value: context.read<AdminCubit>(),
              child: const AdminSubscriptionsScreen(),
            ),
          ),
        ),
        _ActionTile(
          icon: Icons.receipt_long_rounded,
          label: 'Invoices',
          color: AppUIConstants.warning,
          onTap: () => _navigateTo(
            context,
            BlocProvider.value(
              value: context.read<AdminAnalyticsCubit>(),
              child: const AdminInvoicesScreen(),
            ),
          ),
        ),
        _ActionTile(
          icon: Icons.bar_chart_rounded,
          label: 'Revenue',
          color: AppUIConstants.primary,
          onTap: () => _navigateTo(
            context,
            BlocProvider(
              create: (_) => sl<AdminIntelligenceCubit>()..loadDashboard(),
              child: const RevenueIntelligenceScreen(),
            ),
          ),
        ),
        _ActionTile(
          icon: Icons.discount_rounded,
          label: 'Coupons',
          color: AppUIConstants.accent,
          onTap: () => _navigateTo(
            context,
            BlocProvider.value(
              value: context.read<AdminCubit>(),
              child: const CouponManagementScreen(),
            ),
          ),
        ),
        // Row 2 — marketing / ops
        _ActionTile(
          icon: Icons.local_offer_rounded,
          label: 'Promos',
          color: AppUIConstants.warning,
          onTap: () => _navigateTo(context, const AdminPromoManagementScreen()),
        ),
        _ActionTile(
          icon: Icons.campaign_rounded,
          label: 'Broadcast',
          color: AppUIConstants.warning,
          onTap: () => _navigateTo(
            context,
            BlocProvider.value(
              value: context.read<AdminAnalyticsCubit>(),
              child: const AdminBroadcastScreen(),
            ),
          ),
        ),
        _ActionTile(
          icon: Icons.analytics_rounded,
          label: 'Features',
          color: AppUIConstants.secondary,
          onTap: () =>
              _navigateTo(context, const AdminFeatureAnalyticsScreen()),
        ),
        _ActionTile(
          icon: Icons.work_outline_rounded,
          label: 'Jobs',
          color: AppUIConstants.accent,
          onTap: () => _navigateToJobs(context),
        ),
      ],
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _navigateToLibraries(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<AdminAnalyticsCubit>(),
          child: const AdminLibraryAnalyticsScreen(),
        ),
      ),
    );
  }

  void _navigateToCurrentAffairs(BuildContext context) {
    final adminId = FirebaseAuth.instance.currentUser?.uid ?? '';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<CurrentAffairsManagementCubit>(),
          child: CurrentAffairsManagementScreen(adminId: adminId),
        ),
      ),
    );
  }

  void _navigateToJobs(BuildContext context) {
    final adminId = FirebaseAuth.instance.currentUser?.uid ?? '';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminJobsScreen(adminId: adminId),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              FirebaseAuth.instance.signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppUIConstants.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
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
      color: AppUIConstants.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppUIConstants.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
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
}
