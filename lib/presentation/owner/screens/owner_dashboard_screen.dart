import 'dart:developer' as developer;

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/router/app_router.dart';
import '../../../domain/entities/promo_offer.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/usecases/get_owner_subscription.dart';
import '../../../domain/usecases/promo/promo_usecases.dart';
import '../../auth/cubit/phone_auth_cubit.dart';
import '../../auth/cubit/phone_auth_state.dart';
import '../../core/app_ui_constants.dart';
import '../../student/widgets/profile_completion_banner.dart';
import '../bloc/owner_library_bloc.dart';
import '../bloc/owner_library_event.dart';
import '../bloc/owner_library_state.dart';
import '../cubit/revenue_analytics_cubit.dart';
import '../cubit/subscription_cubit.dart';
import '../widgets/dashboard_widgets.dart';
import '../widgets/owner_header.dart';
import '../widgets/premium_dashboard_widgets.dart';
import '../widgets/promo_popup.dart';
import '../widgets/revenue_analytics_card.dart';
import '../widgets/seat_stats_card.dart';
import '../widgets/subscription_guard.dart';
import '../widgets/tutorial_videos_banner.dart';
import 'owner_dashboard_navigation.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen>
    with OwnerDashboardNavigation {
  bool _isProfilePromptDismissed = false;
  bool _hasLoadedInitially = false;
  bool _hasLoadedSubscription = false;
  bool _hasCheckedPromo = false;
  String? _lastLoadedLibraryId;
  late SubscriptionCubit _subscriptionCubit;

  RevenueAnalyticsCubit? _revenueCubit;
  String? _revenueLibraryId;

  @override
  void onLibraryReloaded() => _loadLibrary();

  @override
  void onRevenueReloaded() => _reloadDashboardRevenue();

  @override
  void initState() {
    super.initState();
    _subscriptionCubit = sl<SubscriptionCubit>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLibrary();
      _hasLoadedInitially = true;
    });
  }

  @override
  void dispose() {
    _revenueCubit?.close();
    _subscriptionCubit.close();
    super.dispose();
  }

  RevenueAnalyticsCubit _revenueCubitForLibrary(String libraryId) {
    if (_revenueCubit == null || _revenueLibraryId != libraryId) {
      _revenueCubit?.close();
      _revenueCubit = sl<RevenueAnalyticsCubit>()..loadAnalytics(libraryId);
      _revenueLibraryId = libraryId;
    }
    return _revenueCubit!;
  }

  void _reloadDashboardRevenue() {
    if (!mounted) return;
    final id = context.read<OwnerLibraryBloc>().state.library?.id;
    if (id == null) return;
    if (_revenueCubit == null || _revenueLibraryId != id) {
      _revenueCubitForLibrary(id);
    } else {
      _revenueCubit!.loadAnalytics(id);
    }
  }

  /// Check and show promotional popup if there's an active promo for this owner.
  Future<void> _checkAndShowPromoPopup({
    required String ownerId,
    required String libraryId,
    required OwnerAccessStatus accessStatus,
  }) async {
    developer.log(
      'Checking promo popup: ownerId=$ownerId, libraryId=$libraryId, '
      'accessStatus=$accessStatus, hasCheckedPromo=$_hasCheckedPromo',
      name: 'OwnerDashboard',
    );

    if (_hasCheckedPromo) return;
    _hasCheckedPromo = true;

    // Map OwnerAccessStatus to PromoTargetAudience
    final audience = _mapAccessStatusToAudience(accessStatus);
    developer.log('Mapped promo audience: $audience', name: 'OwnerDashboard');

    final getActivePromo = sl<GetActivePromo>();
    final result = await getActivePromo(
      ownerId: ownerId,
      libraryId: libraryId,
      ownerAudience: audience,
    );

    result.fold(
      (failure) {
        developer.log(
          'Promo fetch failed: ${failure.message}',
          name: 'OwnerDashboard',
        );
      },
      (promo) {
        developer.log(
          'Promo result: ${promo?.title ?? 'null'}',
          name: 'OwnerDashboard',
        );
        if (promo != null && mounted) {
          _showPromoPopup(promo, ownerId, libraryId);
        }
      },
    );
  }

  PromoTargetAudience _mapAccessStatusToAudience(OwnerAccessStatus status) {
    switch (status) {
      case OwnerAccessStatus.subscriptionActive:
        return PromoTargetAudience.paid;
      case OwnerAccessStatus.freeTier:
      case OwnerAccessStatus.trialActive:
      case OwnerAccessStatus.trialExpired:
        return PromoTargetAudience.freeTier;
      case OwnerAccessStatus.subscriptionExpired:
        return PromoTargetAudience.expired;
      case OwnerAccessStatus.newOwner:
        return PromoTargetAudience.newOwners;
      case OwnerAccessStatus.pendingVerification:
        return PromoTargetAudience.pendingVerification;
    }
  }

  void _showPromoPopup(PromoOffer promo, String ownerId, String libraryId) {
    final recordInteraction = sl<RecordPromoInteraction>();

    // Record view
    recordInteraction(
      promoOfferId: promo.id,
      ownerId: ownerId,
      libraryId: libraryId,
      action: PromoInteractionAction.viewed,
    );

    showPromoPopup(
      context: context,
      promo: promo,
      onDismiss: () {
        // Record dismissal
        recordInteraction(
          promoOfferId: promo.id,
          ownerId: ownerId,
          libraryId: libraryId,
          action: PromoInteractionAction.dismissed,
        );
      },
      onCtaClicked: () {
        // Record click
        recordInteraction(
          promoOfferId: promo.id,
          ownerId: ownerId,
          libraryId: libraryId,
          action: PromoInteractionAction.clicked,
        );
      },
    );
  }

  void _loadLibrary() {
    final user = context.read<PhoneAuthCubit>().state.currentUser;
    if (user != null) {
      _hasLoadedSubscription = false;
      _lastLoadedLibraryId = null;
      context.read<OwnerLibraryBloc>().add(LoadOwnerLibrary(ownerId: user.id));
    }
  }

  void _loadSubscriptionStatus(
    String ownerId,
    String libraryId,
    DateTime? accountCreatedAt,
  ) {
    if (_hasLoadedSubscription && _lastLoadedLibraryId == libraryId) return;

    _hasLoadedSubscription = true;
    _lastLoadedLibraryId = libraryId;
    _subscriptionCubit.loadSubscriptionStatus(
      ownerId,
      libraryCreatedAt: accountCreatedAt,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasLoadedInitially && ModalRoute.of(context)?.isCurrent == true) {
      Future.microtask(() {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          setState(() {});
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PhoneAuthCubit, PhoneAuthState>(
      listener: (context, state) {
        if (state is PhoneAuthSignedOut) context.goToAuth();
      },
      child: BlocProvider.value(
        value: _subscriptionCubit,
        child: BlocListener<SubscriptionCubit, SubscriptionState>(
          listenWhen: (prev, curr) =>
              prev.status != curr.status &&
              (curr.status == SubscriptionStateStatus.loaded ||
                  curr.status == SubscriptionStateStatus.priceCalculated),
          listener: (context, subState) {
            // Check for promo when subscription status is loaded
            final libraryState = context.read<OwnerLibraryBloc>().state;
            final user = context.read<PhoneAuthCubit>().state.currentUser;
            if (libraryState.library != null &&
                user != null &&
                subState.subscriptionStatus != null) {
              _checkAndShowPromoPopup(
                ownerId: user.id,
                libraryId: libraryState.library!.id,
                accessStatus: subState.subscriptionStatus!.accessStatus,
              );
            }
          },
          child: BlocListener<OwnerLibraryBloc, OwnerLibraryState>(
            listenWhen: (prev, curr) =>
                curr.hasLibrary &&
                curr.library != null &&
                curr.status == OwnerLibraryStatus.loaded &&
                prev.isLoading &&
                !curr.isLoading,
            listener: (context, state) => _reloadDashboardRevenue(),
            child: Scaffold(
              backgroundColor: AppUIConstants.background,
              body: BlocBuilder<OwnerLibraryBloc, OwnerLibraryState>(
                builder: (context, state) {
                  final user = context.read<PhoneAuthCubit>().state.currentUser;

                  if (state.library != null && user != null) {
                    _loadSubscriptionStatus(
                      user.id,
                      state.library!.id,
                      user.createdAt,
                    );
                  }

                  return CustomScrollView(
                    slivers: [
                      OwnerHeader(
                        libraryName: state.library?.name,
                        user: user,
                        onRefresh: _loadLibrary,
                        onProfile: () => navigateToProfile(context, user),
                        onSignOut: () => showSignOutDialog(context),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(
                            AppUIConstants.spacingLg,
                          ),
                          child: _buildContent(context, state, user),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    OwnerLibraryState state,
    User? user,
  ) {
    return BlocBuilder<SubscriptionCubit, SubscriptionState>(
      builder: (context, subState) {
        final isStatusLoaded =
            subState.status == SubscriptionStateStatus.loaded ||
            subState.status == SubscriptionStateStatus.priceCalculated ||
            subState.status == SubscriptionStateStatus.error;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.hasLibrary && isStatusLoaded)
              SubscriptionRequiredBanner(
                subscriptionStatus: subState.subscriptionStatus,
                onSubscribe: () =>
                    navigateToSubscription(context, state, subState: subState),
              ),
            _buildProfileBanner(context, user),
            if (state.isLoading) const DashboardLoading(),
            if (state.status == OwnerLibraryStatus.error)
              DashboardErrorView(
                message: state.failure?.message ?? 'Failed to load',
                onRetry: _loadLibrary,
              ),
            if (!state.isLoading &&
                state.status != OwnerLibraryStatus.error) ...[
              if (!state.hasLibrary) ...[
                EmptyLibraryCard(
                  onCreateLibrary: () => navigateToForm(context),
                ),
                const SizedBox(height: AppUIConstants.spacing2Xl),
                TutorialVideosBanner(remoteConfig: sl<FirebaseRemoteConfig>()),
              ],
              if (state.hasLibrary) ...[
                _buildSeatSection(context, state, subState),
                _buildQuickActionsSection(context, state, subState),
                const SizedBox(height: 20),
                _buildRevenueSection(context, state),
                _buildLibraryPhotosSection(context, state),
                const SizedBox(height: 24),
              ],
            ],
          ],
        );
      },
    );
  }

  Widget _buildProfileBanner(BuildContext context, User? user) {
    if (_isProfilePromptDismissed || user == null || user.isProfileComplete) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppUIConstants.spacingLg),
      child: ProfileCompletionBanner(
        user: user,
        onComplete: () => navigateToProfile(context, user),
        onSkip: () => setState(() => _isProfilePromptDismissed = true),
      ),
    );
  }

  Widget _buildLibraryPhotosSection(
    BuildContext context,
    OwnerLibraryState state,
  ) {
    final library = state.library;
    if (library == null) return const SizedBox.shrink();

    return LibraryPhotosSection(
      libraryName: library.name,
      photos: library.photos,
      onPreviewTap: () => navigateToLibraryPreview(context, state),
    );
  }

  Widget _buildSeatSection(
    BuildContext context,
    OwnerLibraryState state,
    SubscriptionState subState,
  ) {
    final hasAccess = subState.subscriptionStatus?.hasAccess ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SeatStatsCard(
          availableSeats: state.stats.availableSeats,
          pendingSeats: state.stats.reservedSeats,
          occupiedSeats: state.occupiedSeats,
          isLocked: !hasAccess,
          onLockedTap: () =>
              showSubscriptionRequired(context, state, subState: subState),
          onTap: () => navigateToSeatOverview(context, state),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRevenueSection(BuildContext context, OwnerLibraryState state) {
    final libraryId = state.library!.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BlocProvider.value(
          value: _revenueCubitForLibrary(libraryId),
          child: RevenueAnalyticsCard(
            libraryId: libraryId,
            onTap: () => navigateToRevenue(context, state),
            onViewCashApprovals: () => navigateToCashApprovals(context, state),
            onViewUpiApprovals: () => navigateToUpiApprovals(context, state),
          ),
        ),
        const SizedBox(height: 20),
        TutorialVideosBanner(remoteConfig: sl<FirebaseRemoteConfig>()),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildQuickActionsSection(
    BuildContext context,
    OwnerLibraryState state,
    SubscriptionState subState,
  ) {
    final hasAccess = subState.subscriptionStatus?.hasAccess ?? false;
    final hasPaidPlan = subState.subscriptionStatus?.hasActivePaidPlan ?? false;
    final isIosApp = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    VoidCallback lockedOr(VoidCallback action) => hasAccess
        ? action
        : () => showSubscriptionRequired(context, state, subState: subState);

    VoidCallback lockedOrPaidReferral(VoidCallback action) => hasPaidPlan
        ? action
        : () => showSubscriptionRequired(context, state, subState: subState);

    const memberColor = Color(0xFF2563EB);
    const bedsColor = Color(0xFF0F766E);
    const invoicesColor = Color(0xFFD97706);
    const subscriptionColor = Color(0xFF7C3AED);
    const notificationColor = Color(0xFFF59E0B);
    const paymentsColor = Color(0xFF4F46E5);
    const referralColor = Color(0xFFE11D48);

    return QuickActionsGridView(
      actions: [
        QuickActionItem(
          icon: Icons.person_add_rounded,
          label: 'New\nMember',
          color: memberColor,
          onTap: lockedOr(() => navigateToMembershipAssignment(context, state)),
          isLocked: !hasAccess,
        ),
        QuickActionItem(
          icon: Icons.bed_rounded,
          label: 'Beds',
          color: bedsColor,
          onTap: lockedOr(() => navigateToSlotManagement(context, state)),
          isLocked: !hasAccess,
        ),
        QuickActionItem(
          icon: Icons.receipt_long_rounded,
          label: 'Invoices',
          color: invoicesColor,
          onTap: lockedOr(() => navigateToInvoices(context, state)),
          isLocked: !hasAccess,
        ),
        QuickActionItem(
          icon: Icons.workspace_premium_rounded,
          label: 'Subscription',
          color: subscriptionColor,
          onTap: () =>
              navigateToSubscription(context, state, subState: subState),
        ),
        QuickActionItem(
          icon: Icons.notifications_active_rounded,
          label: 'Send\nNotification',
          color: notificationColor,
          onTap: lockedOr(() => navigateToNotifications(context, state)),
          isLocked: !hasAccess,
        ),
        QuickActionItem(
          icon: Icons.payment_rounded,
          label: 'Approve\nPayments',
          color: paymentsColor,
          onTap: lockedOr(() => showPaymentOptions(context, state)),
          isLocked: !hasAccess,
        ),
        if (!isIosApp)
          QuickActionItem(
            icon: Icons.card_giftcard_rounded,
            label: 'Refer &\nEarn',
            color: referralColor,
            onTap: lockedOrPaidReferral(
              () => navigateToReferral(context, state, subState),
            ),
            isLocked: !hasPaidPlan,
            badge: 'NEW',
          ),
        QuickActionItem(
          icon: Icons.settings_rounded,
          label: 'Edit\nPG',
          color: AppUIConstants.textSecondary,
          onTap: () => navigateToForm(context),
        ),
      ],
    );
  }
}
