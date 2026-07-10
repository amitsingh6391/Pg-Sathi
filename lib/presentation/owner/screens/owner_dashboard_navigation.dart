import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/user.dart';
import '../../auth/cubit/phone_auth_cubit.dart';
import '../../core/app_ui_constants.dart';
import '../../student/cubit/profile_cubit.dart';
import '../../student/screens/profile_screen.dart';
import '../bloc/owner_library_bloc.dart';
import '../bloc/owner_library_event.dart';
import '../bloc/owner_library_state.dart';
import '../cubit/cash_approval_cubit.dart';
import '../cubit/expense_cubit.dart';
import '../cubit/membership_assignment_cubit.dart';
import '../cubit/occupied_seats_cubit.dart';
import '../cubit/owner_invoice_cubit.dart';
import '../cubit/referral_cubit.dart';
import '../cubit/revenue_analytics_cubit.dart';
import '../cubit/subscription_cubit.dart';
import 'cash_approvals_screen.dart';
import 'library_form_screen.dart';
import 'library_preview_screen.dart';
import 'membership_assignment_screen.dart';
import 'occupied_seats_screen.dart';
import 'owner_in_app_purchase_screen.dart';
import 'owner_invoices_screen.dart';
import 'payment_approvals_screen.dart';
import 'referral_screen.dart';
import 'revenue_analytics_screen.dart';
import 'unified_notifications_screen.dart';
import 'upi_approvals_screen.dart';

