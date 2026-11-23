import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/utils/indian_currency_format.dart';
import '../../../domain/entities/subscription.dart';
import '../../auth/screens/phone_auth_screen.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/admin_analytics_cubit.dart';
import '../cubit/admin_cubit.dart';
import '../cubit/admin_intelligence_cubit.dart';
import '../cubit/withdrawal_approval_cubit.dart';
import '../../core/widgets/premium_kit.dart';
import '../widgets/admin_widgets.dart';
import 'admin_broadcast_screen.dart';
import 'admin_feature_analytics_screen.dart';
import 'admin_invoices_screen.dart';
import 'admin_library_analytics_screen.dart';
import 'admin_owners_details_screen.dart';
import 'admin_promo_management_screen.dart';
import 'admin_students_analytics_screen.dart';
import 'admin_subscriptions_screen.dart';
import 'admin_withdrawal_approvals_screen.dart';
import 'coupon_management_screen.dart';
import 'revenue_intelligence_screen.dart';

/// Admin command center: hero revenue, KPI grid, approvals strip, tool grid
/// and activity feed.
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

  Future<void> _refresh(BuildContext context) async {
    await Future.wait([
      context.read<AdminCubit>().loadDashboard(),
      context.read<AdminAnalyticsCubit>().loadAnalytics(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      body: RefreshIndicator(
        color: AppUIConstants.primaryLight,
        backgroundColor: AppUIConstants.surface,
        onRefresh: () => _refresh(context),
        child: BlocBuilder<AdminAnalyticsCubit, AdminAnalyticsState>(
          builder: (context, analyticsState) {
            return BlocBuilder<AdminCubit, AdminState>(
              builder: (context, adminState) {
                final loading =
                    analyticsState.isLoading || adminState.isLoading;
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    _buildHero(context, analyticsState, adminState, loading),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      child: loading
                          ? const _DashboardSkeleton()
                          : analyticsState.hasError
                          ? _buildError(context, analyticsState)
                          : _buildContent(context, analyticsState, adminState),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHero(
    BuildContext context,
    AdminAnalyticsState analytics,
    AdminState admin,
    bool loading,
  ) {
    return PremiumHero(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppUIConstants.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: AppUIConstants.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PG Sathi Console',
                      style: TextStyle(
                        color: AppUIConstants.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Platform command center',
                      style: TextStyle(
                        color: AppUIConstants.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: AppUIConstants.textSecondary,
                ),
                onPressed: () => _refresh(context),
              ),
              IconButton(
                tooltip: 'Logout',
                icon: const Icon(
                  Icons.logout_rounded,
                  color: AppUIConstants.textSecondary,
                ),
                onPressed: () => _showLogoutDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (loading)
            const _Shimmer(height: 150, radius: 16)
          else ...[
            AdminRevenueCard(
              allSubscriptions: admin.allSubscriptions,
              pendingSubscriptions: admin.pendingSubscriptions,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, AdminAnalyticsState s) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: PremiumCard(
        child: Column(
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: AppUIConstants.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              'Could not load console data',
              style: AppUIConstants.headingSm,
            ),
            const SizedBox(height: 4),
            Text(
              s.errorMessage ?? 'Failed to load',
              textAlign: TextAlign.center,
              style: AppUIConstants.bodySm,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: AppUIConstants.primaryButtonStyle,
              onPressed: () => _refresh(context),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AdminAnalyticsState analytics,
    AdminState admin,
  ) {
    final stats = analytics.dashboardStats;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        // KPI grid
        PremiumTwoColumnGrid(
          children: [
            PremiumStatTile(
              icon: Icons.apartment_rounded,
              value: '${stats.totalLibraries}',
              label: 'Active PGs',
              color: AppUIConstants.primaryLight,
              onTap: () => _navigateToLibraries(context),
            ),
            PremiumStatTile(
              icon: Icons.people_alt_rounded,
              value: '${stats.totalActiveStudents}',
              label: 'Residents',
              color: AppUIConstants.primaryLight,
              onTap: () => _navigateTo(
                context,
                BlocProvider.value(
                  value: context.read<AdminAnalyticsCubit>(),
                  child: const AdminStudentsAnalyticsScreen(),
                ),
              ),
            ),
            PremiumStatTile(
              icon: Icons.badge_rounded,
              value: '${stats.totalActiveOwners}',
              label: 'PG owners',
              color: AppUIConstants.primaryLight,
              onTap: () =>
                  _navigateTo(context, const AdminOwnersDetailsScreen()),
            ),
            PremiumStatTile(
              icon: Icons.workspace_premium_rounded,
              value:
                  '${admin.allSubscriptions.where((s) => s.status == SubscriptionStatus.active).length}',
              label: 'Active plans',
              color: AppUIConstants.primaryLight,
              onTap: () => _openSubscriptions(context),
            ),
          ],
        ),
        if (admin.pendingSubscriptions.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildPendingStrip(context, admin),
        ],
        PremiumSectionHeader('Manage'),
        _buildToolGrid(context, _manageTools(context)),
        PremiumSectionHeader('Money & growth'),
        _buildToolGrid(context, _growthTools(context)),
        const SizedBox(height: 4),
        AdminLibraryGrowth(stats: stats),
        AdminHourlyActivity(activity: analytics.userActivityStats),
        AdminRecentLibraries(
          libraries: analytics.librarySummaries,
          onViewAll: () => _navigateToLibraries(context),
        ),
        AdminUserActivitySection(activity: analytics.userActivityStats),
      ],
    );
  }

  Widget _buildPendingStrip(BuildContext context, AdminState admin) {
    final n = admin.pendingSubscriptions.length;
    final amount = admin.pendingSubscriptions.fold<double>(
      0,
      (sum, s) => sum + s.finalAmount,
    );
    return PremiumCard(
      onTap: () => _openSubscriptions(context),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppUIConstants.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '$n',
              style: TextStyle(
                color: AppUIConstants.warning,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n == 1 ? 'Approval waiting' : 'Approvals waiting',
                  style: AppUIConstants.bodyLg.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Review pending PG plan payments',
                  style: AppUIConstants.bodySm,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${formatIndianRupeeInteger(amount)}',
                style: AppUIConstants.bodyLg.copyWith(
                  color: AppUIConstants.warning,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppUIConstants.textTertiary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<_Tool> _manageTools(BuildContext context) => [
    _Tool(
      Icons.apartment_rounded,
      'PGs',
      AppUIConstants.primaryLight,
      () => _navigateToLibraries(context),
    ),
    _Tool(
      Icons.people_alt_rounded,
      'Residents',
      AppUIConstants.accent,
      () => _navigateTo(
        context,
        BlocProvider.value(
          value: context.read<AdminAnalyticsCubit>(),
          child: const AdminStudentsAnalyticsScreen(),
        ),
      ),
    ),
    _Tool(
      Icons.badge_rounded,
      'Owners',
      AppUIConstants.success,
      () => _navigateTo(context, const AdminOwnersDetailsScreen()),
    ),
    _Tool(
      Icons.account_balance_wallet_rounded,
      'Payouts',
      AppUIConstants.error,
      () => _navigateTo(
        context,
        BlocProvider(
          create: (_) => sl<WithdrawalApprovalCubit>()..load(),
          child: const AdminWithdrawalApprovalsScreen(),
        ),
      ),
    ),
  ];

  List<_Tool> _growthTools(BuildContext context) => [
    _Tool(
      Icons.subscriptions_rounded,
      'Plans',
      AppUIConstants.primaryLight,
      () => _openSubscriptions(context),
    ),
    _Tool(
      Icons.receipt_long_rounded,
      'Invoices',
      AppUIConstants.warning,
      () => _navigateTo(
        context,
        BlocProvider.value(
          value: context.read<AdminAnalyticsCubit>(),
          child: const AdminInvoicesScreen(),
        ),
      ),
    ),
    _Tool(
      Icons.insights_rounded,
      'Revenue',
      AppUIConstants.success,
      () => _navigateTo(
        context,
        BlocProvider(
          create: (_) => sl<AdminIntelligenceCubit>()..loadDashboard(),
          child: const RevenueIntelligenceScreen(),
        ),
      ),
    ),
    _Tool(
      Icons.discount_rounded,
      'Coupons',
      AppUIConstants.accent,
      () => _navigateTo(
        context,
        BlocProvider.value(
          value: context.read<AdminCubit>(),
          child: const CouponManagementScreen(),
        ),
      ),
    ),
    _Tool(
      Icons.local_offer_rounded,
      'Promos',
      AppUIConstants.warning,
      () => _navigateTo(context, const AdminPromoManagementScreen()),
    ),
    _Tool(
      Icons.campaign_rounded,
      'Broadcast',
      AppUIConstants.accent,
      () => _navigateTo(
        context,
        BlocProvider.value(
          value: context.read<AdminAnalyticsCubit>(),
          child: const AdminBroadcastScreen(),
        ),
      ),
    ),
    _Tool(
      Icons.analytics_rounded,
      'Features',
      AppUIConstants.secondary,
      () => _navigateTo(context, const AdminFeatureAnalyticsScreen()),
    ),
  ];

  Widget _buildToolGrid(BuildContext context, List<_Tool> tools) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.88,
      children: [for (final t in tools) _ActionTile(tool: t)],
    );
  }

  void _openSubscriptions(BuildContext context) {
    _navigateTo(
      context,
      BlocProvider.value(
        value: context.read<AdminCubit>(),
        child: const AdminSubscriptionsScreen(),
      ),
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

  void _showLogoutDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppUIConstants.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppUIConstants.disabled,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 20),
              Icon(Icons.logout_rounded, size: 32, color: AppUIConstants.error),
              const SizedBox(height: 12),
              Text('Log out of console?', style: AppUIConstants.headingMd),
              const SizedBox(height: 4),
              Text(
                'You will need to sign in again to manage PGs.',
                style: AppUIConstants.bodySm,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        FirebaseAuth.instance.signOut();
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const PhoneAuthScreen(),
                          ),
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppUIConstants.error,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Logout'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tool {
  const _Tool(this.icon, this.label, this.color, this.onTap);
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _ActionTile extends StatefulWidget {
  const _ActionTile({required this.tool});
  final _Tool tool;

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tool;
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.94 : 1,
        duration: const Duration(milliseconds: 110),
        child: Material(
          color: AppUIConstants.surface,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          child: InkWell(
            onTap: t.onTap,
            borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
                border: Border.all(color: AppUIConstants.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppUIConstants.surfaceMuted,
                    ),
                    child: Icon(
                      t.icon,
                      color: AppUIConstants.primaryLight,
                      size: 21,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.label,
                    style: AppUIConstants.bodySm.copyWith(
                      color: AppUIConstants.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _Shimmer(height: 92)),
            SizedBox(width: 12),
            Expanded(child: _Shimmer(height: 92)),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _Shimmer(height: 92)),
            SizedBox(width: 12),
            Expanded(child: _Shimmer(height: 92)),
          ],
        ),
        SizedBox(height: 20),
        _Shimmer(height: 150),
        SizedBox(height: 16),
        _Shimmer(height: 150),
      ],
    );
  }
}

class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.height, this.radius = 20});
  final double height;
  final double radius;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(
            AppUIConstants.surface,
            AppUIConstants.surfaceMuted,
            _c.value,
          ),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}
