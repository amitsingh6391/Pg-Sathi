import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/router/app_router.dart';
import '../../../domain/entities/user.dart';
import '../../auth/cubit/phone_auth_cubit.dart';
import '../../auth/cubit/phone_auth_state.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/student_home_cubit.dart';
import '../cubit/student_home_state.dart';
import '../home/home_navigator.dart';
import '../home/membership_groups.dart';
import '../widgets/home/home_featured_membership.dart';
import '../widgets/home/home_quick_actions_section.dart';
import '../widgets/home/past_memberships.dart';
import '../widgets/home_dashboard_widgets.dart';
import '../widgets/no_membership_card.dart';
import '../widgets/profile_completion_banner.dart';
import '../widgets/sync_memberships_banner.dart';
import 'profile_form_screen.dart';
import 'profile_screen.dart';

/// Student home screen focused on PG stays and tenant account actions.
class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({
    super.key,
    required this.userId,
    this.onOpenExploreTab,
  });

  final String userId;

  /// Switches the shell to the Explore tab (null when pushed standalone).
  final VoidCallback? onOpenExploreTab;

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  /// Stay chosen in the header switcher (null = most urgent).
  String? _selectedMembershipId;

  late final StudentHomeNavigator _navigator = StudentHomeNavigator(
    userId: widget.userId,
    onRefresh: () {
      if (mounted) _refreshDashboard(context);
    },
  );

  @override
  Widget build(BuildContext context) {
    return BlocListener<PhoneAuthCubit, PhoneAuthState>(
      listener: (context, state) {
        state.mapOrNull(signedOut: (_) => context.goToAuth());
      },
      child: Scaffold(
        backgroundColor: AppUIConstants.background,
        body: BlocConsumer<StudentHomeCubit, StudentHomeState>(
          listener: _handleStateChanges,
          builder: (context, state) {
            if (state.isLoading) {
              return const _StudentHomeSkeleton();
            }

            final groups = groupMemberships(
              state.memberships,
              selectedId: _selectedMembershipId,
            );
            return RefreshIndicator(
              onRefresh: () async {
                _refreshDashboard(context);
              },
              color: AppUIConstants.primaryLight,
              backgroundColor: AppUIConstants.surface,
              edgeOffset: MediaQuery.of(context).padding.top,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  StudentDashboardHeader(
                    user: state.user,
                    onRefresh: () => _refreshDashboard(context),
                    onProfile: state.user != null
                        ? () => _navigateToProfile(context, state.user!)
                        : null,
                    onSignOut: () => _showSignOutDialog(context),
                    figure: groups.featured == null
                        ? null
                        : HomeFeaturedMembership(
                            groups: groups,
                            userId: widget.userId,
                            navigator: _navigator,
                            onSelected: (id) =>
                                setState(() => _selectedMembershipId = id),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildContent(context, state, groups),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // Content Sections
  // ===========================================================================

  Widget _buildContent(
    BuildContext context,
    StudentHomeState state,
    MembershipGroups groups,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        HomeReveal(child: _buildBanners(context, state)),
        if (groups.featured == null)
          HomeReveal(
            index: 1,
            child: NoMembershipCard(
              onExplore: state.canShowExploreLibraries
                  ? widget.onOpenExploreTab
                  : null,
            ),
          )
        else ...[
          HomeReveal(
            index: 1,
            child: HomeQuickActionsSection(
              memberships: groups.all,
              documentStatus: state.documentStatus,
              navigator: _navigator,
            ),
          ),
          if (groups.past.isNotEmpty)
            HomeReveal(
              index: 2,
              child: PastMembershipsRow(
                past: groups.past,
                userId: widget.userId,
                navigator: _navigator,
              ),
            ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildBanners(BuildContext context, StudentHomeState state) {
    return Column(
      children: [
        if (state.shouldShowProfilePrompt && state.user != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ProfileCompletionBanner(
              user: state.user!,
              onComplete: () =>
                  _navigateToProfileCompletion(context, state.user!),
              onSkip: () =>
                  context.read<StudentHomeCubit>().dismissProfilePrompt(),
            ),
          ),
        if (state.hasUnregisteredMemberships &&
            !state.isSyncBannerDismissed &&
            state.user != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SyncMembershipsBanner(
              onSync: () => _syncMemberships(context, state.user!),
              onDismiss: () =>
                  context.read<StudentHomeCubit>().dismissSyncBanner(),
            ),
          ),
      ],
    );
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  void _handleStateChanges(BuildContext context, StudentHomeState state) {
    if (state.isFailure && state.failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.failure!.message ?? 'Something went wrong'),
          backgroundColor: AppUIConstants.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
          ),
        ),
      );
    }
  }

  void _refreshDashboard(BuildContext context) {
    context.read<StudentHomeCubit>().loadDashboard(userId: widget.userId);
  }

  void _syncMemberships(BuildContext context, User user) {
    if (user.phone.isEmpty) return;
    context.read<StudentHomeCubit>().syncMemberships(
      userId: user.id,
      phoneNumber: user.phone,
    );
  }

  // ===========================================================================
  // Navigation
  // ===========================================================================

  void _navigateToProfileCompletion(BuildContext ctx, User user) async {
    final updated = await Navigator.of(ctx).push<User>(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<ProfileCubit>(),
          child: ProfileFormScreen(user: user, isInitialSetup: true),
        ),
      ),
    );
    if (updated != null && ctx.mounted) {
      ctx.read<PhoneAuthCubit>().updateUser(updated);
      _refreshDashboard(ctx);
    }
  }

  void _navigateToProfile(BuildContext ctx, User user) async {
    final updated = await Navigator.of(ctx).push<User>(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<ProfileCubit>(),
          child: ProfileScreen(user: user),
        ),
      ),
    );
    if (updated != null && ctx.mounted) {
      ctx.read<PhoneAuthCubit>().updateUser(updated);
      _refreshDashboard(ctx);
    }
  }

  void _showSignOutDialog(BuildContext ctx) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: AppUIConstants.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppUIConstants.radiusXl),
        ),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppUIConstants.error.withValues(alpha: 0.14),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: AppUIConstants.error,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sign out of PG Sathi?',
                style: AppUIConstants.headingMd,
              ),
              const SizedBox(height: 6),
              const Text(
                'You can sign back in anytime with your phone number.',
                style: AppUIConstants.bodyMd,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppUIConstants.textSecondary,
                        side: const BorderSide(color: AppUIConstants.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppUIConstants.radiusMd,
                          ),
                        ),
                      ),
                      child: const Text('Stay signed in'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(sheetCtx).pop();
                        ctx.read<PhoneAuthCubit>().signOut();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppUIConstants.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppUIConstants.radiusMd,
                          ),
                        ),
                      ),
                      child: const Text('Sign out'),
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