/// Extracted navigation methods for the owner dashboard.
///
/// Keeps the main dashboard file focused on layout and state,
/// while all routing / dialog logic lives here.
mixin OwnerDashboardNavigation<T extends StatefulWidget> on State<T> {
  void onLibraryReloaded();
  void onRevenueReloaded();

  Future<void> navigateToForm(BuildContext context) async {
    final user = context.read<PhoneAuthCubit>().state.currentUser;
    if (user == null) return;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            LibraryFormScreen(ownerId: user.id, ownerPhone: user.phone),
      ),
    );

    if (result == true && context.mounted) onLibraryReloaded();
  }

  Future<void> navigateToSeatOverview(
    BuildContext context,
    OwnerLibraryState state,
  ) async {
    if (state.library == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<OccupiedSeatsCubit>(),
          child: OccupiedSeatsScreen(library: state.library!),
        ),
      ),
    );

    if (context.mounted) {
      context.read<OwnerLibraryBloc>().add(const RefreshLibraryStats());
      onRevenueReloaded();
    }
  }

  Future<void> navigateToMembershipAssignment(
    BuildContext context,
    OwnerLibraryState state,
  ) async {
    if (state.library == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<MembershipAssignmentCubit>(),
          child: MembershipAssignmentScreen(library: state.library!),
        ),
      ),
    );

    if (context.mounted) {
      context.read<OwnerLibraryBloc>().add(const RefreshLibraryStats());
      onRevenueReloaded();
    }
  }

  Future<void> navigateToLibraryPreview(
    BuildContext context,
    OwnerLibraryState state,
  ) async {
    if (state.library == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LibraryPreviewScreen(
          library: state.library!,
          availableSeats: state.stats.availableSeats,
          totalSeats: state.stats.totalSeats,
        ),
      ),
    );
  }

  Future<void> navigateToInvoices(
    BuildContext context,
    OwnerLibraryState state,
  ) async {
    if (state.library == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<OwnerInvoiceCubit>(),
          child: OwnerInvoicesScreen(
            ownerId: state.library!.ownerId,
            libraryName: state.library!.name,
          ),
        ),
      ),
    );
  }

  Future<void> navigateToCashApprovals(
    BuildContext context,
    OwnerLibraryState state,
  ) async {
    if (state.library == null) return;

    final hasChanges = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<CashApprovalCubit>(),
          child: CashApprovalsScreen(
            libraryId: state.library!.id,
            ownerId: state.library!.ownerId,
            libraryName: state.library!.name,
          ),
        ),
      ),
    );

    if (hasChanges == true && context.mounted) onLibraryReloaded();
  }

  Future<void> navigateToUpiApprovals(
    BuildContext context,
    OwnerLibraryState state,
  ) async {
    if (state.library == null) return;

    final hasChanges = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<CashApprovalCubit>(),
          child: UpiApprovalsScreen(
            libraryId: state.library!.id,
            ownerId: state.library!.ownerId,
            libraryName: state.library!.name,
          ),
        ),
      ),
    );

    if (hasChanges == true && context.mounted) onLibraryReloaded();
  }

  Future<void> navigateToRevenue(
    BuildContext context,
    OwnerLibraryState state,
  ) async {
    if (state.library == null) return;

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => sl<RevenueAnalyticsCubit>()),
            BlocProvider(create: (_) => sl<ExpenseCubit>()),
          ],
          child: RevenueAnalyticsScreen(
            libraryId: state.library!.id,
            libraryName: state.library!.name,
          ),
        ),
      ),
    );

    if (result == true && context.mounted) {
      context.read<OwnerLibraryBloc>().add(const RefreshLibraryStats());
      onRevenueReloaded();
    }
  }

  Future<void> navigateToSlotManagement(
    BuildContext context,
    OwnerLibraryState state,
  ) async {
    if (!state.hasLibrary) return;
    await context.push('/owner/slots?libraryId=${state.library!.id}');
    if (context.mounted) {
      context.read<OwnerLibraryBloc>().add(const RefreshLibraryStats());
      onRevenueReloaded();
    }
  }

  Future<void> navigateToNotifications(
    BuildContext context,
    OwnerLibraryState state,
  ) async {
    if (state.library == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UnifiedNotificationsScreen(library: state.library!),
      ),
    );
  }

  Future<void> navigateToSubscription(
    BuildContext context,
    OwnerLibraryState state, {
    SubscriptionState? subState,
  }) async {
    if (state.library == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OwnerInAppPurchaseScreen(library: state.library!),
      ),
    );

    if (mounted) onLibraryReloaded();
  }

  void navigateToReferral(
    BuildContext context,
    OwnerLibraryState state,
    SubscriptionState subState,
  ) {
    final user = context.read<PhoneAuthCubit>().state.currentUser;
    if (user == null) return;

    final hasAccess = subState.subscriptionStatus?.hasAccess ?? false;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<ReferralCubit>(),
          child: ReferralScreen(
            ownerId: user.id,
            ownerName: user.name,
            hasActiveSubscription: hasAccess,
          ),
        ),
      ),
    );
  }

  void showPaymentOptions(BuildContext context, OwnerLibraryState state) {
    if (state.library == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentApprovalsScreen(library: state.library!),
      ),
    );
  }

  void navigateToProfile(BuildContext context, User? user) async {
    if (user == null) return;

    final updatedUser = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<ProfileCubit>(),
          child: ProfileScreen(user: user),
        ),
      ),
    );

    if (updatedUser != null && context.mounted) {
      context.read<PhoneAuthCubit>().updateUser(updatedUser);
      onLibraryReloaded();
    }
  }

  void showSubscriptionRequired(
    BuildContext context,
    OwnerLibraryState state, {
    SubscriptionState? subState,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppUIConstants.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        ),
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: AppUIConstants.warning, size: 24),
            const SizedBox(width: AppUIConstants.spacingSm),
            Text('Subscription Required', style: AppUIConstants.headingMd),
          ],
        ),
        content: Text(
          'This feature requires an active subscription. '
          'Please subscribe to continue using all features.',
          style: AppUIConstants.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Later',
              style: TextStyle(color: AppUIConstants.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              navigateToSubscription(context, state, subState: subState);
            },
            style: AppUIConstants.primaryButtonStyle,
            child: const Text('Subscribe Now'),
          ),
        ],
      ),
    );
  }

  void showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppUIConstants.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<PhoneAuthCubit>().signOut();
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
