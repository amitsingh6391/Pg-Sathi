import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/router/app_router.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/usecases/get_student_memberships.dart';
import '../../auth/cubit/phone_auth_cubit.dart';
import '../../auth/cubit/phone_auth_state.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/attendance_history_cubit.dart';
import '../cubit/invoice_cubit.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/student_home_cubit.dart';
import '../cubit/student_home_state.dart';
import '../cubit/student_payment_cubit.dart';
import '../widgets/home_dashboard_widgets.dart';
import '../widgets/no_membership_card.dart';
import '../widgets/profile_completion_banner.dart';
import '../widgets/sync_memberships_banner.dart';
import '../widgets/unified_membership_card.dart';
import 'attendance_details_screen.dart';
import 'invoices_screen.dart';
import 'library_details_screen.dart';
import 'payment_screen.dart';
import 'profile_form_screen.dart';
import 'profile_screen.dart';
import 'student_documents_screen.dart';

/// Student home screen focused on PG stays and tenant account actions.
class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key, required this.userId});

  final String userId;

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
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

            return Column(
              children: [
                StudentDashboardHeader(
                  user: state.user,
                  onRefresh: () => _refreshDashboard(context),
                  onProfile: state.user != null
                      ? () => _navigateToProfile(context, state.user!)
                      : null,
                  onSignOut: () => _showSignOutDialog(context),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      _refreshDashboard(context);
                    },
                    color: AppUIConstants.primary,
                    backgroundColor: AppUIConstants.surface,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      children: [_buildContent(context, state)],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // Content Sections
  // ===========================================================================

  Widget _buildContent(BuildContext context, StudentHomeState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        // Banners (profile completion, sync memberships)
        _buildBanners(context, state),

        // Memberships
        _buildMembershipsSection(context, state),
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

  Widget _buildMembershipsSection(
    BuildContext context,
    StudentHomeState state,
  ) {
    if (!state.hasMemberships) return const NoMembershipCard();

    final merged = _mergeMemberships(state.memberships);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'My Memberships',
          trailing: Text(
            '${merged.length}',
            style: TextStyle(
              color: AppUIConstants.textTertiary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 14),
        ...merged.map((info) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: UnifiedMembershipCard(
              info: info,
              userId: widget.userId,
              documentStatus: state.documentStatus,
              onCardTap: info.library != null
                  ? () => info.isPendingPayment
                        ? _navigateToPayment(context, info)
                        : _navigateToLibraryDetails(context, info)
                  : null,
              onViewAttendance: info.isActive && info.library != null
                  ? () => _navigateToAttendance(context, info)
                  : null,
              onViewInvoices: info.isActive
                  ? () => _navigateToInvoices(context)
                  : null,
              onViewDocuments: info.isActive
                  ? () => _navigateToDocuments(context)
                  : null,
            ),
          );
        }),
        const SizedBox(height: 8),
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

  List<StudentMembershipInfo> _mergeMemberships(
    List<StudentMembershipInfo> memberships,
  ) {
    final merged = <String, StudentMembershipInfo>{};

    for (final info in memberships) {
      final slot = info.displaySlot;
      final slotKey = slot != null
          ? slot.name
          : (info.customSlot?.id ?? 'unknown');
      final key = '${info.membership.libraryId}_$slotKey';

      if (!merged.containsKey(key)) {
        merged[key] = info;
        continue;
      }

      final existing = merged[key]!;
      StudentMembershipInfo primary = existing;
      StudentMembershipInfo other = info;

      if (!existing.isActive && info.isActive) {
        primary = info;
        other = existing;
      } else if (existing.isActive && !info.isActive) {
        primary = existing;
        other = info;
      } else {
        if (info.membership.startDate.isBefore(existing.membership.startDate)) {
          primary = info;
          other = existing;
        }
      }

      var upcoming = primary.upcomingMembership;
      if (upcoming == null) {
        if (other.membership.startDate.isAfter(primary.membership.startDate)) {
          upcoming = other.membership;
        } else if (other.upcomingMembership != null) {
          upcoming = other.upcomingMembership;
        }
      } else {
        final candidate =
            other.upcomingMembership ??
            (other.membership.startDate.isAfter(primary.membership.startDate)
                ? other.membership
                : null);
        if (candidate != null &&
            candidate.startDate.isBefore(upcoming.startDate)) {
          upcoming = candidate;
        }
      }

      merged[key] = StudentMembershipInfo(
        membership: primary.membership,
        library: primary.library,
        libraryName: primary.libraryName,
        customSlot: primary.customSlot,
        daysRemaining: primary.daysRemaining,
        isPendingPayment: primary.isPendingPayment,
        isActive: primary.isActive,
        isExpired: primary.isExpired,
        upcomingMembership: upcoming,
      );
    }

    return merged.values.toList();
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

  void _navigateToPayment(BuildContext ctx, StudentMembershipInfo info) async {
    final result = await Navigator.of(ctx).push<bool>(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<StudentPaymentCubit>(),
          child: PaymentScreen(membershipInfo: info),
        ),
      ),
    );
    if (result == true && ctx.mounted) _refreshDashboard(ctx);
  }

  void _navigateToLibraryDetails(BuildContext ctx, StudentMembershipInfo info) {
    if (info.library == null) return;
    Navigator.of(ctx).push(
      MaterialPageRoute(
        builder: (_) => LibraryDetailsScreen(
          library: info.library!,
          membershipInfo: info,
          userId: widget.userId,
        ),
      ),
    );
  }

  void _navigateToAttendance(BuildContext ctx, StudentMembershipInfo info) {
    if (info.library == null) return;
    Navigator.of(ctx).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<AttendanceHistoryCubit>(),
          child: AttendanceDetailsScreen(
            userId: widget.userId,
            libraryId: info.library!.id,
            libraryName: info.library!.name,
          ),
        ),
      ),
    );
  }

  void _navigateToDocuments(BuildContext ctx) {
    Navigator.of(ctx)
        .push(
          MaterialPageRoute(
            builder: (_) => StudentDocumentsScreen(studentId: widget.userId),
          ),
        )
        .then((_) {
          if (ctx.mounted) _refreshDashboard(ctx);
        });
  }

  void _navigateToInvoices(BuildContext ctx) {
    Navigator.of(ctx).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<InvoiceCubit>(),
          child: InvoicesScreen(userId: widget.userId),
        ),
      ),
    );
  }

  void _showSignOutDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppUIConstants.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        ),
        title: Text('Sign Out', style: AppUIConstants.headingMd),
        content: Text(
          'Are you sure you want to sign out?',
          style: AppUIConstants.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppUIConstants.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              ctx.read<PhoneAuthCubit>().signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppUIConstants.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
              ),
            ),
            child: const Text('Sign Out'),
          ),
        ],
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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
        children: [
          _Bone(width: double.infinity, height: 56, anim: _anim),
          const SizedBox(height: 16),
          _Bone(width: double.infinity, height: 100, anim: _anim),
          const SizedBox(height: 16),
          _Bone(width: double.infinity, height: 120, anim: _anim),
          const SizedBox(height: 12),
          _Bone(width: double.infinity, height: 120, anim: _anim),
          const SizedBox(height: 16),
          _Bone(width: 160, height: 18, anim: _anim),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _Bone(height: 110, anim: _anim)),
              const SizedBox(width: 12),
              Expanded(child: _Bone(height: 110, anim: _anim)),
            ],
          ),
          const SizedBox(height: 16),
          _Bone(width: 160, height: 18, anim: _anim),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _Bone(height: 90, anim: _anim)),
              const SizedBox(width: 12),
              Expanded(child: _Bone(height: 90, anim: _anim)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bone extends StatelessWidget {
  const _Bone({required this.anim, required this.height, this.width});

  final Animation<double> anim;
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment(anim.value - 1, 0),
          end: Alignment(anim.value + 1, 0),
          colors: const [
            Color(0xFFE8EEF4),
            Color(0xFFD0DCE8),
            Color(0xFFE8EEF4),
          ],
        ),
      ),
    );
  }
}