class _StudentHomeSkeleton extends StatefulWidget {
  const _StudentHomeSkeleton();

  @override
  State<_StudentHomeSkeleton> createState() => _StudentHomeSkeletonState();
}

class _StudentHomeSkeletonState extends State<_StudentHomeSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + 16,
              20,
              24,
            ),
            decoration: const BoxDecoration(
              color: AppUIConstants.surface,
              border: Border(bottom: BorderSide(color: AppUIConstants.border)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _Bone(width: 48, height: 48, radius: 24, anim: _anim),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Bone(width: 90, height: 10, anim: _anim),
                        const SizedBox(height: 8),
                        _Bone(width: 150, height: 16, anim: _anim),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _Bone(
                  width: double.infinity,
                  height: 128,
                  radius: AppUIConstants.radiusLg,
                  anim: _anim,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Bone(width: 120, height: 16, anim: _anim),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _Bone(height: 64, radius: 20, anim: _anim)),
                    const SizedBox(width: 10),
                    Expanded(child: _Bone(height: 64, radius: 20, anim: _anim)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _Bone(height: 64, radius: 20, anim: _anim)),
                    const SizedBox(width: 10),
                    Expanded(child: _Bone(height: 64, radius: 20, anim: _anim)),
                  ],
                ),
                const SizedBox(height: 24),
                _Bone(width: 100, height: 16, anim: _anim),
                const SizedBox(height: 12),
                _Bone(
                  width: double.infinity,
                  height: 220,
                  radius: AppUIConstants.radiusLg,
                  anim: _anim,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bone extends StatelessWidget {
  const _Bone({
    required this.anim,
    required this.height,
    this.width,
    this.radius = 12,
  });

  final Animation<double> anim;
  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment(anim.value - 1, 0),
          end: Alignment(anim.value + 1, 0),
          colors: const [
            AppUIConstants.surfaceMuted,
            AppUIConstants.border,
            AppUIConstants.surfaceMuted,
          ],
        ),
      ),
    );
  }
}
