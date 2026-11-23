import 'package:material_ui/material_ui.dart';
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
import '../cubit/whatsapp_credits_cubit.dart';
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
import 'upi_approvals_screen.dart';
import 'whatsapp_credits_screen.dart';

/// Extracted navigation methods for the owner dashboard.
///
/// Keeps the main dashboard file focused on layout and state,
/// while all routing / dialog logic lives here.
mixin OwnerDashboardNavigation<T extends StatefulWidget> on State<T> {
  void onLibraryReloaded();
  void onRevenueReloaded();

  Future<void> navigateToAddBranch(BuildContext context) async {
    final user = context.read<PhoneAuthCubit>().state.currentUser;
    if (user == null) return;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LibraryFormScreen(
          ownerId: user.ownerAccountId,
          ownerPhone: user.phone,
          forceCreate: true,
        ),
      ),
    );

    if (result == true && context.mounted) onLibraryReloaded();
  }

  Future<void> navigateToForm(BuildContext context) async {
    final user = context.read<PhoneAuthCubit>().state.currentUser;
    if (user == null) return;

    final libraryState = context.read<OwnerLibraryBloc>().state;
    final libraryId = libraryState.library?.id;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LibraryFormScreen(
          ownerId: user.ownerAccountId,
          ownerPhone: user.phone,
          libraryId: libraryId,
        ),
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
            libraryId: state.library!.id,
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

  Future<void> navigateToWhatsAppCredits(
    BuildContext context,
    OwnerLibraryState state,
  ) async {
    final library = state.library;
    if (library == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<WhatsAppCreditsCubit>(),
          child: WhatsAppCreditsScreen(
            ownerId: library.ownerId,
            ownerPhone: library.ownerPhone,
          ),
        ),
      ),
    );
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
            ownerId: user.ownerAccountId,
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ActionSheet(
        icon: Icons.lock_rounded,
        tone: AppUIConstants.warning,
        title: 'Unlock PG Sathi',
        message:
            'This feature needs an active subscription. Subscribe to manage '
            'tenants, rent, receipts and notices without limits.',
        primaryLabel: 'Subscribe now',
        primaryStyle: AppUIConstants.primaryButtonStyle,
        onPrimary: () {
          Navigator.of(sheetContext).pop();
          navigateToSubscription(context, state, subState: subState);
        },
        secondaryLabel: 'Maybe later',
        onSecondary: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }

  void showSignOutDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ActionSheet(
        icon: Icons.logout_rounded,
        tone: AppUIConstants.error,
        title: 'Sign out?',
        message: 'You will need to verify your phone number to sign back in.',
        primaryLabel: 'Sign out',
        primaryStyle: ElevatedButton.styleFrom(
          backgroundColor: AppUIConstants.error,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          ),
        ),
        onPrimary: () {
          Navigator.of(sheetContext).pop();
          context.read<PhoneAuthCubit>().signOut();
        },
        secondaryLabel: 'Cancel',
        onSecondary: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }
}

/// Compact confirmation bottom sheet shared by the dashboard prompts.
class _ActionSheet extends StatelessWidget {
  const _ActionSheet({
    required this.icon,
    required this.tone,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.primaryStyle,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
  });

  final IconData icon;
  final Color tone;
  final String title;
  final String message;
  final String primaryLabel;
  final ButtonStyle primaryStyle;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppUIConstants.radiusXl),
        ),
        border: Border(top: BorderSide(color: AppUIConstants.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
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
              const SizedBox(height: 22),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: tone.withValues(alpha: 0.4)),
                ),
                child: Icon(icon, color: tone, size: 28),
              ),
              const SizedBox(height: 16),
              Text(title, style: AppUIConstants.headingLg),
              const SizedBox(height: 8),
              Text(
                message,
                style: AppUIConstants.bodyMd,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onPrimary,
                  style: primaryStyle,
                  child: Text(
                    primaryLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: onSecondary,
                child: Text(
                  secondaryLabel,
                  style: const TextStyle(color: AppUIConstants.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
