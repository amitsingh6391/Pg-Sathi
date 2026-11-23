import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/payment.dart';
import '../../../domain/usecases/get_pending_cash_payments.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/cash_approval_cubit.dart';
import '../cubit/cash_approval_state.dart';
import 'cash_approvals_screen.dart';

/// Screen for owner to approve/reject pending UPI payments.
class UpiApprovalsScreen extends StatefulWidget {
  const UpiApprovalsScreen({
    super.key,
    required this.libraryId,
    required this.ownerId,
    required this.libraryName,
  });

  final String libraryId;
  final String ownerId;
  final String libraryName;

  @override
  State<UpiApprovalsScreen> createState() => _UpiApprovalsScreenState();
}

class _UpiApprovalsScreenState extends State<UpiApprovalsScreen> {
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    context.read<CashApprovalCubit>().loadPendingPayments(widget.libraryId);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pop(_hasChanges);
        }
      },
      child: Scaffold(
        backgroundColor: AppUIConstants.background,
        body: BlocConsumer<CashApprovalCubit, CashApprovalState>(
          listener: (context, state) {
            if (state.isApproved) {
              _hasChanges = true;
              showApprovalSnack(
                context,
                'UPI payment approved successfully',
                AppUIConstants.success,
                Icons.check_circle_rounded,
              );
              context.read<CashApprovalCubit>().resetToLoaded();
            } else if (state.isRejected) {
              _hasChanges = true;
              showApprovalSnack(
                context,
                'UPI payment rejected',
                AppUIConstants.warning,
                Icons.cancel_rounded,
              );
              context.read<CashApprovalCubit>().resetToLoaded();
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
            // Filter only UPI payments
            final upiPayments = state.pendingPayments
                .where((p) => p.payment.mode == PaymentMode.upi)
                .toList();

            return Column(
              children: [
                ApprovalsHero(
                  title: 'UPI Approvals',
                  subtitle: widget.libraryName,
                  count: state.isLoading ? 0 : upiPayments.length,
                  total: state.isLoading ? 0 : approvalTotal(upiPayments),
                  onBack: () => Navigator.of(context).pop(_hasChanges),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: state.isLoading
                        ? const ApprovalSkeletonList(key: ValueKey('skeleton'))
                        : ApprovalList(
                            key: const ValueKey('list'),
                            payments: upiPayments,
                            isProcessing: state.isProcessingPayment,
                            onApprove: _handleApprove,
                            onReject: _handleReject,
                            onRefresh: () async => context
                                .read<CashApprovalCubit>()
                                .loadPendingPayments(widget.libraryId),
                            emptyIcon: Icons.verified_rounded,
                            emptyTitle: 'All caught up!',
                            emptyMessage:
                                'No pending UPI payments\nawaiting your approval.',
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

  Future<void> _handleApprove(PendingCashPaymentInfo info) async {
    final ok = await showApprovalConfirmSheet(
      context,
      title: 'Approve UPI payment',
      personName: 'UPI from ${info.studentName}',
      amount: info.payment.amount,
      message: 'This will activate their stay.',
      confirmLabel: 'Approve',
      color: AppUIConstants.success,
      icon: Icons.check_circle_outline_rounded,
    );
    if (!ok || !mounted) return;
    context.read<CashApprovalCubit>().approve(
      paymentId: info.payment.id,
      ownerId: widget.ownerId,
      libraryId: widget.libraryId,
    );
  }

  Future<void> _handleReject(PendingCashPaymentInfo info) async {
    final ok = await showApprovalConfirmSheet(
      context,
      title: 'Reject UPI payment',
      personName: 'UPI from ${info.studentName}',
      amount: info.payment.amount,
      message: 'Their bed reservation will be cancelled.',
      confirmLabel: 'Reject',
      color: AppUIConstants.error,
      icon: Icons.cancel_outlined,
    );
    if (!ok || !mounted) return;
    context.read<CashApprovalCubit>().reject(
      paymentId: info.payment.id,
      ownerId: widget.ownerId,
      libraryId: widget.libraryId,
      reason: 'UPI payment rejected by owner',
    );
  }
}
