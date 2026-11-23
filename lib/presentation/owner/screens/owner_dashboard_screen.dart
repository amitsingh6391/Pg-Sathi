import 'dart:developer' as developer;

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:unicons/unicons.dart';

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
import 'owner_profile_wrapper.dart';
import '../../../domain/repositories/membership_repository.dart';
import '../widgets/pg_qr/registration_qr_section.dart';
import 'bed_requests_screen.dart';
import 'pg_qr_screen.dart';

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

  /// Library whose pending bed requests were last loaded.
  String? _requestsLibraryId;

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

  /// Number of resident bed requests waiting for approval (grid badge).
  int _pendingRequests = 0;

  Future<void> _loadPendingRequests(String libraryId) async {
    _requestsLibraryId = libraryId;
    final result = await sl<MembershipRepository>()
        .getPendingSeatRequestMemberships(libraryId);
    if (!mounted) return;
    setState(
      () => _pendingRequests = result.fold((_) => 0, (list) => list.length),
    );
  }

  void _reloadDashboardRevenue() {
    if (!mounted) return;
    final id = context.read<OwnerLibraryBloc>().state.library?.id;
    if (id == null) return;
    _loadPendingRequests(id);
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
      context.read<OwnerLibraryBloc>().add(
        LoadOwnerLibrary(
          ownerId: user.ownerAccountId,
          managedLibraryIds: user.isManager ? user.managedLibraryIds : null,
        ),
      );
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
                ownerId: user.ownerAccountId,
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
            child: BlocListener<OwnerLibraryBloc, OwnerLibraryState>(
              listenWhen: (prev, curr) =>
                  curr.library != null &&
                  (prev.stats != curr.stats ||
                      _requestsLibraryId != curr.library!.id),
              listener: (context, state) =>
                  _loadPendingRequests(state.library!.id),
              child: Scaffold(
                backgroundColor: AppUIConstants.background,
                floatingActionButton: _buildNewResidentFab(),
                body: BlocBuilder<OwnerLibraryBloc, OwnerLibraryState>(
                  builder: (context, state) {
                    final user = context
                        .read<PhoneAuthCubit>()
                        .state
                        .currentUser;

                    if (state.library != null && user != null) {
                      _loadSubscriptionStatus(
                        user.ownerAccountId,
                        state.library!.id,
                        user.createdAt,
                      );
                    }

                    return RefreshIndicator(
                      color: AppUIConstants.primary,
                      onRefresh: () async {
                        _loadLibrary();
                        await Future<void>.delayed(
                          const Duration(milliseconds: 700),
                        );
                      },
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          OwnerHeader(
                            libraryName: state.library?.name,
                            user: user,
                            hasMultipleBranches: state.hasMultipleLibraries,
                            onSwitchBranch: state.hasMultipleLibraries
                                ? () => OwnerProfileWrapper.showBranchSwitcher(
                                    context,
                                  )
                                : null,
                            onRefresh: _loadLibrary,
                            onProfile: () => navigateToProfile(context, user),
                            onSignOut: () => showSignOutDialog(context),
                            onPgDetails: state.hasLibrary
                                ? () => navigateToForm(context)
                                : null,
                            onAddBranch:
                                (user?.isManager ?? false) || !state.hasLibrary
                                ? null
                                : () => navigateToAddBranch(context),
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
                      ),
                    );
                  },
                ),
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
                const SizedBox(height: 20),
                RegistrationQrSection(
                  library: state.library!,
                  onOpen: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PgQrScreen(library: state.library!),
                    ),
                  ),
                ),
                _buildActionGrid(context, state, subState),
                const SizedBox(height: 20),
                _buildRevenueSection(context, state),
                const SizedBox(height: 20),
                TutorialVideosBanner(remoteConfig: sl<FirebaseRemoteConfig>()),
                _buildLibraryPhotosSection(context, state),
                // Room for the "New Resident" FAB.
                const SizedBox(height: 88),
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

    return SeatStatsCard(
      availableSeats: state.stats.availableSeats,
      pendingSeats: state.stats.reservedSeats,
      occupiedSeats: state.occupiedSeats,
      isLocked: !hasAccess,
      onLockedTap: () =>
          showSubscriptionRequired(context, state, subState: subState),
      onTap: () => navigateToSeatOverview(context, state),
    );
  }

  Widget _buildRevenueSection(BuildContext context, OwnerLibraryState state) {
    final libraryId = state.library!.id;
    return BlocProvider.value(
      value: _revenueCubitForLibrary(libraryId),
      child: RevenueAnalyticsCard(
        libraryId: libraryId,
        onTap: () => navigateToRevenue(context, state),
        onViewCashApprovals: () => navigateToCashApprovals(context, state),
        onViewUpiApprovals: () => navigateToUpiApprovals(context, state),
      ),
    );
  }

  /// "New Resident" lives in a FAB so the quick-action grid stays two rows.
  Widget _buildNewResidentFab() {
    return BlocBuilder<OwnerLibraryBloc, OwnerLibraryState>(
      builder: (context, state) {
        if (!state.hasLibrary) return const SizedBox.shrink();
        return BlocBuilder<SubscriptionCubit, SubscriptionState>(
          builder: (context, subState) {
            final hasAccess = subState.subscriptionStatus?.hasAccess ?? false;
            return FloatingActionButton.extended(
              heroTag: 'owner_new_resident_fab',
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              onPressed: hasAccess
                  ? () => navigateToMembershipAssignment(context, state)
                  : () => showSubscriptionRequired(
                      context,
                      state,
                      subState: subState,
                    ),
              icon: Icon(
                hasAccess
                    ? Icons.person_add_alt_1_rounded
                    : Icons.lock_outline_rounded,
              ),
              label: const Text(
                'New Resident',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionGrid(
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

    return QuickActionsGridView(
      actions: [
        QuickActionItem(
          icon: Icons.how_to_reg_rounded,
          label: 'Bed\nRequests',
          color: AppUIConstants.accent,
          badge: _pendingRequests,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BedRequestsScreen(library: state.library!),
              ),
            );
            _loadPendingRequests(state.library!.id);
          },
        ),
        QuickActionItem(
          icon: Icons.payments_outlined,
          label: 'Approve\nPayments',
          color: const Color(0xFF6366F1),
          onTap: lockedOr(() => showPaymentOptions(context, state)),
          isLocked: !hasAccess,
        ),
        QuickActionItem(
          icon: Icons.receipt_long_outlined,
          label: 'Invoices',
          color: AppUIConstants.warning,
          onTap: lockedOr(() => navigateToInvoices(context, state)),
          isLocked: !hasAccess,
        ),
        QuickActionItem(
          icon: Icons.workspace_premium_outlined,
          label: 'Subscription',
          color: const Color(0xFFEC4899),
          onTap: () =>
              navigateToSubscription(context, state, subState: subState),
        ),
        QuickActionItem(
          icon: UniconsLine.whatsapp,
          label: 'WhatsApp\nCredits',
          color: const Color(0xFF25D366),
          onTap: () => navigateToWhatsAppCredits(context, state),
        ),
        QuickActionItem(
          icon: Icons.bed_outlined,
          label: 'Room\nTypes',
          color: const Color(0xFF0EA5E9),
          onTap: lockedOr(() => navigateToSlotManagement(context, state)),
          isLocked: !hasAccess,
        ),
        if (!isIosApp)
          QuickActionItem(
            icon: Icons.card_giftcard_rounded,
            label: 'Refer &\nEarn',
            color: AppUIConstants.primary,
            onTap: hasPaidPlan
                ? () => navigateToReferral(context, state, subState)
                : () => showSubscriptionRequired(
                    context,
                    state,
                    subState: subState,
                  ),
            isLocked: !hasPaidPlan,
          ),
      ],
    );
  }
}
