import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/library.dart';
import '../../../domain/entities/payment.dart';
import '../../../domain/usecases/get_pending_cash_payments.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/cash_approval_cubit.dart';
import '../cubit/cash_approval_state.dart';
import 'cash_approvals_screen.dart';

/// Combined payment approvals screen with tabs for UPI and Cash.
class PaymentApprovalsScreen extends StatefulWidget {
  const PaymentApprovalsScreen({
    super.key,
    required this.library,
    this.initialTab = 0,
  });

  final Library library;
  final int initialTab;

  @override
  State<PaymentApprovalsScreen> createState() => _PaymentApprovalsScreenState();
}

class _PaymentApprovalsScreenState extends State<PaymentApprovalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late CashApprovalCubit _cubit;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _cubit = sl<CashApprovalCubit>()..loadPendingPayments(widget.library.id);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cubit.close();
    super.dispose();
  }

  Future<void> _confirm(
    PendingCashPaymentInfo info, {
    required bool approve,
  }) async {
    final isUpi = info.payment.mode == PaymentMode.upi;
    final kind = isUpi ? 'UPI' : 'cash';
    final ok = await showApprovalConfirmSheet(
      context,
      title: approve ? 'Approve $kind payment' : 'Reject $kind payment',
      personName: '${isUpi ? 'UPI' : 'Cash'} from ${info.studentName}',
      amount: info.payment.amount,
      message: approve
          ? 'This will activate their stay.'
          : 'Their bed reservation will be cancelled.',
      confirmLabel: approve ? 'Approve' : 'Reject',
      color: approve ? AppUIConstants.success : AppUIConstants.error,
      icon: approve
          ? Icons.check_circle_outline_rounded
          : Icons.cancel_outlined,
    );
    if (!ok || !mounted) return;
    if (approve) {
      _cubit.approve(
        paymentId: info.payment.id,
        ownerId: widget.library.ownerId,
        libraryId: widget.library.id,
      );
    } else {
      _cubit.reject(
        paymentId: info.payment.id,
        ownerId: widget.library.ownerId,
        libraryId: widget.library.id,
      );
    }
  }

  Widget _segmented(int upi, int cash) {
    return ListenableBuilder(
      listenable: _tabController.animation!,
      builder: (context, _) {
        final index = _tabController.animation!.value.round();
        Widget seg(int i, IconData icon, String label, int n) {
          final sel = index == i;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                _tabController.animateTo(i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? AppUIConstants.background : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: sel
                          ? AppUIConstants.primaryLight
                          : AppUIConstants.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$label ($n)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: sel
                            ? AppUIConstants.textPrimary
                            : AppUIConstants.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppUIConstants.background.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          ),
          child: Row(
            children: [
              seg(0, Icons.account_balance_rounded, 'UPI', upi),
              seg(1, Icons.payments_rounded, 'Cash', cash),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(_hasChanges);
      },
      child: BlocProvider.value(
        value: _cubit,
        child: Scaffold(
          backgroundColor: AppUIConstants.background,
          body: BlocConsumer<CashApprovalCubit, CashApprovalState>(
            listener: (context, state) {
              if (state.isApproved) {
                _hasChanges = true;
                showApprovalSnack(
                  context,
                  'Payment approved successfully',
                  AppUIConstants.success,
                  Icons.check_circle_rounded,
                );
                _cubit.resetToLoaded();
              } else if (state.isRejected) {
                _hasChanges = true;
                showApprovalSnack(
                  context,
                  'Payment rejected',
                  AppUIConstants.warning,
                  Icons.cancel_rounded,
                );
                _cubit.resetToLoaded();
              } else if (state.isError && state.errorMessage != null) {
                showApprovalSnack(
                  context,
                  state.errorMessage!,
                  AppUIConstants.error,
                  Icons.error_rounded,
                );
              }
            },
            builder: (context, state) {
              // Filter by payment mode
              final upiPayments = state.pendingPayments
                  .where((p) => p.payment.mode == PaymentMode.upi)
                  .toList();
              final cashPayments = state.pendingPayments
                  .where((p) => p.payment.mode == PaymentMode.cash)
                  .toList();
              final loading = state.isLoading;
              final all = [...upiPayments, ...cashPayments];

              Widget list(
                List<PendingCashPaymentInfo> p,
                bool isUpi,
              ) => ApprovalList(
                payments: p,
                isProcessing: state.isProcessingPayment,
                onApprove: (i) => _confirm(i, approve: true),
                onReject: (i) => _confirm(i, approve: false),
                onRefresh: () async =>
                    _cubit.loadPendingPayments(widget.library.id),
                emptyIcon: isUpi
                    ? Icons.account_balance_rounded
                    : Icons.payments_rounded,
                emptyTitle: 'No pending ${isUpi ? 'UPI' : 'cash'} payments',
                emptyMessage:
                    'All ${isUpi ? 'UPI' : 'cash'} payments have been processed.',
              );

              return Column(
                children: [
                  ApprovalsHero(
                    title: 'Approve Payments',
                    subtitle: widget.library.name,
                    count: loading ? 0 : all.length,
                    total: loading ? 0 : approvalTotal(all),
                    onBack: () => Navigator.of(context).pop(_hasChanges),
                    bottom: _segmented(upiPayments.length, cashPayments.length),
                  ),
                  Expanded(
                    child: loading
                        ? const ApprovalSkeletonList()
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              list(upiPayments, true),
                              list(cashPayments, false),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
